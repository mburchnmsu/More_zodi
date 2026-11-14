"""ZodiPy (Kelsall/DIRBE, as for our training data) at every row of the 7a extraction (realdata/ttx_merge.py): at the row's
median wavelength and at 5.0 um, at the sub-pixel centre and mid-exposure time. Observer = Earth, as in talltable_zodipy.py.

    python -I realdata/ttx_zodipy.py data/tt_train/ttx_L6_g2_sub9.csv   (zodipy env)   → <input>_zodipy.csv
"""
import sys, time
import numpy as np
import astropy.units as u
from astropy.coordinates import SkyCoord
from astropy.time import Time
import zodipy

src = sys.argv[1]
hdr = open(src).readline().strip().split(",")
A = np.genfromtxt(src, delimiter=",", skip_header=1, dtype=None, encoding="utf-8", names=hdr)
mjd, lam, ra, dec = A["t_mid_mjd"], A["wavelength"], A["ra"], A["dec"]
n = len(mjd); print(f"{n} rows", flush=True)


def zp(wl, m):
    model = zodipy.Model(x=wl * u.micron, name="dirbe", ephemeris="de432s")
    c = SkyCoord(ra[m] * u.deg, dec[m] * u.deg, frame="icrs", obstime=Time(mjd[m], format="mjd", scale="utc"))
    return model.evaluate(c, obspos="earth").value


t0 = time.time()
z5 = zp(5.0, np.ones(n, bool)); print(f"5.0 um done in {time.time() - t0:.0f} s", flush=True)
z_lam = np.zeros(n); lr = np.round(lam / 0.005) * 0.005                  # one ZodiPy model per 0.005 um wavelength step
for w in np.unique(lr):
    m = lr == w; z_lam[m] = zp(float(w), m)
print(f"all wavelengths done in {time.time() - t0:.0f} s", flush=True)
out = src.replace(".csv", "_zodipy.csv")
with open(src) as fi, open(out, "w") as fo:
    fo.write(fi.readline().strip() + ",zodipy_lam,zodipy_5um\n")
    for line, a, b in zip(fi, z_lam, z5):
        fo.write(f"{line.strip()},{a:.6f},{b:.6f}\n")
print(f"-> {out}")
