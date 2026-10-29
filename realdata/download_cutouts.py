"""Download IRSA cutouts for the frames listed by find_frames.py (resumable: existing files are skipped).
Each image's file URL comes from its IRSA datalink record (the processing-version folder varies), then the IBE cutout
service returns a SIZE x SIZE pixel cutout centred on the target, with all extensions (IMAGE, FLAGS, VARIANCE, ZODI,
EPSF, WCS-WAVE), ~4.5 MB each.

    python -I realdata/download_cutouts.py data/spherex_real/nep_d6_frames.csv data/spherex_real/nep_d6
"""
import csv, os, re, sys, time, urllib.request
from concurrent.futures import ThreadPoolExecutor

RA0, DEC0, SIZE, WORKERS = 270.0, 66.560708, 200, 4


def get(url, timeout=300):
    for k in range(5):
        try:
            with urllib.request.urlopen(url, timeout=timeout) as r:
                return r.read()
        except Exception as e:
            if k == 4:
                raise
            time.sleep(10 * (k + 1))


def fetch(row, outdir):
    out = os.path.join(outdir, row["obs_id"].replace("/", "_") + "_D6.fits")
    if os.path.exists(out) and os.path.getsize(out) > 0:
        return "skip"
    links = get(row["access_url"], 120).decode()
    m = re.search(r"<TD>(https://[^<]+\.fits)</TD>\s*<TD>\s*</TD>\s*<TD>#this</TD>", links) or \
        re.search(r"(https://irsa\.ipac\.caltech\.edu/ibe/data/spherex/[^<\s]+/level2_[^<\s]+\.fits)", links)
    if not m:
        raise RuntimeError(f"no image URL in datalink for {row['obs_id']}")
    data = get(f"{m.group(1)}?center={RA0},{DEC0}&size={SIZE}pix")
    if data[:6] != b"SIMPLE":
        raise RuntimeError(f"not a FITS file for {row['obs_id']}: {data[:80]!r}")
    with open(out + ".part", "wb") as fh:
        fh.write(data)
    os.replace(out + ".part", out)
    return "ok"


def main():
    rows = list(csv.DictReader(open(sys.argv[1])))
    outdir = sys.argv[2]; os.makedirs(outdir, exist_ok=True)
    t0 = time.time(); n = {"ok": 0, "skip": 0, "fail": 0}

    def job(r):
        try:
            return fetch(r, outdir)
        except Exception as e:
            print(f"FAIL {r['obs_id']}: {e}", flush=True)
            return "fail"
    with ThreadPoolExecutor(WORKERS) as ex:
        for i, s in enumerate(ex.map(job, rows), 1):
            n[s] += 1
            if i % 25 == 0 or i == len(rows):
                print(f"{time.strftime('%H:%M')}  {i}/{len(rows)}  {n}  {(time.time() - t0) / 60:.1f} min", flush=True)
    print("done", n)


if __name__ == "__main__":
    main()
