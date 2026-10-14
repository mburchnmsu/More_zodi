"""Round 13 (multi-wavelength): every mission exposure at ONE of 64 wavelength channels between 1.25 and 5.0 um.
Writes data/zodipy115_multi_boresight.h5 (new file; same layout as zodipy115_5um_boresight.h5 plus wavelength_um and
channel). Pointing and geometry are the mission's own (boresight_pointing.h5, spherex_vectors_bore_interpolated.h5),
so the training stack runs unchanged with ENV["ZODI_DATA"] = "z115multi".

Channels: 64 log-spaced from 1.25 um (the shortest DIRBE band; below it ZodiPy's Kelsall model only extrapolates) to
5.0 um, monochromatic (no channel bandpass). Same ZodiPy settings as generate.py (observer = SPHEREx heliocentric,
de432s, times passed as UTC, time-ordered chunks).
Check: the 5.0 um channel must equal data/zodipy115_5um_boresight.h5 exactly for the same exposures.

Run:  <zodipy env python> -I -X utf8 zodipy_gen/generate_multi.py <More_zodi root>
"""
import sys, time, ctypes, numpy as np, h5py, astropy.units as u
from astropy.time import Time
from astropy.coordinates import SkyCoord, BarycentricMeanEcliptic, HeliocentricMeanEcliptic, CartesianRepresentation, solar_system_ephemeris
import zodipy
from importlib.metadata import version

if sys.platform == "win32":
    ctypes.windll.kernel32.SetPriorityClass(ctypes.windll.kernel32.GetCurrentProcess(), 0x4000)  # BELOW_NORMAL

ROOT = sys.argv[1]; D = f"{ROOT}/data"; EPHEM = "de432s"; CHUNK = 2000
WAVES = np.geomspace(1.25, 5.0, 64)
COMPS = ["smooth_cloud", "dust_band_1", "dust_band_2", "dust_band_3", "circum_solar_ring", "earth_trailing_feature"]

with h5py.File(f"{D}/boresight_pointing.h5") as f:
    lon = f["pointing/ecliptic_longitude_deg"][:]; lat = f["pointing/ecliptic_latitude_deg"][:]; jd = f["times/julian_date"][:]
with h5py.File(f"{D}/spherex_vectors_bore_interpolated.h5") as f:
    S_bary = f["spherex/positions"][:]
with h5py.File(f"{D}/zodipy115_5um_boresight.h5") as f:
    y5 = f["emission"][:]; days = f["times/days_since_start"][:]
N = len(jd)

def helio(xyz_bary, t):
    c = BarycentricMeanEcliptic(CartesianRepresentation(xyz_bary.T * u.AU))
    with solar_system_ephemeris.set(EPHEM):
        return c.transform_to(HeliocentricMeanEcliptic(obstime=t)).cartesian.xyz.to_value(u.AU)

chan = np.random.default_rng(13).integers(0, len(WAVES), N)          # one channel per exposure
out = np.empty((len(COMPS), N)); tic = time.time()
for c in range(len(WAVES)):
    model = zodipy.Model(x=WAVES[c] * u.um, name="dirbe", ephemeris=EPHEM)
    idx = np.where(chan == c)[0]; idx = idx[np.argsort(jd[idx], kind="stable")]
    for j in range(0, len(idx), CHUNK):
        ii = idx[j:j + CHUNK]; t = Time(jd[ii], format="jd", scale="tdb")
        sc = SkyCoord(lon[ii] * u.deg, lat[ii] * u.deg, frame="barycentricmeanecliptic", obstime=t.utc)
        out[:, ii] = model.evaluate(sc, obspos=helio(S_bary[ii], t) * u.AU, return_comps=True).value
    if c % 8 == 0 or c == len(WAVES) - 1:
        print(f"  channel {c:2d}  {WAVES[c]:.3f} um  {len(idx)} exposures  median {np.median(out[:, idx].sum(0)):.4f} MJy/sr  ({time.time() - tic:.0f}s)", flush=True)
tot = out.sum(0)
assert np.all(np.isfinite(out)) and np.all(tot > 0)
last = chan == len(WAVES) - 1
d5 = np.max(np.abs(tot[last] / y5[last] - 1))
print(f"check: 5.0 um channel vs zodipy115_5um_boresight.h5 on {last.sum()} exposures: max rel diff {d5:.1e}", flush=True)
assert d5 < 1e-10, "the 5.0 um channel does not reproduce the 5 um corrected data"

with h5py.File(f"{D}/zodipy115_multi_boresight.h5", "w") as f:
    m = f.create_group("metadata")
    for k, v in dict(created=time.strftime("%Y-%m-%dT%H:%M:%S"), zodipy_version=version("zodipy"), zodipy_model="dirbe (Kelsall 1998)",
                     description="Zodiacal light for SPHEREx pointing directions, one of 64 wavelength channels (1.25-5.0 um) per exposure",
                     wavelength="1.25-5.0 (per exposure)", wavelength_units="micron", bandpass="none (monochromatic)",
                     ephemeris=EPHEM, emission_units="MJy/sr", generator="zodipy_gen/generate_multi.py", data_points=N).items():
        m.attrs[k] = v
    f["emission"] = tot
    for i, n in enumerate(COMPS): f[f"emission_{n}"] = out[i]
    f["wavelength_um"] = WAVES[chan]; f["channel"] = chan; f["channel_wavelengths_um"] = WAVES
    f["coordinates/ecliptic_latitude_deg"] = lat; f["coordinates/ecliptic_longitude_deg"] = lon
    f["times/julian_date"] = jd; f["times/days_since_start"] = days
print(f"DONE in {time.time() - tic:.0f}s; emission range {tot.min():.4f}..{tot.max():.4f} MJy/sr", flush=True)
