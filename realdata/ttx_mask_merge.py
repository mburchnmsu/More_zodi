"""Merge the star-masked extraction files (TTX_MASK=1 realdata/talltable_extract.py) into one CSV keyed like the unmasked
table (patch, imageid, subpix), so sweeps/train_real.jl can join the masked medians onto the existing rows.

    ~/envs/talltable/bin/python realdata/ttx_mask_merge.py G SUB   → data/tt_train/ttx_L6_g<G>_sub<SUB>_mask.csv
"""
import sys
from pathlib import Path
import duckdb

G, SUB = int(sys.argv[1]), int(sys.argv[2])
D = Path(__file__).resolve().parent.parent / "data" / "tt_train"
files = sorted(D.glob(f"ttxm_L6_g{G}_sub{SUB}_g{G}_*.parquet"))
out = D / f"ttx_L6_g{G}_sub{SUB}_mask.csv"
duckdb.sql(f"COPY (SELECT regexp_extract(filename, '(g{G}_[0-9]+)\\.parquet$', 1) AS patch, imageid, subpix, n_pix, n_clean, "
           "flux_med_clean, zodi_med_clean, wavelength_clean, flux_q25_clean, flux_q75_clean "
           f"FROM read_parquet({[str(f) for f in files]}, filename=true) ORDER BY patch, t_beg, subpix) TO '{out}' (HEADER)")
n, nc, npix = duckdb.sql(f"SELECT count(*), sum(n_clean), sum(n_pix) FROM read_csv('{out}')").fetchone()
print(f"{len(files)} patches, {n} rows, {nc}/{npix} pixels kept ({100 * nc / npix:.1f}%) -> {out}")
