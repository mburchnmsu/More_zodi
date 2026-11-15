"""Flag census on the ThinkPad: what the tall table's flags mark at 4.9–5.1 μm (from realdata/talltable_flags.py output).

  A. pixel samples per flag bit over all patches
  B. flagged static objects (MP_SOURCE) in a sample of patches, cross-matched (peak position, 6″ ≈ one SPHEREx pixel)
     with Gaia DR3 and AllWISE through the ESA Gaia archive (VizieR and IRSA were down on Nov 14, 2026):
       galaxy  = AllWISE ext_flag > 0 (extended, incl. 2MASS XSC) or Gaia galaxy probability > 0.5
       quasar  = Gaia quasar probability > 0.5, or no Gaia star and AllWISE W1 − W2 ≥ 0.8
       star    = Gaia source with parallax/error > 5 or proper motion/error > 5 ("confirmed"), else any other Gaia
                 point source ("likely")
       WISE-only = AllWISE point source with no Gaia counterpart; unmatched = neither
  C. single-exposure events over all patches, by shape and pipeline flags:
       satellite streak = ≥ 8 pixels and axis ratio ≥ 5
       cosmic ray / detector = compact, with pipeline TRANSIENT or OUTLIER pixels
       sky transient candidate = compact, no pipeline flag, not on a static source (asteroids, flares)
       on a static source = compact, no pipeline flag, on MP_SOURCE pixels (variable sources, PSF residuals)
  D. sky transient candidates in the sample's ecliptic patches (|β| < 25°) checked against known asteroids (IMCCE SkyBoT,
     geocentre, 30″)

    python -I -X utf8 realdata/flags_xmatch.py [EVERY=8]   → data/tt_flags/xmatch_objects.csv, flag_census.txt
"""
import sys, glob, time, io
from pathlib import Path
import numpy as np
import duckdb
import astropy.units as u
from astropy.coordinates import SkyCoord
from astropy.table import Table, vstack
from astropy.time import Time

D = Path(__file__).resolve().parent.parent / "data" / "tt_flags"
EVERY = int(sys.argv[1]) if len(sys.argv) > 1 else 8
BITS = {0: "TRANSIENT", 1: "OVERFLOW", 2: "SUR_ERROR", 4: "PHANTOM", 5: "REFERENCE", 6: "NONFUNC", 7: "DICHROIC",
        9: "MISSING_DATA", 10: "HOT", 11: "COLD", 12: "FULLSAMPLE", 14: "PHANMISS", 15: "NONLINEAR", 17: "PERSIST",
        19: "OUTLIER", 21: "SOURCE"}
out = io.StringIO()
def say(s=""):
    print(s, flush=True); out.write(s + "\n")
pq = lambda k: f"read_parquet('{D.as_posix()}/{k}_g2_*.parquet')"

# ---- A. counts
cnt = duckdb.sql(f"SELECT * FROM {pq('counts')}").fetchnumpy()
npatch = len(cnt["patch"]); ntot = int(cnt["n_pix"].sum())
say(f"A. {npatch} patches, {ntot:,} pixel samples at 4.9–5.1 μm, {int(cnt['n_exp'].sum()):,} patch-exposures")
say(f"   no flag: {100 * cnt['n_clean'].sum() / ntot:.1f}%;  any flag other than SOURCE: {100 * cnt['n_artifact'].sum() / ntot:.2f}%")
for b in sorted(int(k[3:]) for k in cnt if k.startswith("bit")):
    n = int(cnt[f"bit{b}"].sum())
    if n: say(f"   bit {b:2d} {BITS.get(b, '(undocumented)'):14s} {n:13,d}  {100 * n / ntot:6.3f}%")

# ---- C. events (all patches)
ev = duckdb.sql(f"""SELECT *, CASE WHEN n_pix >= 8 AND axis_ratio >= 5 THEN 'satellite streak'
                       WHEN n_transient + n_outlier > 0 THEN 'cosmic ray / detector'
                       WHEN n_on_source > 0 THEN 'on a static source'
                       ELSE 'sky transient candidate' END AS cls FROM {pq('events')}""").fetchnumpy()
say(f"\nC. {len(ev['cls']):,} single-exposure events in {npatch} patches ({len(ev['cls']) / max(cnt['n_exp'].sum(), 1):.0f} per patch-exposure)")
for k in ("cosmic ray / detector", "satellite streak", "sky transient candidate", "on a static source"):
    m = ev["cls"] == k
    say(f"   {k:24s} {m.sum():9,d}  ({100 * m.mean():5.2f}%)  median size {np.median(ev['n_pix'][m]) if m.any() else 0:.0f} px")
m = ev["cls"] == "satellite streak"
# sizes > 8000″ (larger than a patch) come from a RA 0/360 wrap bug in the first census run's shape() (fixed since):
# 44 events and 3 objects in the 4 patches that straddle RA 0, left out of the lengths
ok = m & (ev["size_arcsec"] < 8000)
if m.any():
    say(f"   streaks: {len(set(zip(ev['patch'][m], ev['imageid'][m])))} patch-exposures with a streak; median length "
        f"{np.median(ev['size_arcsec'][ok]) / 60:.1f}′, 90% {np.quantile(ev['size_arcsec'][ok], 0.9) / 60:.0f}′, "
        f"longest {ev['size_arcsec'][ok].max() / 60:.0f}′ ({(m & ~ok).sum()} wrap-affected left out)")

# ---- B. objects in the sample
obj = duckdb.sql(f"SELECT * FROM {pq('objects')} ORDER BY patch, obj").fetchnumpy()
pnum = np.array([int(p.split("_")[1]) for p in obj["patch"]])
say(f"\nB. {len(obj['patch']):,} flagged static objects (MP_SOURCE groups) in {npatch} patches "
    f"(median {np.median(np.bincount(pnum)[np.unique(pnum)]):.0f} per patch, median size {np.median(obj['size_arcsec']):.0f}″)")
gb_obj = SkyCoord(obj["ra"] * u.deg, obj["dec"] * u.deg).galactic.b.deg
pb = {p: np.median(np.abs(gb_obj[pnum == p])) for p in np.unique(pnum)}
# sample: every EVERY-th patch, off the Galactic plane (a plane patch's Gaia cone holds ~10⁶ sources)
samp = np.isin(pnum, [p for p in np.arange(0, 192, EVERY) if pb.get(p, 0) > 15])
from astroquery.gaia import Gaia
import socket; socket.setdefaulttimeout(300)   # a hung request becomes an error (and a retry) instead of waiting forever
Gaia.ROW_LIMIT = -1
GCOLS = ["ra", "dec", "phot_g_mean_mag", "parallax_over_error", "pmra", "pmdec", "pmra_error", "pmdec_error",
         "classprob_dsc_combmod_galaxy", "classprob_dsc_combmod_quasar"]
WCOLS = ["ra", "dec", "w1mpro", "w2mpro", "ext_flag"]
cache = D / "catalogs"; cache.mkdir(exist_ok=True)
def cone(table, cols, p, ra0, dec0, rad):
    """All catalogue rows in a cone around a patch (ESA Gaia archive TAP), cached to data/tt_flags/catalogs/."""
    # The archive's async jobs failed often on Nov 14 and, when busy, returned partial results without an error. So the
    # cone is fetched with synchronous queries (fast, but capped at 2000 rows): declination strips are halved until each
    # holds < 2000 rows by COUNT(*), and every strip's download is checked against its count.
    f = cache / f"{table.replace('.', '_')}_g2_{p:03d}.ecsv"
    if f.exists(): return Table.read(f)   # cached cones were checked when downloaded (and for empty regions, Nov 14)
    where = f"WHERE 1 = CONTAINS(POINT(ra, dec), CIRCLE({ra0}, {dec0}, {rad}))"
    def q(sql, tries=8):
        for attempt in range(tries):
            try: return Gaia.launch_job(sql).get_results()
            except Exception as e:
                print(f"   {table} patch {p}: {str(e)[:80]} (retry {attempt + 1})", flush=True); time.sleep(5 * (attempt + 1))
        raise RuntimeError(f"{table} query failed for patch {p}")
    def strip(lo, hi):
        band = f" AND dec >= {lo!r} AND dec < {hi!r}"
        n = int(q(f"SELECT COUNT(*) AS n FROM {table} {where}{band}")["n"][0])
        if n >= 2000: return strip(lo, (lo + hi) / 2) + strip((lo + hi) / 2, hi)
        if n == 0: return []
        for attempt in range(4):
            t = q(f"SELECT {', '.join(cols)} FROM {table} {where}{band}")
            if len(t) == n: return [t]
            print(f"   {table} patch {p}: got {len(t)} of {n} rows (retry {attempt + 1})", flush=True)
        raise RuntimeError(f"{table} patch {p}: incomplete result")
    n = int(q(f"SELECT COUNT(*) AS n FROM {table} {where}")["n"][0])
    t = vstack(strip(float(dec0 - rad - 0.01), float(dec0 + rad + 0.01)))
    assert len(t) == n, f"{table} patch {p}: strips give {len(t)} of {n} rows"
    t.write(f, overwrite=True); return t
def nearest(ra, dec, t, r_arcsec=6.0):
    """Index of the nearest catalogue row within r for each position (−1 if none)."""
    if len(t) == 0: return np.full(len(ra), -1)
    i, sep, _ = SkyCoord(ra * u.deg, dec * u.deg).match_to_catalog_sky(SkyCoord(np.asarray(t["ra"]) * u.deg, np.asarray(t["dec"]) * u.deg))
    return np.where(sep.arcsec < r_arcsec, i, -1)
gm, wm = {}, {}; t0 = time.time()
for p in np.unique(pnum[samp]):
    m = np.flatnonzero(samp & (pnum == p)); ra, dec = obj["ra"][m], obj["dec"][m]
    ra0 = np.degrees(np.angle(np.mean(np.exp(1j * np.radians(ra))))) % 360   # circular mean (patches may straddle RA 0)
    c0 = SkyCoord(ra0 * u.deg, np.mean(dec) * u.deg)
    rad = float(c0.separation(SkyCoord(ra * u.deg, dec * u.deg)).deg.max()) + 0.01
    tg = cone("gaiadr3.gaia_source", GCOLS, p, c0.ra.deg, c0.dec.deg, rad)
    tw = cone("gaiadr1.allwise_original_valid", WCOLS, p, c0.ra.deg, c0.dec.deg, rad)
    for k, (ig, iw) in enumerate(zip(nearest(ra, dec, tg), nearest(ra, dec, tw))):
        if ig >= 0: gm[m[k]] = tg[ig]
        if iw >= 0: wm[m[k]] = tw[iw]
    print(f"   patch {p}: {len(m)} objects, Gaia {len(tg)}, AllWISE {len(tw)} in the cone ({time.time() - t0:.0f} s)", flush=True)
idx_s = np.flatnonzero(samp)
say(f"   sample: {samp.sum():,} objects in {len(np.unique(pnum[samp]))} patches (every {EVERY}th, |b| > 15°); "
    f"Gaia match {len(gm):,}, AllWISE match {len(wm):,} within 6″ ({time.time() - t0:.0f} s)")
def num(v):
    try: return float(v)
    except Exception: return np.nan
cls = []
for i in idx_s:
    g, w = gm.get(i), wm.get(i)
    pgal = num(g["classprob_dsc_combmod_galaxy"]) if g is not None else np.nan
    pqso = num(g["classprob_dsc_combmod_quasar"]) if g is not None else np.nan
    ext = int(num(w["ext_flag"])) if w is not None and np.isfinite(num(w["ext_flag"])) else 0
    w12 = num(w["w1mpro"]) - num(w["w2mpro"]) if w is not None else np.nan
    if ext > 0 or pgal > 0.5: c = "galaxy"
    elif pqso > 0.5 or (g is None and w12 >= 0.8): c = "quasar / AGN"
    elif g is not None:
        pm = np.hypot(num(g["pmra"]) / num(g["pmra_error"]), num(g["pmdec"]) / num(g["pmdec_error"]))
        c = "star (parallax or motion)" if num(g["parallax_over_error"]) > 5 or pm > 5 else "star (Gaia point source)"
    elif w is not None: c = "WISE-only point source"
    else: c = "unmatched"
    cls.append(c)
cls = np.array(cls)
for k in ("star (parallax or motion)", "star (Gaia point source)", "galaxy", "quasar / AGN", "WISE-only point source", "unmatched"):
    m = cls == k; say(f"   {k:34s} {m.sum():7,d}  ({100 * m.mean():5.1f}%)")
with open(D / "xmatch_objects.csv", "w") as f:
    f.write("patch,obj,ra,dec,n_cells,size_arcsec,peak_ex,class\n")
    for j, i in enumerate(np.flatnonzero(samp)):
        f.write(f"{obj['patch'][i]},{obj['obj'][i]},{obj['ra'][i]:.6f},{obj['dec'][i]:.6f},{obj['n_cells'][i]},"
                f"{obj['size_arcsec'][i]:.1f},{obj['peak_ex'][i]},{cls[j]}\n")

# ---- D. known asteroids among the sky transient candidates (sample, ecliptic patches)
from astroquery.imcce import Skybot
ecl = SkyCoord(ev["ra"] * u.deg, ev["dec"] * u.deg).barycentrictrueecliptic.lat.deg
epn = np.array([int(p.split("_")[1]) for p in ev["patch"]])
insamp = np.isin(epn, np.arange(0, 192, EVERY)) & (np.abs(ecl) < 25)
cand = (ev["cls"] == "sky transient candidate") & insamp
keys = sorted(set(zip(ev["patch"][insamp], ev["imageid"][insamp])))
keys = keys[::max(1, len(keys) // 300)][:300]                       # ≤ 300 SkyBoT queries, spread over the exposures
say(f"\nD. {cand.sum():,} sky transient candidates in sample patches with |β| < 25°; known asteroids checked in "
    f"{len(keys)} of their exposures (IMCCE SkyBoT, geocentre)")
# For each known small body predicted inside an exposure's footprint (within 60″ of that exposure's events, which are
# dense: ~10³ per patch-exposure), is there an event within 15″, and of which class?
# Control: the same test at a position 2′ north of each body, i.e. how often ~10³ events per exposure put one within
# 15″ of a random spot by chance.
rec = {}; nin = {"V<16": 0, "16–18": 0, "V>18": 0}; nhit = dict.fromkeys(nin, 0); nctl = dict.fromkeys(nin, 0)
ncand_hit, nq, t0 = 0, 0, time.time()
vb = lambda v: "V<16" if v < 16 else ("16–18" if v < 18 else "V>18")
sbc = cache / "skybot"; sbc.mkdir(exist_ok=True)
for (p, img) in keys:
    m = (ev["patch"] == p) & (ev["imageid"] == img)
    e = SkyCoord(ev["ra"][m] * u.deg, ev["dec"][m] * u.deg)
    ra0 = np.degrees(np.angle(np.mean(np.exp(1j * np.radians(ev["ra"][m]))))) % 360
    f = sbc / f"{p}_{img}.ecsv"; fnone = sbc / f"{p}_{img}.none"
    if fnone.exists(): continue
    if f.exists(): sb = Table.read(f)
    else:
        try:
            nq += 1
            sb = Skybot.cone_search(SkyCoord(ra0 * u.deg, np.mean(ev["dec"][m]) * u.deg), 0.75 * u.deg,
                                    Time(ev["t_beg"][m][0], format="mjd"), location="500")
            sb = Table({"RA": sb["RA"].to(u.deg).value, "DEC": sb["DEC"].to(u.deg).value, "V": np.asarray(sb["V"], float)})
            sb.write(f, overwrite=True)
        except Exception as ex:                           # SkyBoT raises when no known body is in the field
            if "No solar system object" in str(ex) or "No Solar System" in str(ex): fnone.touch()
            continue
    a = SkyCoord(np.asarray(sb["RA"]) * u.deg, np.asarray(sb["DEC"]) * u.deg)
    ia, sep, _ = a.match_to_catalog_sky(e)
    _, sepc, _ = a.directional_offset_by(0 * u.deg, 2 * u.arcmin).match_to_catalog_sky(e)
    for k in range(len(a)):
        if sep[k].arcsec > 60: continue                   # outside what this exposure covered at 4.9–5.1 μm
        b = vb(float(sb["V"][k])); nin[b] += 1; nctl[b] += int(sepc[k].arcsec < 15)
        if sep[k].arcsec < 15:
            nhit[b] += 1; c = ev["cls"][m][ia[k]]; rec[c] = rec.get(c, 0) + 1
            ncand_hit += int(c == "sky transient candidate")
say(f"   {nq} new queries ({time.time() - t0:.0f} s). Known asteroids inside the footprint, how many sit on an event "
    f"(≤ 15″), and the chance rate (same test 2′ away):")
for b in nin: say(f"     {b:6s} {nin[b]:5d} in footprint, {nhit[b]:4d} on an event, {nctl[b]:4d} by chance")
say(f"   classes of those events: " + ", ".join(f"{k} {v}" for k, v in sorted(rec.items(), key=lambda x: -x[1])))
say(f"   sky transient candidates that are a known asteroid: {ncand_hit}")
(D / "flag_census.txt").write_text(out.getvalue(), encoding="utf-8")
