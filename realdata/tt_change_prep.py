"""Week 15 task 6: build the training table for sweeps/train_change.jl from the tt_change.py outputs (on Colibrí).
Takes every STRIDE-th partition (default 32, ~2000 partitions spread over the sky), joins each exposure's ephemeris
(realdata/exposure_ephem.py, uploaded as data/tt_change_ephem.csv), and computes the onboarding registry dot products in
the ecliptic frame: n̂ = level-9 cell centre (the tall table's HEALPix is equatorial), S⃗ = Earth (barycentric, AU),
ẑ = ecliptic pole, v̂_E = Earth's velocity direction.
    $TALLTABLE_PYTHON -u realdata/tt_change_prep.py [STRIDE]
  → data/tt_change_train.f32 (Float32, row-major, columns in data/tt_change_train.cols) and data/tt_change_train.cell
    (Int64 cell9 per row). Rows are sorted by cell9, then time."""
import os, sys
from pathlib import Path
import duckdb, numpy as np, healpy as hp

R = Path(__file__).resolve().parent.parent
SRC, STRIDE = R / "data" / "tt_change", int(sys.argv[1]) if len(sys.argv) > 1 else 32
DB = Path("/fs1/project/18-interstellar/data/talltable")
parts = [l.strip() for l in open(DB / "parts.txt") if l.strip()][::STRIDE]
files = [str(SRC / f"part={p}.parquet") for p in parts if (SRC / f"part={p}.parquet").exists()]
print(f"{len(files)} of {len(parts)} partitions (stride {STRIDE}) present", flush=True)
con = duckdb.connect(); con.execute(f"SET memory_limit = '{os.environ.get('TTD_MEM', '20GB')}'")
X = con.execute(f"""SELECT r.cell9, e.t_mid, r.c, r.cz, r.f5, r.z5, r.lam, r.n_kept, e.Sx, e.Sy, e.Sz, e.vx, e.vy, e.vz
    FROM read_parquet({files}) r JOIN read_csv('{R / "data" / "tt_change_ephem.csv"}') e USING (imageid)
    WHERE r.c IS NOT NULL AND r.n_kept >= 20 ORDER BY r.cell9, e.t_mid""").fetchnumpy()
cell = X["cell9"].astype(np.int64)
ra, dec = hp.pix2ang(512, cell, nest=True, lonlat=True)
el, eb = hp.Rotator(coord=["C", "E"])(ra, dec, lonlat=True)
n = np.vstack([np.cos(np.deg2rad(eb)) * np.cos(np.deg2rad(el)), np.cos(np.deg2rad(eb)) * np.sin(np.deg2rad(el)), np.sin(np.deg2rad(eb))])
S = np.vstack([X["Sx"], X["Sy"], X["Sz"]]); v = np.vstack([X["vx"], X["vy"], X["vz"]]); v /= np.linalg.norm(v, axis=0)
dot = lambda a, b: np.sum(a * b, axis=0)
cols = {"t_mid": X["t_mid"], "c": X["c"], "cz": X["cz"], "f5": X["f5"], "z5": X["z5"], "lam": X["lam"], "n_kept": X["n_kept"],
        "elon": np.mod(el, 360), "elat": eb,
        "n·S": dot(n, S), "n·z": n[2], "S·z": S[2], "S·S": dot(S, S), "n·v": dot(n, v), "S·v": dot(S, v), "z·v": v[2]}
M = np.column_stack([np.asarray(c, dtype=np.float64) for c in cols.values()])
M[:, 0] -= 60000.0                                   # keep time precise in Float32 (MJD − 60000)
M.astype("<f4").tofile(R / "data" / "tt_change_train.f32"); cell.astype("<i8").tofile(R / "data" / "tt_change_train.cell")
open(R / "data" / "tt_change_train.cols", "w").write("\n".join(cols) + "\n")
print(f"{len(cell):,} rows, {len(np.unique(cell)):,} cells, {M.shape[1]} columns -> data/tt_change_train.*", flush=True)
