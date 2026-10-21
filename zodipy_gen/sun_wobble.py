"""Does the Sun's offset from the solar-system barycentre explain why the 500-day model needs n·J?
Sun's barycentric position (de432s) at a sample of the 500-day exposure times; its size and drift, its alignment
with Jupiter, and whether HELIOcentric Earth distance repeats year to year where the barycentric one does not.
Run:  <zodipy env python> -I zodipy_gen/sun_wobble.py <More_zodi root>"""
import sys, numpy as np, h5py
from astropy.time import Time
from astropy.coordinates import get_body_barycentric, solar_system_ephemeris
D = sys.argv[1] + "/data"
with h5py.File(f"{D}/boresight_pointing.h5") as f: jd = f["times/julian_date"][:]
with h5py.File(f"{D}/spherex_vectors_bore_interpolated.h5") as f: E = f["earth/positions"][:]; J = f["jupiter/positions"][:]
idx = np.arange(0, len(jd), 500)
t = Time(jd[idx], format="jd", scale="utc")
with solar_system_ephemeris.set("de432s"):
    sun = get_body_barycentric("sun", t).xyz.to_value("au").T          # (n, 3), ecliptic? -> ICRS; rotate below
# astropy returns ICRS (equatorial); rotate to ecliptic (obliquity 23.4393°) to match the vectors file
eps = np.deg2rad(23.4392911)
R = np.array([[1, 0, 0], [0, np.cos(eps), np.sin(eps)], [0, -np.sin(eps), np.cos(eps)]])
sun = sun @ R.T
day = jd[idx] - jd.min()
r = np.linalg.norm(sun, axis=1)
print(f"Sun-barycentre distance: {r.min():.5f} .. {r.max():.5f} AU over 500 days; change {r[-1]-r[0]:+.5f} AU; "
      f"Sun moved {np.linalg.norm(sun[-1]-sun[0]):.5f} AU")
Ju = J[idx] / np.linalg.norm(J[idx], axis=1, keepdims=True); su = sun / r[:, None]
print(f"cos(angle between Sun offset and Jupiter direction): median {np.median(np.sum(Ju*su,1)):+.3f} (−1 = opposite)")
Eb = E[idx]; Eh = Eb - sun
lam = np.degrees(np.arctan2(Eb[:, 1], Eb[:, 0])) % 360; lamh = np.degrees(np.arctan2(Eh[:, 1], Eh[:, 0])) % 360
y1 = day < 135; y2 = day >= 365.25
def match(l):
    out = []
    for j in np.where(y2)[0]:
        i = np.where(y1)[0][np.argmin(np.abs(((l[y1] - l[j] + 180) % 360) - 180))]
        out.append((i, j))
    return np.array(out)
for nm, X, l in (("barycentric", Eb, lam), ("heliocentric", Eh, lamh)):
    p = match(l); d = np.linalg.norm(X[p[:, 1]], axis=1) - np.linalg.norm(X[p[:, 0]], axis=1)
    print(f"{nm:12s} Earth distance, year 2 − year 1 at the same longitude: median {np.median(d):+.2e} AU, "
          f"|·| p95 {np.percentile(np.abs(d), 95):.2e} AU")
