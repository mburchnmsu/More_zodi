"""Week 14 task 7a: a real-data training set from the tall table. For every grid-G patch (level-6 HEALPix pixel at a level-G
pixel centre, as in talltable_bins.py), per exposure AND per level-SUB sub-pixel: median flux, median zodi (SPHEREx's ZODI
layer), median wavelength, pixel count, time. Runs DuckDB on the local partitions on Discovery scratch (TALLTABLE_DB_DIR).

    ~/envs/talltable/bin/python realdata/talltable_extract.py G SUB [first last]
      → data/tt_train/ttx_L6_g<G>_sub<SUB>_<name>.parquet, one file per patch (patches already on disk are skipped)
"""
import os, sys, time
from pathlib import Path
import healpy as hp
import duckdb
from talltable import PixelQuery

LAM_LO, LAM_HI = 4.9, 5.1                                            # microns (data stop at ~5.01)
LEVEL = 6
DB_DIR = Path(os.environ["TALLTABLE_DB_DIR"])
OUT = Path(__file__).resolve().parent.parent / "data" / "tt_train"; OUT.mkdir(parents=True, exist_ok=True)
G, SUB = int(sys.argv[1]), int(sys.argv[2]); assert LEVEL <= SUB <= 22
nside = 2 ** G
ra_c, dec_c = hp.pix2ang(nside, range(12 * nside ** 2), nest=True, lonlat=True)
idx = range(len(ra_c))
if len(sys.argv) >= 5:
    idx = range(int(sys.argv[3]), min(int(sys.argv[4]) + 1, len(ra_c)))
shift = 2 * (22 - SUB)                                                # hphigh is HEALPix level 22, nested
t_all = time.time(); rows_all = 0
for i in idx:
    name = f"g{G}_{i:03d}"; out = OUT / f"ttx_L{LEVEL}_g{G}_sub{SUB}_{name}.parquet"
    if out.exists():
        print(f"{name}: already done", flush=True); continue
    # rounded exactly as talltable_bins.py / talltable_local_size.py: a level-G centre is a corner of 4 level-6 pixels,
    # so the rounding decides which one (and which downloaded partition) is used
    ra, dec = float(f"{ra_c[i]:.5f}"), float(f"{dec_c[i]:.5f}")
    pix = int(hp.ang2pix(2 ** LEVEL, ra, dec, nest=True, lonlat=True))
    q = PixelQuery(web=False).ipix([pix], LEVEL).wavelength(LAM_LO, LAM_HI).with_wavelengths().with_image()
    parts = q.partitions(); inner = q._local_sql(parts)
    missing = [p for p in parts if not (DB_DIR / "pixels" / f"part={p}" / "compacted.parquet").exists()]
    if missing:
        print(f"{name}: partitions not downloaded: {missing}", flush=True); continue
    assert "i.filepath" in inner and "hphigh" in inner, "inner SQL lacks i.filepath or hphigh"
    inner = inner.replace("i.filepath", "i.filepath, i.t_beg, i.t_end", 1)
    sql = (f"SELECT imageid, (hphigh >> {shift}) AS subpix, min(t_beg) AS t_beg, min(t_end) AS t_end, count(*) AS n_pix, "
           "median(wavelength) AS wavelength, median(flux) AS flux_median, median(zodi) AS zodi_median, "
           "quantile_cont(flux, 0.25) AS flux_q25, quantile_cont(flux, 0.75) AS flux_q75 "
           f"FROM ({inner}) GROUP BY imageid, subpix ORDER BY t_beg, subpix")
    t0 = time.time(); con = duckdb.connect()
    try:
        con.execute(f"COPY ({sql}) TO '{out}.tmp' (FORMAT PARQUET)")
        n = con.execute(f"SELECT count(*) FROM read_parquet('{out}.tmp')").fetchone()[0]
    finally:
        con.close()
    os.replace(f"{out}.tmp", out); rows_all += n
    print(f"{name}: level-6 pixel {pix}, {len(parts)} partition(s), {n} rows, {time.time() - t0:.1f} s", flush=True)
print(f"done: {rows_all} rows in {time.time() - t_all:.0f} s", flush=True)
