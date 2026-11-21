"""Week 15 task 4: the median of zodi-cleaned difference images per exposure, sky-wide, from the full tall table on Colibrí
(read only: /fs1/project/18-interstellar/data/talltable). One partition at a time:
  1. pixels at 4.9–5.1 μm with flags == 0 (every flagged pixel masked: sources, transients, outliers, detector defects)
  2. s = flux − zodi (SPHEREx's zodi layer removed first, so the reference does not depend on each pixel's wavelength)
  3. reference = per sky cell (HEALPix level 15, 6.4″ ≈ one SPHEREx pixel) median of s over time (cells with ≥ MIN_N)
  4. d = s − reference (stars, galaxies, CIB, DGL cancel; what is left is zodi's error + noise)
  5. per exposure: 3σ clipping of d with σ = 1.4826 × MAD about the median, then the median of the kept pixels
  → empirical zodi of the exposure = median(zodi) + median(d) (the column to compare with SPHEREx's ZODI)
Output: one small parquet per partition in OUT (default data/tt_diffmed): partition, imageid, n_pix, n_kept, med_zodi,
med_flux, med_d, mad_d, z_emp, med_lam. Partitions already written are skipped, so a resubmitted array is safe.
    $TALLTABLE_PYTHON -u realdata/tt_diffmed.py TASK NTASKS        (partitions parts[TASK-1 :: NTASKS] of parts.txt)
    TTD_PARTS=id1,id2 ... (only these partitions; the timing test)
"""
import os, sys, time
from pathlib import Path
import duckdb

DB = Path(os.environ.get("TALLTABLE_DB_DIR", "/fs1/project/18-interstellar/data/talltable"))
OUT = Path(os.environ.get("TTD_OUT", Path(__file__).resolve().parent.parent / "data" / "tt_diffmed")); OUT.mkdir(parents=True, exist_ok=True)
LAM_LO, LAM_HI, MIN_N, LEVEL = 4.9, 5.1, 5, 15
SHIFT = 2 * (22 - LEVEL)                                             # hphigh is HEALPix level 22, nested
task, ntask = (int(sys.argv[1]), int(sys.argv[2])) if len(sys.argv) >= 3 else (1, 1)
if os.environ.get("TTD_PARTS"):
    parts = os.environ["TTD_PARTS"].split(",")
else:
    parts = [l.strip() for l in open(DB / "parts.txt") if l.strip()][task - 1::ntask]
con = duckdb.connect(); con.execute(f"SET threads TO {os.environ.get('SLURM_CPUS_PER_TASK', '4')}")
con.execute(f"CREATE TEMP TABLE w AS SELECT waveid, wavelength FROM read_parquet('{DB / 'waves.parquet'}') "
            f"WHERE wavelength BETWEEN {LAM_LO} AND {LAM_HI}")
print(f"task {task}/{ntask}: {len(parts)} partitions, {con.execute('SELECT count(*) FROM w').fetchone()[0]} wave ids in "
      f"{LAM_LO}–{LAM_HI} μm", flush=True)
t_all = time.time(); nd = 0
for p in parts:
    out = OUT / f"part={p}.parquet"
    if out.exists():
        continue
    f = DB / "pixels" / f"part={p}" / "compacted.parquet"
    t0 = time.time()
    sql = f"""
    WITH px AS (SELECT imageid, hphigh >> {SHIFT} AS c, flux, zodi, flux - zodi AS s, w.wavelength AS lam
                FROM read_parquet('{f}') JOIN w USING (waveid) WHERE flags = 0 AND isfinite(flux) AND isfinite(zodi)),
         ref AS (SELECT c, median(s) AS sref FROM px GROUP BY c HAVING count(*) >= {MIN_N}),
         d AS (SELECT imageid, zodi, flux, lam, s - sref AS d FROM px JOIN ref USING (c)),
         m1 AS (SELECT imageid, median(d) AS m FROM d GROUP BY imageid),
         m2 AS (SELECT imageid, m, median(abs(d - m)) AS mad FROM d JOIN m1 USING (imageid) GROUP BY imageid, m)
    SELECT {p}::BIGINT AS partition, imageid, count(*) AS n_pix,
           count(*) FILTER (WHERE abs(d - m) <= 3 * 1.4826 * mad) AS n_kept,
           median(zodi) AS med_zodi, median(flux) AS med_flux,
           median(d) FILTER (WHERE abs(d - m) <= 3 * 1.4826 * mad) AS med_d, any_value(mad) AS mad_d,
           median(zodi) + median(d) FILTER (WHERE abs(d - m) <= 3 * 1.4826 * mad) AS z_emp, median(lam) AS med_lam
    FROM d JOIN m2 USING (imageid) GROUP BY imageid ORDER BY imageid"""
    tmp = OUT / f".part={p}.parquet.tmp"
    con.execute(f"COPY ({sql}) TO '{tmp}' (FORMAT parquet)"); tmp.rename(out)
    n = con.execute(f"SELECT count(*), coalesce(sum(n_pix), 0) FROM read_parquet('{out}')").fetchone(); nd += 1
    print(f"part={p}: {n[0]} exposures, {n[1]} pixels kept, {f.stat().st_size / 1e9:.2f} GB read in {time.time() - t0:.1f} s",
          flush=True)
print(f"done: {nd} partitions in {time.time() - t_all:.0f} s", flush=True)
