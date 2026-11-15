"""What do the tall table's flags mark? Per grid-G patch at 4.9–5.1 μm, from the local partitions on Discovery scratch, with
NO default flag filter (PixelQuery's default keeps only flags == 0 or MP_SOURCE):

  1. counts: pixel samples per flag bit (bit names from the FLAGS header of the SPHEREx images, MP_*)
  2. objects: "static source" cells (HEALPix level 15, ~6.4″ ≈ one SPHEREx pixel) where MP_SOURCE is set in at least half
     of the exposures, joined into objects (8-connected neighbours); peak position and brightness (median flux − zodi)
     for the catalogue cross-match on the ThinkPad (realdata/flags_xmatch.py)
  3. events: single-exposure brightenings (satellites, asteroids, cosmic rays): pixels the pipeline flagged TRANSIENT or
     OUTLIER, plus artifact-free pixels > 5σ and > 0.05 MJy/sr above their cell's median over all exposures; joined into
     events per exposure (8-connected), with size and elongation

    ~/envs/talltable/bin/python realdata/talltable_flags.py G [first last]
      → data/tt_flags/{counts,objects,events}_g<G>_<patch>.parquet (patches already done are skipped)
"""
import os, sys, time
from pathlib import Path
import numpy as np
import healpy as hp
import duckdb
from talltable import PixelQuery

LAM_LO, LAM_HI, LEVEL, CELL = 4.9, 5.1, 6, 15
SHIFT = 2 * (22 - CELL)
NSIDE_C = 2 ** CELL
SRC = 1 << 21
ART = 0xFFFFFFFF & ~SRC                      # any flag other than MP_SOURCE
BITS = {0: "TRANSIENT", 1: "OVERFLOW", 2: "SUR_ERROR", 4: "PHANTOM", 5: "REFERENCE", 6: "NONFUNC", 7: "DICHROIC",
        9: "MISSING_DATA", 10: "HOT", 11: "COLD", 12: "FULLSAMPLE", 14: "PHANMISS", 15: "NONLINEAR", 17: "PERSIST",
        19: "OUTLIER", 21: "SOURCE"}
BITS_ALL = sorted(set(BITS) | set(range(22, 32)))   # undocumented high bits are counted too
DB_DIR = Path(os.environ["TALLTABLE_DB_DIR"])
OUT = Path(__file__).resolve().parent.parent / "data" / "tt_flags"; OUT.mkdir(parents=True, exist_ok=True)
G = int(sys.argv[1]); nside = 2 ** G
ra_c, dec_c = hp.pix2ang(nside, range(12 * nside ** 2), nest=True, lonlat=True)
idx = range(int(sys.argv[2]), min(int(sys.argv[3]) + 1, len(ra_c))) if len(sys.argv) >= 4 else range(len(ra_c))


def components(cells, groups=None):
    """Label 8-connected components of level-15 cells (optionally only within the same group, e.g. exposure)."""
    cells = np.asarray(cells, dtype=np.int64)
    parent = np.arange(len(cells))
    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]; i = parent[i]
        return i
    lookup = {}
    for i, cpix in enumerate(cells):
        lookup[(cpix if groups is None else (groups[i], cpix))] = i
    nb = hp.get_all_neighbours(NSIDE_C, cells, nest=True)      # (8, n), −1 where none
    for k in range(8):
        for i in np.flatnonzero(nb[k] >= 0):
            j = lookup.get(nb[k, i] if groups is None else (groups[i], nb[k, i]))
            if j is not None:
                a, b = find(i), find(j)
                if a != b: parent[a] = b
    return np.array([find(i) for i in range(len(cells))])


def shape(ra, dec):
    """Size of a group of cell centres: length of the major axis and axis ratio, in arcsec."""
    if len(ra) < 2: return 0.0, 1.0
    x = (ra - ra[0] + 180) % 360 - 180; x = (x - x.mean()) * np.cos(np.radians(dec.mean())) * 3600; y = (dec - dec.mean()) * 3600   # unwrap about ra[0]: safe across RA 0/360
    ev = np.linalg.eigvalsh(np.cov(np.vstack([x, y])) + 1e-6 * np.eye(2))
    return 4 * np.sqrt(ev[1]), float(np.sqrt(ev[1] / ev[0]))


t_all = time.time()
for i in idx:
    name = f"g{G}_{i:03d}"; outs = [OUT / f"{k}_{name}.parquet" for k in ("counts", "objects", "events")]
    if all(o.exists() for o in outs):
        print(f"{name}: already done", flush=True); continue
    ra, dec = float(f"{ra_c[i]:.5f}"), float(f"{dec_c[i]:.5f}")        # rounded as in talltable_bins.py
    pix = int(hp.ang2pix(2 ** LEVEL, ra, dec, nest=True, lonlat=True))
    q = PixelQuery(web=False).ipix([pix], LEVEL).wavelength(LAM_LO, LAM_HI).with_wavelengths().with_image()
    parts = q.partitions(); inner = q._local_sql(parts)
    if any(not (DB_DIR / "pixels" / f"part={p}" / "compacted.parquet").exists() for p in parts):
        print(f"{name}: partitions not downloaded", flush=True); continue
    filt = f"AND (flags & ~({SRC})) = 0"
    assert filt in inner, "the default flag filter changed"
    inner = inner.replace(filt, "").replace("i.filepath", "i.filepath, i.t_beg", 1)
    t0 = time.time(); con = duckdb.connect()
    con.execute(f"CREATE TEMP TABLE px AS SELECT imageid, hphigh, hphigh >> {SHIFT} AS cell, flux, zodi, variance, flags, "
                f"wavelength, t_beg FROM ({inner})")
    # 1. counts per bit
    cols = ", ".join(f"sum(((flags >> {b}) & 1)::BIGINT) AS bit{b}" for b in BITS_ALL)
    con.execute(f"COPY (SELECT '{name}' AS patch, count(*) AS n_pix, sum((flags = 0)::BIGINT) AS n_clean, "
                f"sum(((flags & {ART}) != 0)::BIGINT) AS n_artifact, count(DISTINCT imageid) AS n_exp, {cols} FROM px) "
                f"TO '{outs[0]}' (FORMAT PARQUET)")
    # 2. static-source objects
    c = con.execute(f"SELECT cell, count(*) AS n, sum(((flags & {SRC}) != 0)::INT) AS nsrc, "
                    f"median(flux - zodi) FILTER (WHERE (flags & {ART}) = 0) AS ex FROM px GROUP BY cell "
                    "HAVING nsrc >= 0.5 * count(*) AND count(*) >= 3").fetchnumpy()
    lab = components(c["cell"]) if len(c["cell"]) else np.array([], int)
    cr, cd = hp.pix2ang(NSIDE_C, c["cell"].astype(np.int64), nest=True, lonlat=True)
    ex = np.nan_to_num(np.asarray(c["ex"], dtype=float), nan=-np.inf)
    rows = []
    for L in np.unique(lab):
        m = np.flatnonzero(lab == L); k = m[np.argmax(ex[m])]
        size, ratio = shape(cr[m], cd[m])
        rows.append((name, int(L), len(m), float(cr[k]), float(cd[k]), float(ex[k]) if np.isfinite(ex[k]) else None,
                     float(np.nansum(np.where(np.isfinite(ex[m]), ex[m], 0.0))), size, ratio))
    con.execute("CREATE TEMP TABLE obj (patch VARCHAR, obj INT, n_cells INT, ra DOUBLE, dec DOUBLE, peak_ex DOUBLE, "
                "sum_ex DOUBLE, size_arcsec DOUBLE, axis_ratio DOUBLE)")
    if rows: con.executemany("INSERT INTO obj VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", rows)
    con.execute(f"COPY obj TO '{outs[1]}' (FORMAT PARQUET)"); n_obj = len(rows)
    # 3. single-exposure events
    e = con.execute(f"""
        WITH cm AS (SELECT cell, median(flux - zodi) AS m, count(*) AS n FROM px WHERE (flags & {ART}) = 0 GROUP BY cell)
        SELECT px.imageid, px.cell, px.flux - px.zodi - cm.m AS ex, sqrt(px.variance) AS sig, px.flags, px.t_beg
        FROM px JOIN cm USING (cell)
        WHERE cm.n >= 5 AND ( (px.flags & {(1 << 0) | (1 << 19)}) != 0
              OR ((px.flags & {ART}) = 0 AND px.flux - px.zodi - cm.m > 5 * sqrt(px.variance) AND px.flux - px.zodi - cm.m > 0.05) )
        """).fetchnumpy()
    rows = []
    if len(e["cell"]):
        img = np.asarray(e["imageid"]); cells = e["cell"].astype(np.int64)
        lab = components(cells, groups=img)
        er, ed = hp.pix2ang(NSIDE_C, cells, nest=True, lonlat=True)
        fl = np.asarray(e["flags"]).astype(np.int64); exv = np.asarray(e["ex"], dtype=float)
        order = np.argsort(lab, kind="stable"); cuts = np.flatnonzero(np.diff(lab[order])) + 1
        for m in np.split(order, cuts):
            size, ratio = shape(er[m], ed[m]); k = m[np.nanargmax(exv[m])] if np.isfinite(exv[m]).any() else m[0]
            rows.append((name, int(img[m[0]]), float(e["t_beg"][m[0]]), len(m), float(er[m].mean()), float(ed[m].mean()),
                         float(np.nanmax(exv[m])) if np.isfinite(exv[m]).any() else None, size, ratio,
                         int(((fl[m] >> 0) & 1).sum()), int(((fl[m] >> 19) & 1).sum()), int(((fl[m] & SRC) != 0).sum())))
    con.execute("CREATE TEMP TABLE ev (patch VARCHAR, imageid BIGINT, t_beg DOUBLE, n_pix INT, ra DOUBLE, dec DOUBLE, "
                "peak_ex DOUBLE, size_arcsec DOUBLE, axis_ratio DOUBLE, n_transient INT, n_outlier INT, n_on_source INT)")
    if rows: con.executemany("INSERT INTO ev VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", rows)
    con.execute(f"COPY ev TO '{outs[2]}' (FORMAT PARQUET)")
    n = con.execute("SELECT count(*) FROM px").fetchone()[0]; con.close()
    print(f"{name}: {n} pixel samples, {len(c['cell'])} source cells → {n_obj} objects, {len(rows)} events, "
          f"{time.time() - t0:.1f} s", flush=True)
print(f"done in {time.time() - t_all:.0f} s", flush=True)
