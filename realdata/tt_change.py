"""Week 15 task 6 (redefined Nov 22): the CHANGE of the sky over time, per exposure × level-9 cell (6.9′), sky-wide, from
the full tall table on Colibrí (read only: /fs1/project/18-interstellar/data/talltable). No absolute level is borrowed:
the network is trained on these changes only (sweeps/train_change.jl). One partition at a time:
  1. pixels at 4.9–5.1 μm with flags == 0 (stars and every other flagged pixel masked)
  2. scale each pixel to 5.0 μm with one fixed power law, f5 = flux × (5.0/λ)^ALPHA (no λ input to the network, user's
     choice; ALPHA = 6.1 is the within-exposure slope of the masked flux on the 192 local patches, see choices log)
  3. c = f5 − the pixel's (HEALPix level 15, 6.4″) median of f5 over time (cells with ≥ MIN_N visits): the static sky
     (stars below the mask, galaxies, CIB, DGL) and the time-average zodi cancel, the change remains
  4. per (exposure, level-9 cell): 3σ clip of c with σ = 1.4826 × MAD about the median, then the median of the kept pixels
  The same is done for SPHEREx's ZODI (scaled the same way), for the baseline only: cz = its change on the kept pixels.
Output: one parquet per partition in OUT (default data/tt_change): partition, imageid, cell9, n_pix, n_kept, c, cz,
f5 (median scaled flux), z5 (median scaled ZODI, for % only), lam (median λ, for diagnostics).
    $TALLTABLE_PYTHON -u realdata/tt_change.py TASK NTASKS        (partitions parts[TASK-1 :: NTASKS] of parts.txt)
    TTC_PARTS=id1:id2:... (only these partitions); TTC_ALPHA, TTC_OUT, TTD_MEM as in tt_diffmed.py
"""
import os, sys, time
from pathlib import Path
import duckdb

DB = Path(os.environ.get("TALLTABLE_DB_DIR", "/fs1/project/18-interstellar/data/talltable"))
OUT = Path(os.environ.get("TTC_OUT", Path(__file__).resolve().parent.parent / "data" / "tt_change")); OUT.mkdir(parents=True, exist_ok=True)
LAM_LO, LAM_HI, MIN_N, LEVEL, CELL = 4.9, 5.1, 5, 15, 9
ALPHA = float(os.environ.get("TTC_ALPHA", "6.1"))
SHIFT, SHIFT9 = 2 * (22 - LEVEL), 2 * (22 - CELL)                    # hphigh is HEALPix level 22, nested
task, ntask = (int(sys.argv[1]), int(sys.argv[2])) if len(sys.argv) >= 3 else (1, 1)
if os.environ.get("TTC_PARTS"):
    parts = os.environ["TTC_PARTS"].replace(":", ",").split(",")
else:
    parts = [l.strip() for l in open(DB / "parts.txt") if l.strip()][task - 1::ntask]
def connect():
    c = duckdb.connect()
    c.execute(f"SET threads TO {os.environ.get('SLURM_CPUS_PER_TASK', '4')}")
    c.execute(f"SET memory_limit = '{os.environ.get('TTD_MEM', '10GB')}'"); c.execute("SET preserve_insertion_order = false")
    c.execute(f"SET temp_directory = '{os.environ.get('TMPDIR', '/tmp')}/ttc_{os.getpid()}'")
    c.execute(f"CREATE TEMP TABLE w AS SELECT waveid, wavelength, pow(5.0 / wavelength, {ALPHA}) AS k "
              f"FROM read_parquet('{DB / 'waves.parquet'}') WHERE wavelength BETWEEN {LAM_LO} AND {LAM_HI}")
    return c
con = connect()
print(f"task {task}/{ntask}: {len(parts)} partitions, α = {ALPHA}", flush=True)
t_all = time.time(); nd = 0
for p in parts:
    out = OUT / f"part={p}.parquet"
    if out.exists():
        continue
    if nd and nd % 200 == 0:
        con.close(); con = connect()
    f = DB / "pixels" / f"part={p}" / "compacted.parquet"
    t0 = time.time()
    sql = f"""
    WITH px AS (SELECT imageid, hphigh >> {SHIFT} AS c15, hphigh >> {SHIFT9} AS cell9, flux * w.k AS f5, zodi * w.k AS z5,
                       w.wavelength AS lam
                FROM read_parquet('{f}') JOIN w USING (waveid) WHERE flags = 0 AND isfinite(flux) AND isfinite(zodi)),
         ref AS (SELECT c15, median(f5) AS fref, median(z5) AS zref FROM px GROUP BY c15 HAVING count(*) >= {MIN_N}),
         d AS (SELECT imageid, cell9, f5, z5, lam, f5 - fref AS c, z5 - zref AS cz FROM px JOIN ref USING (c15)),
         m1 AS (SELECT imageid, cell9, median(c) AS m FROM d GROUP BY imageid, cell9),
         m2 AS (SELECT imageid, cell9, m, median(abs(c - m)) AS mad FROM d JOIN m1 USING (imageid, cell9) GROUP BY imageid, cell9, m),
         k AS (SELECT d.*, abs(c - m) <= 3 * 1.4826 * mad AS keep FROM d JOIN m2 USING (imageid, cell9))
    SELECT {p}::BIGINT AS partition, imageid, cell9, count(*)::INT AS n_pix, count(*) FILTER (WHERE keep)::INT AS n_kept,
           median(c) FILTER (WHERE keep)::FLOAT AS c, median(cz) FILTER (WHERE keep)::FLOAT AS cz,
           median(f5)::FLOAT AS f5, median(z5)::FLOAT AS z5, median(lam)::FLOAT AS lam
    FROM k GROUP BY imageid, cell9 HAVING count(*) >= 20 ORDER BY imageid, cell9"""
    tmp = OUT / f".part={p}.parquet.tmp"
    try:
        con.execute(f"COPY ({sql}) TO '{tmp}' (FORMAT parquet)"); tmp.rename(out)
    except duckdb.Error as e:
        print(f"part={p}: FAILED {type(e).__name__}: {e}", flush=True); nd += 1; continue
    n = con.execute(f"SELECT count(*), coalesce(sum(n_kept), 0) FROM read_parquet('{out}')").fetchone(); nd += 1
    print(f"part={p}: {n[0]} rows, {n[1]} pixels kept, {f.stat().st_size / 1e9:.2f} GB read in {time.time() - t0:.1f} s", flush=True)
print(f"done: {nd} partitions in {time.time() - t_all:.0f} s", flush=True)
