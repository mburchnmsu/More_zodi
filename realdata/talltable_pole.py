"""First query of the NYU SPHEREx "tall table" (http://connorhainje.com/talltable) through its web service: the pixels
around one sky position at ~5 um, then one row per exposure (median flux, median SPHEREx ZODI layer, time).
Runs on Discovery (the client needs healpy, which has no Windows build):

    ~/envs/talltable/bin/python realdata/talltable_pole.py probe            # tiny query: columns, wavelength units
    ~/envs/talltable/bin/python realdata/talltable_pole.py run [RA Dec R]   # R = disc radius in arcmin (default 1.6)

Default target: the north ecliptic pole (RA 270, Dec 66.560708), as in realdata/extract_frames.py; R = 1.6' matches its
31x31-pixel (~3.2') box. Median, not mean, so stars (no masking yet) barely move it. Flags are not used yet.
Output: data/spherex_real/tt_<name>_pixels.parquet (all pixels) and tt_<name>_per_image.csv (one row per exposure).
"""
import sys, time
from pathlib import Path
import numpy as np
import pyarrow.compute as pc
from talltable import PixelQuery

OUT = Path(__file__).resolve().parent.parent / "data" / "spherex_real"
LAM_LO, LAM_HI = 4.9, 5.1
mode = sys.argv[1] if len(sys.argv) > 1 else "probe"
ra, dec = (float(sys.argv[2]), float(sys.argv[3])) if len(sys.argv) > 3 else (270.0, 66.560708)
radius = float(sys.argv[4]) if len(sys.argv) > 4 else 1.6

if mode == "probe":
    q = PixelQuery(web=True).disc(ra, dec, 0.2).with_wavelengths().with_image()
    print(q.sql()[:2000])
    t0 = time.time(); t = q.execute(); dt = time.time() - t0
    print(f"\n{t.num_rows} rows in {dt:.1f} s; columns: {t.column_names}")
    for c in ("wavelength", "bandwidth", "flux", "zodi", "t_beg", "t_end"):
        if c in t.column_names:
            print(f"  {c:10s} min {pc.min(t[c]).as_py()}  max {pc.max(t[c]).as_py()}")
    print(t.slice(0, 5).to_pandas() if hasattr(t, "to_pandas") else t.slice(0, 5))
    sys.exit(0)

name = "nep" if (ra, dec) == (270.0, 66.560708) else f"{ra:.3f}_{dec:+.3f}"
OUT.mkdir(parents=True, exist_ok=True)
q = PixelQuery(web=True).disc(ra, dec, radius).wavelength(LAM_LO, LAM_HI).with_wavelengths().with_image()
t0 = time.time(); q.execute_to_parquet(str(OUT / f"tt_{name}_pixels.parquet")); dt = time.time() - t0
import pyarrow.parquet as pq
t = pq.read_table(OUT / f"tt_{name}_pixels.parquet")
print(f"{t.num_rows} pixels in {dt:.1f} s; wavelength {pc.min(t['wavelength']).as_py()}-{pc.max(t['wavelength']).as_py()}")
img = t["imageid"].to_numpy(); order = np.argsort(img, kind="stable"); img = img[order]
cols = {c: t[c].to_numpy()[order] for c in ("flux", "zodi", "wavelength", "t_beg", "t_end")}
cut = np.flatnonzero(np.diff(img)) + 1
with open(OUT / f"tt_{name}_per_image.csv", "w") as f:
    f.write("imageid,t_mid_mjd,n_pix,wavelength_median,flux_median,zodi_median\n")
    for s, e in zip(np.r_[0, cut], np.r_[cut, len(img)]):
        tm = 0.5 * (cols["t_beg"][s] + cols["t_end"][s])
        f.write(f"{img[s]},{tm:.6f},{e - s},{np.median(cols['wavelength'][s:e]):.4f},"
                f"{np.nanmedian(cols['flux'][s:e]):.6f},{np.nanmedian(cols['zodi'][s:e]):.6f}\n")
print(f"{len(cut) + 1} exposures -> {OUT / f'tt_{name}_per_image.csv'}")
