"""The Sun's barycentric position (de432s, ecliptic frame like spherex_vectors_bore_interpolated.h5) at every exposure,
so the model inputs can be made heliocentric (the Kelsall cloud and ZodiPy's targets are Sun-centred; the vectors file
is barycentric and the Sun moves 0.0035 AU about the barycentre over 500 days — see zodipy_gen/sun_wobble.py).
Run:  <zodipy env python> -I zodipy_gen/sun_positions.py <More_zodi root> [d140]
  → data/sun_positions.h5 (500-day delivery) or data/d140/sun_positions.h5 (140-day data)"""
import sys, time, numpy as np, h5py
from astropy.time import Time
from astropy.coordinates import get_body_barycentric, solar_system_ephemeris
D = sys.argv[1] + "/data" + ("/d140" if len(sys.argv) > 2 and sys.argv[2] == "d140" else "")
with h5py.File(f"{D}/boresight_pointing.h5") as f: jd = f["times/julian_date"][:]
t0 = time.time()
# the Sun moves ~1e-7 AU per minute about the barycentre: evaluate on a 30-min grid and interpolate (error < 1e-9 AU)
grid = np.arange(jd.min() - 0.05, jd.max() + 0.05, 1 / 48)
with solar_system_ephemeris.set("de432s"):
    g = get_body_barycentric("sun", Time(grid, format="jd", scale="utc")).xyz.to_value("au").T
eps = np.deg2rad(23.4392911)                                    # ICRS (equatorial) → ecliptic
R = np.array([[1, 0, 0], [0, np.cos(eps), np.sin(eps)], [0, -np.sin(eps), np.cos(eps)]])
g = g @ R.T
sun = np.column_stack([np.interp(jd, grid, g[:, k]) for k in range(3)])
with h5py.File(f"{D}/sun_positions.h5", "w") as f:
    f["sun/positions"] = sun
    f["times/julian_date"] = jd
    m = f.create_group("metadata"); m.attrs["description"] = "Sun barycentric position, de432s, ecliptic (obliquity 23.4392911 deg), AU"
    m.attrs["generator"] = "zodipy_gen/sun_positions.py"
print(f"{len(jd)} exposures → {D}/sun_positions.h5 in {time.time() - t0:.0f}s; |Sun| {np.linalg.norm(sun, axis=1).min():.5f}..{np.linalg.norm(sun, axis=1).max():.5f} AU")
