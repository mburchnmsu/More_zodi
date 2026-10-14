"""Round 12: a ~2.3-year synthetic survey for 'train on year 1, test on year 2'. Writes NEW files only:
  data/z115year_pointing.h5, data/z115year_vectors.h5, data/z115year_boresight.h5
in exactly the layouts of boresight_pointing.h5 / spherex_vectors_bore_interpolated.h5 / zodipy115_5um_boresight.h5,
so the whole training stack runs unchanged with ENV["ZODI_DATA"] = "z115year".

Copies: the real mission (shift 0, corrected ZodiPy target) and the survey moved forward by 140, 280, 420, 560, 700 days
(rotated about the ecliptic pole with Earth's orbital motion, exactly as generate_future.py). Each copy is a different
random 100,000 exposures, so dates run continuously from mission day 0 to ~840.

Run:  <zodipy env python> -I -X utf8 zodipy_gen/generate_year.py <More_zodi root>
"""
import sys, time, ctypes, numpy as np, h5py, astropy.units as u
from astropy.time import Time
from astropy.coordinates import (SkyCoord, BarycentricMeanEcliptic, HeliocentricMeanEcliptic, CartesianRepresentation,
                                 ICRS, solar_system_ephemeris, get_body_barycentric_posvel)
import zodipy
from importlib.metadata import version

if sys.platform == "win32":
    ctypes.windll.kernel32.SetPriorityClass(ctypes.windll.kernel32.GetCurrentProcess(), 0x4000)  # BELOW_NORMAL

ROOT = sys.argv[1]; D = f"{ROOT}/data"; EPHEM = "de432s"
SHIFTS = [0, 140, 280, 420, 560, 700]; NPER = 100_000
COMPS = ["smooth_cloud", "dust_band_1", "dust_band_2", "dust_band_3", "circum_solar_ring", "earth_trailing_feature"]

with h5py.File(f"{D}/boresight_pointing.h5") as f:
    nvec = f["pointing/nvec_unit_cartesian"][:]; jd = f["times/julian_date"][:]
with h5py.File(f"{D}/spherex_vectors_bore_interpolated.h5") as f:
    V = {b: (f[f"{b}/positions"][:], f[f"{b}/velocities"][:]) for b in ("spherex", "earth", "jupiter", "moon")}
with h5py.File(f"{D}/zodipy115_5um_boresight.h5") as f:
    y0 = f["emission"][:]; C0 = np.vstack([f[f"emission_{n}"][:] for n in COMPS])
N = len(jd)

def body_ecl(body, t):
    p, v = get_body_barycentric_posvel(body, t, ephemeris=EPHEM)
    to_ecl = lambda r: ICRS(r).transform_to(BarycentricMeanEcliptic()).cartesian.xyz.to_value(u.AU).T
    return to_ecl(p), to_ecl(CartesianRepresentation(v.xyz.to_value(u.AU / u.day) * u.AU))

def helio(xyz_bary, t):
    c = BarycentricMeanEcliptic(CartesianRepresentation(xyz_bary.T * u.AU))
    with solar_system_ephemeris.set(EPHEM):
        return c.transform_to(HeliocentricMeanEcliptic(obstime=t)).cartesian.xyz.to_value(u.AU)

def rotz(phi_deg, X):
    c, s = np.cos(np.radians(phi_deg)), np.sin(np.radians(phi_deg))
    return np.stack([c * X[:, 0] - s * X[:, 1], s * X[:, 0] + c * X[:, 1], X[:, 2]], axis=1)

def lam_earth(t):
    h = helio(body_ecl("earth", t)[0], t); return np.degrees(np.arctan2(h[1], h[0]))

# validation of the ephemeris code against the vectors file (incl. the Moon, which this file also needs)
k = np.random.default_rng(5).choice(N, 300, replace=False); t = Time(jd[k], format="jd", scale="tdb")
for b in ("earth", "jupiter", "moon"):
    p, v = body_ecl(b, t)
    print(f"ephemeris check {b:8s}: |Δpos| {np.max(np.linalg.norm(p - V[b][0][k], axis=1)):.1e} AU, "
          f"|Δvel| {np.max(np.linalg.norm(v - V[b][1][k], axis=1)):.1e} AU/day", flush=True)

rng = np.random.default_rng(12)
out = {key: [] for key in ("shift", "src", "jd", "nvec", "y", "C", "spherex_p", "spherex_v", "earth_p", "earth_v",
                           "jupiter_p", "jupiter_v", "moon_p", "moon_v")}
model = zodipy.Model(x=5 * u.um, name="dirbe", ephemeris=EPHEM)
for sh in SHIFTS:
    base = np.sort(rng.choice(N, NPER, replace=False)); tic = time.time()
    out["shift"].append(np.full(NPER, sh)); out["src"].append(base); out["jd"].append(jd[base] + sh)
    if sh == 0:                                       # the real mission: real geometry, corrected target
        out["nvec"].append(nvec[base]); out["y"].append(y0[base]); out["C"].append(C0[:, base])
        for b in ("spherex", "earth", "jupiter", "moon"):
            out[f"{b}_p"].append(V[b][0][base]); out[f"{b}_v"].append(V[b][1][base])
        print(f"shift   0: real mission rows (corrected target)", flush=True); continue
    t0, t1 = Time(jd[base], format="jd", scale="tdb"), Time(jd[base] + sh, format="jd", scale="tdb")
    phi = lam_earth(t1) - lam_earth(t0)
    E1, vE1 = body_ecl("earth", t1)
    n1 = rotz(phi, nvec[base]); S1 = E1 + rotz(phi, V["spherex"][0][base] - V["earth"][0][base])
    vS1 = vE1 + rotz(phi, V["spherex"][1][base] - V["earth"][1][base])
    out["nvec"].append(n1); out["spherex_p"].append(S1); out["spherex_v"].append(vS1)
    out["earth_p"].append(E1); out["earth_v"].append(vE1)
    for b in ("jupiter", "moon"):
        p, v = body_ecl(b, t1); out[f"{b}_p"].append(p); out[f"{b}_v"].append(v)
    lat = np.degrees(np.arcsin(np.clip(n1[:, 2], -1, 1))); lon = np.degrees(np.arctan2(n1[:, 1], n1[:, 0])) % 360
    order = np.argsort(t1.jd, kind="stable"); Cs = np.empty((len(COMPS), NPER))
    for j in range(0, NPER, 2000):
        ii = order[j:j + 2000]; tt = t1[ii]
        c = SkyCoord(lon[ii] * u.deg, lat[ii] * u.deg, frame="barycentricmeanecliptic", obstime=tt.utc)
        Cs[:, ii] = model.evaluate(c, obspos=helio(S1[ii], tt) * u.AU, return_comps=True).value
    assert np.all(np.isfinite(Cs)) and np.all(Cs.sum(0) > 0)
    out["y"].append(Cs.sum(0)); out["C"].append(Cs)
    print(f"shift {sh:3d}: dates {np.min(jd[base] + sh - jd.min()):6.1f}..{np.max(jd[base] + sh - jd.min()):6.1f} mission days, "
          f"turn φ median {np.median(phi % 360):6.1f}°, ZodiPy {time.time() - tic:.0f}s", flush=True)

F = {key: (np.concatenate(v, axis=-1) if key == "C" else np.concatenate(v)) for key, v in out.items()}
M = len(F["jd"])
lat = np.degrees(np.arcsin(np.clip(F["nvec"][:, 2], -1, 1))); lon = np.degrees(np.arctan2(F["nvec"][:, 1], F["nvec"][:, 0])) % 360
stamp = dict(created=time.strftime("%Y-%m-%dT%H:%M:%S"), generator="zodipy_gen/generate_year.py",
             shifts_days=np.array(SHIFTS), rows_per_shift=NPER)
with h5py.File(f"{D}/z115year_pointing.h5", "w") as f:
    f.attrs["coordinate_system"] = "ecliptic"; f.attrs["reference_frame"] = "barycentric"
    m = f.create_group("metadata"); [m.attrs.__setitem__(a, b) for a, b in stamp.items()]
    m.attrs["description"] = "Synthetic multi-year SPHEREx survey (real mission + rotated copies), round 12"
    f["pointing/nvec_unit_cartesian"] = F["nvec"]; f["pointing/ecliptic_longitude_deg"] = lon
    f["pointing/ecliptic_latitude_deg"] = lat; f["times/julian_date"] = F["jd"]
    f["shift_days"] = F["shift"]; f["source_index_0based"] = F["src"]
with h5py.File(f"{D}/z115year_vectors.h5", "w") as f:
    f.attrs["coordinate_system"] = "ecliptic"; f.attrs["reference_frame"] = "solar_system_barycenter"; f.attrs["data_points"] = M
    for b in ("spherex", "earth", "jupiter", "moon"):
        f[f"{b}/positions"] = F[f"{b}_p"]; f[f"{b}/velocities"] = F[f"{b}_v"]
with h5py.File(f"{D}/z115year_boresight.h5", "w") as f:
    m = f.create_group("metadata")
    for a, b in dict(stamp, description="Zodiacal light for the synthetic multi-year survey (ZodiPy, round 12)",
                     zodipy_version=version("zodipy"), zodipy_model="dirbe (Kelsall 1998)", wavelength=5.0,
                     wavelength_units="micron", emission_units="MJy/sr", ephemeris=EPHEM).items():
        m.attrs[a] = b
    f["emission"] = F["y"]
    for i, n in enumerate(COMPS): f[f"emission_{n}"] = F["C"][i]
    f["coordinates/ecliptic_latitude_deg"] = lat; f["coordinates/ecliptic_longitude_deg"] = lon
    f["times/julian_date"] = F["jd"]; f["times/days_since_start"] = F["jd"] - F["jd"].min()
print(f"wrote {M} exposures; dates span {F['jd'].max() - F['jd'].min():.1f} days. DONE", flush=True)
