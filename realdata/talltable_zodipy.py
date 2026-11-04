"""ZodiPy (Kelsall/DIRBE, as for our training data) for each exposure of a tall-table per-exposure table
(realdata/talltable_pole.py): at the exposure's median wavelength AND at 5.0 um, so our 5 um emulator can be moved to
each exposure's wavelength with ZodiPy's spectral shape: ours(lambda) = ours(5.0) * ZodiPy(lambda) / ZodiPy(5.0).
Observer = Earth (SPHEREx is ~7000 km away; negligible), as in realdata/extract_frames.py.

    python -I realdata/talltable_zodipy.py data/spherex_real/tt_nep_per_image.csv [RA Dec]   (zodipy env)
    → adds columns zodipy_lam, zodipy_5um → <input>_zodipy.csv
"""
import csv, sys
import numpy as np
import astropy.units as u
from astropy.coordinates import SkyCoord
from astropy.time import Time
import zodipy

src = sys.argv[1]
RA0, DEC0 = (float(sys.argv[2]), float(sys.argv[3])) if len(sys.argv) > 3 else (270.0, 66.560708)
rows = list(csv.DictReader(open(src)))
mjd = np.array([float(r["t_mid_mjd"]) for r in rows]); lam = np.array([float(r["wavelength_median"]) for r in rows])


def zp(wl, m):
    model = zodipy.Model(x=wl * u.micron, name="dirbe", ephemeris="de432s")
    t = Time(mjd[m], format="mjd", scale="utc")
    c = SkyCoord(np.full(m.sum(), RA0) * u.deg, np.full(m.sum(), DEC0) * u.deg, frame="icrs", obstime=t)
    return model.evaluate(c, obspos="earth").value


z_lam = np.zeros(len(rows)); z5 = zp(5.0, np.ones(len(rows), bool))
for lr in np.unique(np.round(lam, 3)):                   # one ZodiPy model per (rounded) wavelength
    m = np.round(lam, 3) == lr
    z_lam[m] = zp(lr, m)
out = src.replace(".csv", "_zodipy.csv")
with open(out, "w", newline="") as f:
    w = csv.writer(f); w.writerow(list(rows[0].keys()) + ["zodipy_lam", "zodipy_5um"])
    for r, a, b in zip(rows, z_lam, z5):
        w.writerow(list(r.values()) + [f"{a:.6f}", f"{b:.6f}"])
print(f"{len(rows)} exposures; ZodiPy(lambda)/ZodiPy(5.0) {np.min(z_lam / z5):.4f}-{np.max(z_lam / z5):.4f} -> {out}")
