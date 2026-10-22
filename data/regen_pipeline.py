#!/usr/bin/env python3.11
"""Regenerate the SPHEREx zodi training data with the extended survey coverage.

Faithful port of the user's notebooks:
  2025_10_17/2025_10_17_spherex.ipynb   (boresight -> ecliptic pointing h5)
  2025_11_24/2025_11_24_boreHorizons.ipynb (Horizons vectors, zodipy emission, healpix comps)
New pointing source: IRSA TAP spherex.obscore (public QR metadata) instead of boresight.txt.
Outputs (drop-in schema-compatible) -> /mnt/ceph/users/sdssv/work/asaydjari/2026_10_19/zodi_regen/ (2026-10-19 rerun: QR2 + QR3 through 2026-09-07; copy of 2026_08_03/experiments/regen_pipeline.py with only OUTDIR changed)
"""
import io
import os
import sys
import time as pytime
from datetime import datetime

import numpy as np
import pandas as pd
import h5py
import requests
import astropy.units as u
from astropy.time import Time
from astropy.coordinates import SkyCoord, CustomBarycentricEcliptic
from astroquery.jplhorizons import Horizons
from scipy.interpolate import interp1d

OUTDIR = "/mnt/ceph/users/sdssv/work/asaydjari/2026_10_19/zodi_regen"
os.makedirs(OUTDIR, exist_ok=True)
CSV_CACHE = os.path.join(OUTDIR, "obscore_pointings.csv")
TAP = "https://irsa.ipac.caltech.edu/TAP/sync"

def log(msg):
    print(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}", flush=True)

# ----------------------------------------------------------------------------
# Stage 1: fetch pointings from IRSA spherex.obscore (chunked by t_min)
# ----------------------------------------------------------------------------
def fetch_pointings():
    if os.path.exists(CSV_CACHE):
        log(f"stage1: using cached {CSV_CACHE}")
        return pd.read_csv(CSV_CACHE)
    q = "SELECT min(t_min) AS a, max(t_min) AS b FROM spherex.obscore"
    r = requests.get(TAP, params={"LANG": "ADQL", "FORMAT": "CSV", "QUERY": q}, timeout=300)
    a, b = map(float, r.text.strip().splitlines()[1].split(","))
    log(f"stage1: obscore t_min range {a:.3f} .. {b:.3f} ({b-a:.1f} d)")
    edges = np.arange(np.floor(a), np.ceil(b) + 30.0, 30.0)
    frames = []
    for lo, hi in zip(edges[:-1], edges[1:]):
        q = ("SELECT obs_publisher_did, obs_collection, energy_bandpassname, s_ra, s_dec, t_min "
             f"FROM spherex.obscore WHERE t_min >= {lo} AND t_min < {hi}")
        for attempt in range(4):
            try:
                r = requests.get(TAP, params={"LANG": "ADQL", "FORMAT": "CSV", "QUERY": q},
                                 timeout=600)
                r.raise_for_status()
                if not r.text.startswith("obs_publisher_did"):
                    raise RuntimeError("unexpected response: " + r.text[:100])
                df = pd.read_csv(io.StringIO(r.text))
                frames.append(df)
                log(f"stage1: [{lo:.0f},{hi:.0f}) -> {len(df)} rows")
                break
            except Exception as e:
                log(f"stage1: chunk [{lo:.0f},{hi:.0f}) attempt {attempt+1} failed: {e}")
                pytime.sleep(20 * (attempt + 1))
        else:
            raise RuntimeError(f"chunk [{lo},{hi}) failed after retries")
    df = pd.concat(frames, ignore_index=True)
    n0 = len(df)
    df = df.drop_duplicates(subset="obs_publisher_did").sort_values("t_min").reset_index(drop=True)
    log(f"stage1: {n0} rows fetched, {len(df)} after dedup; collections: "
        + ", ".join(f"{k}:{v}" for k, v in df.obs_collection.value_counts().items()))
    df.to_csv(CSV_CACHE, index=False)
    return df

# ----------------------------------------------------------------------------
# Stage 2: pointing h5 (FK5 -> CustomBarycentricEcliptic, per the notebook)
# ----------------------------------------------------------------------------
def make_pointing_h5(df):
    path = os.path.join(OUTDIR, "boresight_pointing.h5")
    mjd = df.t_min.values.astype(float)
    ra_deg = df.s_ra.values.astype(float)
    dec_deg = df.s_dec.values.astype(float)
    julian_dates = mjd + 2400000.5
    obstimes = Time(julian_dates, format="jd", scale="utc")
    fk5 = SkyCoord(ra=ra_deg * u.deg, dec=dec_deg * u.deg, frame="fk5", obstime=obstimes)
    ecl = fk5.transform_to(CustomBarycentricEcliptic)
    ecl_lon, ecl_lat = ecl.lon.deg, ecl.lat.deg
    lonr, latr = np.radians(ecl_lon), np.radians(ecl_lat)
    nvec = np.column_stack([np.cos(latr) * np.cos(lonr),
                            np.cos(latr) * np.sin(lonr),
                            np.sin(latr)])
    with h5py.File(path, "w") as f:
        m = f.create_group("metadata")
        m.attrs["created"] = datetime.now().isoformat()
        m.attrs["description"] = ("Boresight pointing directions from IRSA spherex.obscore "
                                  "converted to ecliptic coordinates")
        m.attrs["source_file"] = "IRSA TAP spherex.obscore (s_ra, s_dec, t_min), all detectors"
        m.attrs["total_points"] = len(mjd)
        tg = f.create_group("times")
        tg.create_dataset("mjd", data=mjd, compression="gzip")
        tg.create_dataset("julian_date", data=julian_dates, compression="gzip")
        pg = f.create_group("pointing")
        pg.create_dataset("ra_deg", data=ra_deg, compression="gzip")
        pg.create_dataset("dec_deg", data=dec_deg, compression="gzip")
        pg.create_dataset("ecliptic_longitude_deg", data=ecl_lon, compression="gzip")
        pg.create_dataset("ecliptic_latitude_deg", data=ecl_lat, compression="gzip")
        pg.create_dataset("nvec_unit_cartesian", data=nvec, compression="gzip")
        f.attrs["coordinate_system"] = "ecliptic"
        f.attrs["reference_frame"] = "barycentric"
    log(f"stage2: wrote {path} ({len(mjd)} points, span {mjd.max()-mjd.min():.1f} d)")
    return mjd, julian_dates, ecl_lon, ecl_lat

# ----------------------------------------------------------------------------
# Stage 3: Horizons vectors on a 3-min grid (chunked), cubic-interpolated
# ----------------------------------------------------------------------------
def horizons_grid_chunked(obj_id, mjd_times, step_minutes=3, chunk_days=45.0):
    jd_target = Time(mjd_times, format="mjd").jd
    lo = mjd_times.min() - 0.1
    hi = mjd_times.max() + 0.1
    edges = np.arange(lo, hi + chunk_days, chunk_days)
    edges[-1] = max(edges[-1], hi)
    grids = {k: [] for k in ("jd", "x", "y", "z", "vx", "vy", "vz")}
    for clo, chi in zip(edges[:-1], edges[1:]):
        if clo >= hi:
            break
        chi = min(chi, hi)
        for attempt in range(4):
            try:
                obj = Horizons(id=obj_id, location="@0",
                               epochs={"start": Time(clo, format="mjd").iso,
                                       "stop": Time(chi + 0.05, format="mjd").iso,
                                       "step": f"{step_minutes}m"})
                vec = obj.vectors(refplane="ecliptic")
                grids["jd"].append(np.array(vec["datetime_jd"]))
                for k in ("x", "y", "z", "vx", "vy", "vz"):
                    grids[k].append(np.array(vec[k]))
                log(f"stage3: {obj_id} [{clo:.1f},{chi:.1f}] -> {len(vec)} grid pts")
                break
            except Exception as e:
                log(f"stage3: {obj_id} chunk attempt {attempt+1} failed: {e}")
                pytime.sleep(30 * (attempt + 1))
        else:
            raise RuntimeError(f"Horizons {obj_id} chunk [{clo},{chi}] failed")
    jd_grid = np.concatenate(grids["jd"])
    order = np.argsort(jd_grid)
    jd_grid = jd_grid[order]
    uniq = np.concatenate([[True], np.diff(jd_grid) > 1e-9])
    jd_grid = jd_grid[uniq]
    out = {}
    for k in ("x", "y", "z", "vx", "vy", "vz"):
        g = np.concatenate(grids[k])[order][uniq]
        out[k] = interp1d(jd_grid, g, kind="cubic", fill_value="extrapolate")(jd_target)
    return out

def make_vectors_h5(mjd):
    path = os.path.join(OUTDIR, "spherex_vectors_bore_interpolated.h5")
    bodies = [("spherex", "-163182", "SPHEREx"), ("earth", "399", "Earth"),
              ("moon", "301", "Moon"), ("jupiter", "599", "Jupiter")]
    with h5py.File(path, "w") as f:
        m = f.create_group("metadata")
        m.attrs["created"] = datetime.now().isoformat()
        m.attrs["description"] = ("SPHEREx, Earth, and Jupiter ephemeris data relative to "
                                  "solar system barycenter")
        data = {}
        for name, oid, label in bodies:
            log(f"stage3: querying {label} ({oid})...")
            d = horizons_grid_chunked(oid, mjd)
            pos = np.column_stack([d["x"], d["y"], d["z"]])
            vel = np.column_stack([d["vx"], d["vy"], d["vz"]])
            g = f.create_group(name)
            g.create_dataset("positions", data=pos, compression="gzip")
            g.create_dataset("velocities", data=vel, compression="gzip")
            g.attrs["object_id"] = oid
            g.attrs["object_name"] = label
            g.attrs["units"] = "AU"
            g.attrs["velocity_units"] = "AU/day"
            data[name] = pos
    log(f"stage3: wrote {path}")
    return data["spherex"]

# ----------------------------------------------------------------------------
# Stage 4: zodipy emission along boresights (chunked) + healpix components
# ----------------------------------------------------------------------------
def make_emission_h5(julian_dates, ecl_lon, ecl_lat, spherex_bary):
    import zodipy
    model = zodipy.Model(5 * u.micron)
    path = os.path.join(OUTDIR, "spherex_zodipy_5um_boresight_interpolated.h5")
    n = len(julian_dates)
    emission = np.empty(n)
    CH = 100_000
    for i0 in range(0, n, CH):
        i1 = min(i0 + CH, n)
        obstimes = Time(julian_dates[i0:i1], format="jd", scale="utc")
        coords = SkyCoord(ecl_lon[i0:i1] * u.deg, ecl_lat[i0:i1] * u.deg,
                          frame=CustomBarycentricEcliptic, obstime=obstimes)
        emission[i0:i1] = model.evaluate(coords, obspos=spherex_bary[i0:i1].T * u.AU).value
        log(f"stage4: emission {i1}/{n}")
    days_since_start = julian_dates - julian_dates[0]
    with h5py.File(path, "w") as f:
        m = f.create_group("metadata")
        m.attrs["created"] = datetime.now().isoformat()
        m.attrs["description"] = "Zodiacal light predictions for SPHEREx pointing directions"
        m.attrs["zodipy_model"] = "5 micron"
        m.attrs["wavelength"] = 5.0
        m.attrs["wavelength_units"] = "micron"
        m.attrs["emission_units"] = "MJy/sr"
        m.attrs["data_points"] = n
        f.create_dataset("emission", data=emission, compression="gzip")
        cg = f.create_group("coordinates")
        cg.create_dataset("ecliptic_longitude_deg", data=ecl_lon, compression="gzip")
        cg.create_dataset("ecliptic_latitude_deg", data=ecl_lat, compression="gzip")
        tg = f.create_group("times")
        tg.create_dataset("julian_date", data=julian_dates, compression="gzip")
        tg.create_dataset("days_since_start", data=days_since_start, compression="gzip")
    log(f"stage4: wrote {path} (emission range {emission.min():.3f}..{emission.max():.3f})")
    return model

def make_healpix_h5(model, julian_dates, spherex_bary, tindx0=13169, nside=256):
    import healpy as hp
    COMP_NAMES = ["smooth_cloud", "dust_band_1", "dust_band_2", "dust_band_3",
                  "circum_solar_ring", "earth_trailing_feature"]
    path = os.path.join(OUTDIR, "spherex_zodipy_5um_boresight_healpix_components_interpolated.h5")
    pixels = np.arange(hp.nside2npix(nside))
    lon, lat = hp.pix2ang(nside, pixels, lonlat=True)
    obstime = Time(julian_dates[tindx0], format="jd", scale="utc")
    sc = SkyCoord(lon, lat, unit=u.deg, frame=CustomBarycentricEcliptic, obstime=obstime)
    log(f"stage5: healpix eval at index {tindx0} (JD {julian_dates[tindx0]:.4f})")
    emission = model.evaluate(sc, obspos=spherex_bary[tindx0].T * u.AU).value
    emission_comp = model.evaluate(sc, obspos=spherex_bary[tindx0].T * u.AU,
                                   return_comps=True).value
    with h5py.File(path, "w") as f:
        f.create_dataset("emission", data=emission, compression="gzip")
        f.create_dataset("pixels", data=pixels, compression="gzip")
        f.create_dataset("ecliptic_longitude_deg", data=lon, compression="gzip")
        f.create_dataset("ecliptic_latitude_deg", data=lat, compression="gzip")
        for idx, comp in enumerate(emission_comp):
            f.create_dataset(f"emission_{COMP_NAMES[idx]}", data=comp, compression="gzip")
    log(f"stage5: wrote {path}")

def main():
    df = fetch_pointings()
    mjd, jd, lon, lat = make_pointing_h5(df)
    spherex_bary = make_vectors_h5(mjd)
    model = make_emission_h5(jd, lon, lat, spherex_bary)
    make_healpix_h5(model, jd, spherex_bary)
    log("ALL STAGES DONE")

if __name__ == "__main__":
    main()
