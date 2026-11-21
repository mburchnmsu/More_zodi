"""Week 15: check realdata/tt_diffmed.py's output against an independent full read of the same partitions: total rows,
rows at 4.9–5.1 μm, unflagged rows there, the sum of flux over them (forces the flux column to be read), and the per-
exposure medians written by tt_diffmed.py (all exposures non-empty, values plausible).
    $TALLTABLE_PYTHON -u realdata/tt_diffmed_verify.py OUTDIR part1 part2 ...   (then a summary of every file in OUTDIR)"""
import sys, time
from pathlib import Path
import duckdb
DB = Path("/fs1/project/18-interstellar/data/talltable"); OUT = Path(sys.argv[1])
con = duckdb.connect()
con.execute(f"CREATE TEMP TABLE w AS SELECT waveid FROM read_parquet('{DB / 'waves.parquet'}') WHERE wavelength BETWEEN 4.9 AND 5.1")
for p in sys.argv[2:]:
    f = DB / "pixels" / f"part={p}" / "compacted.parquet"; t0 = time.time()
    n_all, n_band, n_clean, sflux, n_img = con.execute(f"""
        SELECT count(*), count(*) FILTER (WHERE w.waveid IS NOT NULL),
               count(*) FILTER (WHERE w.waveid IS NOT NULL AND flags = 0),
               sum(flux) FILTER (WHERE w.waveid IS NOT NULL AND flags = 0),
               count(DISTINCT imageid) FILTER (WHERE w.waveid IS NOT NULL AND flags = 0)
        FROM read_parquet('{f}') p LEFT JOIN w USING (waveid)""").fetchone()
    t_full = time.time() - t0
    o = con.execute(f"""SELECT count(*), sum(n_pix), sum(n_kept), count(*) FILTER (WHERE z_emp IS NULL OR n_kept = 0),
                        min(z_emp), median(z_emp), max(z_emp), median(med_zodi), median(med_d), median(mad_d)
                        FROM read_parquet('{OUT / f'part={p}.parquet'}')""").fetchone()
    print(f"part={p}: {f.stat().st_size / 1e9:.2f} GB, full read {t_full:.1f} s: {n_all:,} rows, {n_band:,} at 4.9–5.1 μm, "
          f"{n_clean:,} of them unflagged ({n_img} exposures), mean flux {sflux / max(n_clean, 1):.4f} MJy/sr", flush=True)
    print(f"   tt_diffmed output: {o[0]} exposures, {o[1]:,} pixels used (cells with ≥ 5 visits), {o[2]:,} kept after "
          f"clipping, {o[3]} empty; z_emp min/median/max {o[4]:.4f}/{o[5]:.4f}/{o[6]:.4f}, median ZODI {o[7]:.4f}, "
          f"median d {o[8]:+.5f}, median MAD {o[9]:.4f}", flush=True)
# summary over every output file in OUTDIR
s = con.execute(f"""SELECT count(DISTINCT partition), count(*), sum(n_kept), count(*) FILTER (WHERE z_emp IS NULL OR n_kept = 0),
        quantile_cont(z_emp, [0.01, 0.5, 0.99]), quantile_cont(z_emp / med_zodi, [0.01, 0.5, 0.99]),
        quantile_cont(med_d, [0.01, 0.5, 0.99]) FROM read_parquet('{OUT}/*.parquet')""").fetchone()
print(f"all outputs: {s[0]} partitions, {s[1]:,} exposure rows, {s[2]:,} pixels kept, {s[3]} empty; z_emp 1/50/99%: {s[4]}; "
      f"z_emp / ZODI: {s[5]}; median d: {s[6]}", flush=True)
