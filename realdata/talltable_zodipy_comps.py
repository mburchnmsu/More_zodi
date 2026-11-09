"""Kelsall's six components (smooth cloud, dust bands 1-3, circumsolar ring, Earth-trailing feature) from ZodiPy, at every
exposure of every grid patch (realdata/talltable_bins.py ... grid G), at the exposure's wavelength. Used by
realdata/offset_comps.jl to ask which part of Kelsall is too faint. Observer = Earth, as in realdata/talltable_zodipy.py.

    python -I realdata/talltable_zodipy_comps.py LEVEL G [wtag]          (zodipy env)
    → data/spherex_real/ttbin_L<LEVEL>_<patch><wtag>_comps.csv (imageid, t_mid_mjd, wavelength, flux_median, zodi_median,
      zodipy_total and one column per component); patches already done are skipped
"""
import csv, sys
from pathlib import Path
import numpy as np
import astropy.units as u
from astropy.coordinates import SkyCoord
from astropy.time import Time
import zodipy

D = Path(__file__).resolve().parent.parent / "data" / "spherex_real"
level, G = int(sys.argv[1]), int(sys.argv[2]); wtag = sys.argv[3] if len(sys.argv) > 3 else ""
centres = list(csv.DictReader(open(D / f"ttbin_L{level}_grid{G}_centres.csv")))
models = {}


def model(wl):
    if wl not in models:
        models[wl] = zodipy.Model(x=wl * u.micron, name="dirbe", ephemeris="de432s")
    return models[wl]


names = list(model(5.0)._ipd_model.comps.keys())           # component order of return_comps
names = [str(getattr(n, "value", n)) for n in names]
print("components:", names, flush=True)
for c in centres:
    src = D / f"ttbin_L{level}_{c['name']}{wtag}.csv"; out = D / f"ttbin_L{level}_{c['name']}{wtag}_comps.csv"
    if not src.exists() or out.exists():
        continue
    rows = list(csv.DictReader(open(src)))
    if not rows:
        continue
    mjd = np.array([0.5 * (float(r["t_beg"]) + float(r["t_end"])) for r in rows])
    lam = np.round(np.array([float(r["wavelength"]) for r in rows]), 3)
    comps = np.zeros((len(names), len(rows)))
    for lr in np.unique(lam):
        m = lam == lr
        t = Time(mjd[m], format="mjd", scale="utc")
        sc = SkyCoord(np.full(m.sum(), float(c["ra"])) * u.deg, np.full(m.sum(), float(c["dec"])) * u.deg, frame="icrs", obstime=t)
        comps[:, m] = model(float(lr)).evaluate(sc, obspos="earth", return_comps=True).value
    with open(out, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["imageid", "t_mid_mjd", "wavelength", "flux_median", "zodi_median", "zodipy_total"] + [f"comp_{n}" for n in names])
        for i, r in enumerate(rows):
            w.writerow([r["imageid"], f"{mjd[i]:.6f}", r["wavelength"], r["flux_median"], r["zodi_median"], f"{comps[:, i].sum():.6f}"]
                       + [f"{v:.6g}" for v in comps[:, i]])
    print(f"{c['name']}: {len(rows)} exposures; cloud {np.median(comps[0] / comps.sum(0)):.1%} of the total", flush=True)
