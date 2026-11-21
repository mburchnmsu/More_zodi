"""Week 15 task 4: condense the full-sky difference-image medians (tt_diffmed.py output, one file per partition) into
two small tables that can be fetched and plotted locally.
    $TALLTABLE_PYTHON -u realdata/tt_diffmed_summary.py [OUTDIR] [DEST]
  DEST/tt_diffmed_exposures.parquet  one row per exposure, combined over the partitions it touches:
      t_beg, t_end (from image.parquet), n_part, n_kept, med_d (median over partitions), wmean_d (n_kept-weighted mean),
      zodi (n_kept-weighted mean of the per-partition median ZODI), z_emp = zodi + wmean_d, lam (weighted mean wavelength)
  DEST/tt_diffmed_parts.parquet      one row per partition (id = 4·4^k + ipix with the pixel at order k − 3, nested):
      order, ipix, ra, dec, elon, elat, n_exp, med_d, mad_d (spread of the per-exposure medians over time),
      ratio (median z_emp / ZODI), zodi (median ZODI)
Then prints the same overall summary as tt_diffmed_verify.py."""
import os, sys
from pathlib import Path
import duckdb, numpy as np, healpy as hp

OUT = Path(sys.argv[1] if len(sys.argv) > 1 else Path.home() / "More_zodi/data/tt_diffmed")
DEST = Path(sys.argv[2] if len(sys.argv) > 2 else Path.home() / "More_zodi/data")
DB = Path("/fs1/project/18-interstellar/data/talltable")
con = duckdb.connect()
con.execute(f"SET memory_limit='{os.environ.get('TTD_MEM', '10GB')}'")
con.execute("SET preserve_insertion_order=false")
if os.environ.get("TMPDIR"):
    con.execute(f"SET temp_directory='{os.environ['TMPDIR']}/duckdb_tmp'")
con.execute(f"CREATE TABLE r AS SELECT * FROM read_parquet('{OUT}/*.parquet') WHERE n_kept > 0 AND med_d IS NOT NULL")
print("rows:", con.execute("SELECT count(*), count(DISTINCT partition), count(DISTINCT imageid) FROM r").fetchone(), flush=True)

con.execute(f"""COPY (
    SELECT r.imageid, any_value(i.t_beg) AS t_beg, any_value(i.t_end) AS t_end, count(*) AS n_part, sum(n_kept) AS n_kept,
           median(med_d) AS med_d, sum(med_d * n_kept) / sum(n_kept) AS wmean_d,
           sum(med_zodi * n_kept) / sum(n_kept) AS zodi, sum(med_zodi * n_kept) / sum(n_kept) + sum(med_d * n_kept) / sum(n_kept) AS z_emp,
           sum(med_lam * n_kept) / sum(n_kept) AS lam
    FROM r JOIN read_parquet('{DB}/image.parquet') i USING (imageid) GROUP BY r.imageid ORDER BY t_beg
) TO '{DEST}/tt_diffmed_exposures.parquet' (FORMAT parquet)""")

P = con.execute("""SELECT partition, count(*) AS n_exp, median(med_d) AS med_d,
                          quantile_cont(med_d, 0.75) - quantile_cont(med_d, 0.25) AS iqr_d,
                          median(z_emp / med_zodi) AS ratio, median(med_zodi) AS zodi
                   FROM r GROUP BY partition ORDER BY partition""").fetchnumpy()
nu = P["partition"].astype(np.int64)
# the id is 4·4^k + ipix, but each partition spans 4^16 level-22 cells (hphigh 0..2^32 for id 4^10), so the pixel is
# ipix at order k − 3 (orders 6–9: ~0.9° down to 6.9′); checked on the hphigh range of parts 1048576 and 1048577
k = (np.floor(np.log2(nu // 4) / 2)).astype(np.int64)
order = k - 3
ipix = nu - 4 * 4 ** k
ra = np.empty(len(nu)); dec = np.empty(len(nu))
for o in np.unique(order):
    m = order == o
    ra[m], dec[m] = hp.pix2ang(2 ** int(o), ipix[m], nest=True, lonlat=True)
elon, elat = hp.Rotator(coord=["C", "E"])(ra, dec, lonlat=True)
import pyarrow as pa, pyarrow.parquet as pq
pq.write_table(pa.table({"partition": nu, "order": order, "ipix": ipix, "ra": ra, "dec": dec, "elon": np.mod(elon, 360), "elat": elat,
                         "n_exp": P["n_exp"], "med_d": P["med_d"], "mad_d": P["iqr_d"] / 1.349,
                         "ratio": P["ratio"], "zodi": P["zodi"]}), DEST / "tt_diffmed_parts.parquet")

s = con.execute("""SELECT count(DISTINCT partition), count(*), sum(n_kept), quantile_cont(z_emp, [0.01, 0.5, 0.99]),
        quantile_cont(z_emp / med_zodi, [0.01, 0.5, 0.99]), quantile_cont(med_d, [0.01, 0.5, 0.99]) FROM r""").fetchone()
print(f"all outputs: {s[0]} partitions, {s[1]:,} exposure rows, {s[2]:,} pixels kept; z_emp 1/50/99%: {s[3]}; "
      f"z_emp / ZODI: {s[4]}; median d: {s[5]}", flush=True)
for f in ("tt_diffmed_exposures.parquet", "tt_diffmed_parts.parquet"):
    print(f, os.path.getsize(DEST / f) // 1024, "kB", flush=True)
