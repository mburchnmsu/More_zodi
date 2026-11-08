"""The mentor's binning task (Week 13): pick a HEALPix nside, bin the tall table to large areas, and per exposure take the
median over each area at ~5 um; plot it as a function of time, then subtract each area's mean over all exposures.
The median is computed BY THE SERVER (GROUP BY imageid around the client's own generated SQL), so only one row per
exposure comes back, not millions of pixels. Runs on Discovery (~/envs/talltable; healpy).

    ~/envs/talltable/bin/python realdata/talltable_bins.py LEVEL NAME:RA:DEC [NAME:RA:DEC ...]
      LEVEL = HEALPix level of the areas (6 → nside 64, 0.92° pixels); each NAME:RA:DEC picks the level-LEVEL pixel
      containing that position. → data/spherex_real/ttbin_L<LEVEL>_<NAME>.csv (one row per exposure)
    ~/envs/talltable/bin/python realdata/talltable_bins.py LEVEL grid G     (one patch per level-G pixel centre)
    Patches already on disk are skipped, so a stopped run can be restarted.
    With TALLTABLE_LOCAL=1 (and TALLTABLE_DB_DIR set), the same SQL runs in DuckDB on a local copy of the partitions
    (downloaded by pipeline/cluster/talltable_download.sbatch) instead of on the web service.
"""
import os, sys, time
from pathlib import Path
import healpy as hp
import requests
from talltable import PixelQuery
from talltable.client import fetch_arrow_stream

OUT = Path(__file__).resolve().parent.parent / "data" / "spherex_real"
LAM_LO, LAM_HI = 4.9, 5.1          # microns (data stop at ~5.01)
WTAG = ""                          # TT_LAM=lo:hi picks another wavelength window; its files get the suffix _w<lo>
if os.environ.get("TT_LAM"):
    LAM_LO, LAM_HI = map(float, os.environ["TT_LAM"].split(":")); WTAG = f"_w{LAM_LO:g}"
LOCAL = os.environ.get("TALLTABLE_LOCAL") == "1"
if LOCAL:
    import duckdb
    DB_DIR = Path(os.environ["TALLTABLE_DB_DIR"])
level = int(sys.argv[1])
OUT.mkdir(parents=True, exist_ok=True)
specs = sys.argv[2:]
if specs and specs[0] == "grid":
    # grid G: one patch at the centre of every level-G HEALPix pixel (G = 1 → 48 patches, ~30° apart); the centres are
    # written to ttbin_L<level>_grid<G>_centres.csv
    G = int(specs[1]); nside = 2 ** G
    ra_c, dec_c = hp.pix2ang(nside, range(12 * nside ** 2), nest=True, lonlat=True)
    specs = [f"g{G}_{i:03d}:{r:.5f}:{d:.5f}" for i, (r, d) in enumerate(zip(ra_c, dec_c))]
    with open(OUT / f"ttbin_L{level}_grid{G}_centres.csv", "w") as f:
        f.write("name,ra,dec\n"); f.writelines(s.replace(":", ",") + "\n" for s in specs)
for spec in specs:
    name, ra, dec = spec.split(":"); ra, dec = float(ra), float(dec)
    if (OUT / f"ttbin_L{level}_{name}{WTAG}.csv").exists():
        print(f"{name}: already done"); continue
    pix = int(hp.ang2pix(2 ** level, ra, dec, nest=True, lonlat=True))
    q = PixelQuery(web=not LOCAL).ipix([pix], level).wavelength(LAM_LO, LAM_HI).with_wavelengths().with_image()
    parts = q.partitions(); inner = q._local_sql(parts) if LOCAL else q._web_sql(parts)
    assert "i.filepath" in inner
    inner = inner.replace("i.filepath", "i.filepath, i.t_beg, i.t_end", 1)
    sql = ("SELECT imageid, min(t_beg) AS t_beg, min(t_end) AS t_end, count(*) AS n_pix, median(wavelength) AS wavelength, "
           "median(flux) AS flux_median, median(zodi) AS zodi_median, quantile_cont(flux, 0.25) AS flux_q25, "
           "quantile_cont(flux, 0.75) AS flux_q75 FROM (" + inner + ") GROUP BY imageid ORDER BY t_beg")
    t = None
    if LOCAL:
        missing = [p for p in parts if not (DB_DIR / "pixels" / f"part={p}" / "compacted.parquet").exists()]
        if missing:
            print(f"{name}: partitions not downloaded: {missing}", flush=True); continue
        t0 = time.time(); con = duckdb.connect()
        try:
            t = con.execute(sql).fetch_arrow_table()
        finally:
            con.close()
        dt = time.time() - t0
    for attempt in range(0 if LOCAL else 12):                         # the service answers 503 "busy with other queries" at times
        try:
            t0 = time.time()
            t = fetch_arrow_stream(f"{q._base_url}/sql", {"query": sql, "partitions": parts})
            dt = time.time() - t0
            break
        except Exception as e:                        # anything else (time/memory limit, …): report, go on to the next patch
            msg = str(e)
            down = any(s in msg for s in ("invalidated", "502", "504", "Connection"))   # server restarting: wait longer
            if not (down or "503" in msg) or attempt == 11:
                print(f"{name}: FAILED after {time.time() - t0:.0f} s: {msg[:300]}", flush=True); break
            wait = 600 if down else 60
            print(f"  {name}: server {'down' if down else 'busy'}, retry {attempt + 1} in {wait} s", flush=True); time.sleep(wait)
    if t is None:
        continue
    out = OUT / f"ttbin_L{level}_{name}{WTAG}.csv"
    cols = t.column_names; data = [t[c].to_pylist() for c in cols]
    with open(out, "w") as f:
        f.write(",".join(cols) + "\n")
        for row in zip(*data):
            f.write(",".join(str(v) for v in row) + "\n")
    print(f"{name}: level-{level} pixel {pix} ({hp.nside2resol(2 ** level, arcmin=True) / 60:.2f} deg), {len(parts)} partition(s), "
          f"{t.num_rows} exposures, {sum(data[cols.index('n_pix')])} pixels, {dt:.1f} s -> {out.name}")
