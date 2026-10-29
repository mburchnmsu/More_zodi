"""Find the real SPHEREx exposures that see a sky point at a chosen wavelength (default: the north ecliptic pole at
4.9-5.1 um, i.e. detector D6, whose band ends at ~5.01 um). Uses only IRSA metadata: no images are downloaded.

For each D6 image covering the point (IRSA TAP, spherex.obscore), the footprint polygon lists the detector corners in a
fixed order, (1,1), (2040,1), (2040,2040), (1,2040) (checked against an image's own WCS, Oct 28). The point's detector
pixel is found by inverting the bilinear map from detector pixels to the tangent plane at the point, and its wavelength
is read from the detector's spectral lookup table (9x9 grid, the WCS-WAVE extension of any D6 cutout). Accurate to a
few pixels (~0.005 um), so the selection is made with a small margin and the exact wavelength comes from each cutout.

    python -I realdata/find_frames.py <wave_table_cutout.fits> [out.csv]
"""
import csv, io, sys, urllib.parse, urllib.request
import numpy as np
from astropy.io import fits

RA0, DEC0 = 270.0, 66.560708            # north ecliptic pole (J2000 / ICRS)
LAM_LO, LAM_HI = 4.9, 5.1               # um
MARGIN = 0.02                           # um, for the corner-based estimate
DET = "SPHEREx-D6"
TAP = "https://irsa.ipac.caltech.edu/TAP/sync"


def tap(q):
    url = TAP + "?" + urllib.parse.urlencode({"LANG": "ADQL", "FORMAT": "csv", "QUERY": q})
    with urllib.request.urlopen(url, timeout=600) as r:
        return list(csv.DictReader(io.StringIO(r.read().decode())))


def tangent(ra, dec):
    """Gnomonic projection about (RA0, DEC0), degrees in, radians out."""
    a, d, a0, d0 = map(np.radians, (ra, dec, RA0, DEC0))
    c = np.sin(d0) * np.sin(d) + np.cos(d0) * np.cos(d) * np.cos(a - a0)
    return np.cos(d) * np.sin(a - a0) / c, (np.cos(d0) * np.sin(d) - np.sin(d0) * np.cos(d) * np.cos(a - a0)) / c


def point_pixel(region):
    """Detector pixel (1-based) of the target in an image, from its s_region polygon (4 corners)."""
    v = region.split()
    xy = np.array(v[2:], float).reshape(-1, 2)[:4]
    P = np.array(tangent(xy[:, 0], xy[:, 1])).T           # corners in the tangent plane; target is at (0, 0)
    s, t = 0.5, 0.5                                        # solve bilinear(s, t) = 0 by Newton
    for _ in range(30):
        F = (1 - s) * (1 - t) * P[0] + s * (1 - t) * P[1] + s * t * P[2] + (1 - s) * t * P[3]
        J = np.column_stack([-(1 - t) * P[0] + (1 - t) * P[1] + t * P[2] - t * P[3],
                             -(1 - s) * P[0] - s * P[1] + s * P[2] + (1 - s) * P[3]])
        ds = np.linalg.solve(J, -F); s += ds[0]; t += ds[1]
        if abs(ds).max() < 1e-10:
            break
    return 0.5 + 2040 * s, 0.5 + 2040 * t


def wave_table(path):
    tb = fits.open(path)["WCS-WAVE"].data[0]
    X, Y, V = np.array(tb["X"], float), np.array(tb["Y"], float), np.array(tb["VALUES"])   # V: (9, 9, 2) = [y, x, (wave, bw)]
    if V.shape != (len(Y), len(X), 2):
        V = V.reshape(len(Y), len(X), 2)

    def lam(x, y):
        i = int(np.clip(np.searchsorted(X, x) - 1, 0, len(X) - 2)); j = int(np.clip(np.searchsorted(Y, y) - 1, 0, len(Y) - 2))
        u = (x - X[i]) / (X[i + 1] - X[i]); w = (y - Y[j]) / (Y[j + 1] - Y[j])
        return ((1 - u) * (1 - w) * V[j, i, 0] + u * (1 - w) * V[j, i + 1, 0] + u * w * V[j + 1, i + 1, 0] + (1 - u) * w * V[j + 1, i, 0])
    return lam


def main():
    lam = wave_table(sys.argv[1])
    out = sys.argv[2] if len(sys.argv) > 2 else None
    rows = tap(f"SELECT obs_id, obs_collection, t_min, access_url, s_region FROM spherex.obscore "
               f"WHERE energy_bandpassname = '{DET}' AND CONTAINS(POINT('ICRS', {RA0}, {DEC0}), s_region) = 1 ORDER BY t_min")
    print(f"{len(rows)} {DET} images cover ({RA0}, {DEC0})")
    sel = []
    for r in rows:
        x, y = point_pixel(r["s_region"])
        if not (1 <= x <= 2040 and 1 <= y <= 2040):
            continue
        l = lam(x, y)
        r.update(det_x=f"{x:.1f}", det_y=f"{y:.1f}", lam_est=f"{l:.4f}")
        if LAM_LO - MARGIN <= l <= LAM_HI + MARGIN:
            sel.append(r)
    by = {}
    for r in sel:
        by.setdefault(r["obs_collection"], []).append(float(r["t_min"]))
    print(f"{len(sel)} with the point at {LAM_LO - MARGIN:.2f}-{LAM_HI + MARGIN:.2f} um (estimated):")
    for c, t in sorted(by.items()):
        print(f"  {c:20s} {len(t):5d} images, MJD {min(t):.1f}-{max(t):.1f} ({max(t) - min(t):.0f} days)")
    if out:
        with open(out, "w", newline="") as fh:
            w = csv.DictWriter(fh, fieldnames=list(sel[0].keys())); w.writeheader(); w.writerows(sel)
        print("wrote", out)
    return rows, lam


if __name__ == "__main__":
    main()
