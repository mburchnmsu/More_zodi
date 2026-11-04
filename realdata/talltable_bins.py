"""The mentor's binning task (Week 13): pick a HEALPix nside, bin the tall table to large areas, and per exposure take the
median over each area at ~5 um; plot it as a function of time, then subtract each area's mean over all exposures.
The median is computed BY THE SERVER (GROUP BY imageid around the client's own generated SQL), so only one row per
exposure comes back, not millions of pixels. Runs on Discovery (~/envs/talltable; healpy).

    ~/envs/talltable/bin/python realdata/talltable_bins.py LEVEL NAME:RA:DEC [NAME:RA:DEC ...]
      LEVEL = HEALPix level of the areas (6 → nside 64, 0.92° pixels); each NAME:RA:DEC picks the level-LEVEL pixel
      containing that position. → data/spherex_real/ttbin_L<LEVEL>_<NAME>.csv (one row per exposure)
"""
import sys, time
from pathlib import Path
import healpy as hp
from talltable import PixelQuery
from talltable.client import fetch_arrow_stream

OUT = Path(__file__).resolve().parent.parent / "data" / "spherex_real"
LAM_LO, LAM_HI = 4.9, 5.1          # microns (data stop at ~5.01)
level = int(sys.argv[1])
OUT.mkdir(parents=True, exist_ok=True)
for spec in sys.argv[2:]:
    name, ra, dec = spec.split(":"); ra, dec = float(ra), float(dec)
    pix = int(hp.ang2pix(2 ** level, ra, dec, nest=True, lonlat=True))
    q = PixelQuery(web=True).ipix([pix], level).wavelength(LAM_LO, LAM_HI).with_wavelengths().with_image()
    parts = q.partitions(); inner = q._web_sql(parts)
    assert "i.filepath" in inner
    inner = inner.replace("i.filepath", "i.filepath, i.t_beg, i.t_end", 1)
    sql = ("SELECT imageid, min(t_beg) AS t_beg, min(t_end) AS t_end, count(*) AS n_pix, median(wavelength) AS wavelength, "
           "median(flux) AS flux_median, median(zodi) AS zodi_median, quantile_cont(flux, 0.25) AS flux_q25, "
           "quantile_cont(flux, 0.75) AS flux_q75 FROM (" + inner + ") GROUP BY imageid ORDER BY t_beg")
    t0 = time.time()
    t = fetch_arrow_stream(f"{q._base_url}/sql", {"query": sql, "partitions": parts})
    dt = time.time() - t0
    out = OUT / f"ttbin_L{level}_{name}.csv"
    cols = t.column_names; data = [t[c].to_pylist() for c in cols]
    with open(out, "w") as f:
        f.write(",".join(cols) + "\n")
        for row in zip(*data):
            f.write(",".join(str(v) for v in row) + "\n")
    print(f"{name}: level-{level} pixel {pix} ({hp.nside2resol(2 ** level, arcmin=True) / 60:.2f} deg), {len(parts)} partition(s), "
          f"{t.num_rows} exposures, {sum(data[cols.index('n_pix')])} pixels, {dt:.1f} s -> {out.name}")
