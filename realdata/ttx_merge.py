"""Merge the per-patch extraction files of realdata/talltable_extract.py into one CSV with the sub-pixel centres (RA, Dec)
and mid-exposure time, for ZodiPy (realdata/ttx_zodipy.py) and our model (realdata/ttx_ours.jl) on the ThinkPad.

    ~/envs/talltable/bin/python realdata/ttx_merge.py G SUB   → data/tt_train/ttx_L6_g<G>_sub<SUB>.csv
"""
import sys
from pathlib import Path
import duckdb
import healpy as hp
import numpy as np

G, SUB = int(sys.argv[1]), int(sys.argv[2])
D = Path(__file__).resolve().parent.parent / "data" / "tt_train"
files = sorted(D.glob(f"ttx_L6_g{G}_sub{SUB}_g{G}_*.parquet"))
t = duckdb.sql(f"SELECT regexp_extract(filename, 'g{G}_[0-9]+(?=\\.parquet)') AS patch, imageid, subpix, "
               "0.5 * (t_beg + t_end) AS t_mid_mjd, wavelength, n_pix, flux_median, zodi_median, flux_q25, flux_q75 "
               f"FROM read_parquet({[str(f) for f in files]}, filename=true) ORDER BY patch, t_mid_mjd, subpix").fetchnumpy()
ra, dec = hp.pix2ang(2 ** SUB, t["subpix"].astype(np.int64), nest=True, lonlat=True)
out = D / f"ttx_L6_g{G}_sub{SUB}.csv"
cols = ["patch", "imageid", "subpix", "t_mid_mjd", "wavelength", "n_pix", "flux_median", "zodi_median", "flux_q25", "flux_q75"]
with open(out, "w") as f:
    f.write(",".join(cols + ["ra", "dec"]) + "\n")
    for k in range(len(ra)):
        f.write(",".join([str(t[c][k]) for c in cols] + [f"{ra[k]:.6f}", f"{dec[k]:.6f}"]) + "\n")
print(f"{len(files)} patches, {len(ra)} rows, {len(np.unique(t['imageid']))} exposures -> {out}")
