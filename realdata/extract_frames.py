"""Pull the target (north ecliptic pole) out of the downloaded D6 cutouts into one HDF5 file for plotting in Julia.

Per frame:
  * the image, SPHEREx's own zodi model (ZODI extension), the per-pixel wavelength and the flags, resampled (nearest
    pixel) onto a common north-up tangent-plane grid centred on the target, so the movie frames line up;
  * at the target: its wavelength, and the median over a 31x31-pixel box (~3.2') of the image and of the ZODI layer,
    using only pixels at 4.9-5.1 um. A median rather than a mean, so that stars (left in: no masking yet) barely move it;
  * ZodiPy (Kelsall/DIRBE model, as for the simulated training data) at the target, the frame's mid-exposure time and
    the target's own wavelength. Observer = Earth: SPHEREx is ~7000 km from Earth's centre (5e-5 AU), negligible here.

    python -I realdata/extract_frames.py data/spherex_real/nep_d6 data/spherex_real/nep_d6_frames.csv data/spherex_real/nep_d6.h5
"""
import csv, glob, os, sys, warnings
import numpy as np
import h5py
import astropy.units as u
from astropy.coordinates import SkyCoord
from astropy.io import fits
from astropy.time import Time
from astropy.wcs import WCS, FITSFixedWarning
import zodipy

warnings.filterwarnings("ignore", category=FITSFixedWarning)
warnings.filterwarnings("ignore", message=".*SIP.*")
RA0, DEC0 = 270.0, 66.560708
LAM_LO, LAM_HI = 4.9, 5.1
NG, PIX = 160, 6.15 / 3600            # common grid: 160 x 160 pixels of 6.15" (SPHEREx's pixel scale)
BOX = 15                               # half-size of the box at the target (31 x 31 pixels)

grid = WCS(naxis=2)
grid.wcs.ctype = ["RA---TAN", "DEC--TAN"]; grid.wcs.crval = [RA0, DEC0]
grid.wcs.crpix = [(NG + 1) / 2, (NG + 1) / 2]; grid.wcs.cdelt = [-PIX, PIX]
gy, gx = np.mgrid[0:NG, 0:NG]
g_ra, g_dec = grid.pixel_to_world_values(gx, gy)


def one(path):
    f = fits.open(path); h = f["IMAGE"].header
    img = f["IMAGE"].data.astype(float); zod = f["ZODI"].data.astype(float); flg = f["FLAGS"].data
    ws = WCS(h); ww = WCS(h, fobj=f, key="W")
    ny, nx = img.shape
    yy, xx = np.mgrid[0:ny, 0:nx]
    lam = ww.pixel_to_world_values(xx, yy)[0]
    # target
    px, py = ws.world_to_pixel_values(RA0, DEC0); ix, iy = int(round(float(px))), int(round(float(py)))
    lam0 = float(ww.pixel_to_world_values(float(px), float(py))[0])
    sl = (slice(max(iy - BOX, 0), iy + BOX + 1), slice(max(ix - BOX, 0), ix + BOX + 1))
    inband = (lam[sl] >= LAM_LO) & (lam[sl] <= LAM_HI) & np.isfinite(img[sl])
    med = lambda a: float(np.median(a[sl][inband])) if inband.sum() > 50 else np.nan
    # resample onto the common grid (nearest pixel)
    sx, sy = ws.world_to_pixel_values(g_ra, g_dec); sx = np.rint(sx).astype(int); sy = np.rint(sy).astype(int)
    ok = (sx >= 0) & (sx < nx) & (sy >= 0) & (sy < ny)
    def rs(a, fill=np.nan):
        o = np.full((NG, NG), fill, dtype=float); o[ok] = a[sy[ok], sx[ok]]; return o
    return dict(mjd=h["MJD-AVG"], obsid=h["OBSID"], lam0=lam0, n_box=int(inband.sum()),
                img0=med(img), zodi0=med(zod), var0=float(np.median(f["VARIANCE"].data[sl][inband])) if inband.sum() > 50 else np.nan,
                img=rs(img), zodi=rs(zod), lam=rs(lam), flags=rs(flg.astype(float), fill=-1))


def main():
    files = sorted(glob.glob(os.path.join(sys.argv[1], "*.fits")))
    coll = {r["obs_id"].replace("/", "_"): r["obs_collection"] for r in csv.DictReader(open(sys.argv[2]))}
    F = []
    for k, p in enumerate(files):
        try:
            d = one(p)
        except Exception as e:
            print("skip", os.path.basename(p), repr(e)); continue
        d["coll"] = coll.get(os.path.basename(p)[:-len("_D6.fits")], "?"); F.append(d)
        if (k + 1) % 100 == 0:
            print(f"{k + 1}/{len(files)}", flush=True)
    F.sort(key=lambda d: d["mjd"])
    mjd = np.array([d["mjd"] for d in F]); lam0 = np.array([d["lam0"] for d in F])
    # ZodiPy at the target, each frame's time and wavelength (one model per distinct wavelength, rounded to 1 nm)
    zp = np.full(len(F), np.nan)
    for lr in np.unique(np.round(lam0, 3)):
        m = np.round(lam0, 3) == lr
        model = zodipy.Model(x=lr * u.micron, name="dirbe", ephemeris="de432s")
        t = Time(mjd[m], format="mjd", scale="utc")
        c = SkyCoord(np.full(m.sum(), RA0) * u.deg, np.full(m.sum(), DEC0) * u.deg, frame="icrs", obstime=t)
        zp[m] = model.evaluate(c, obspos="earth").value
    with h5py.File(sys.argv[3], "w") as o:
        o["mjd"] = mjd; o["lam0"] = lam0; o["zodipy"] = zp
        for k in ("img0", "zodi0", "var0", "n_box"):
            o[k] = np.array([d[k] for d in F])
        o["obsid"] = np.array([d["obsid"] for d in F], dtype="S"); o["collection"] = np.array([d["coll"] for d in F], dtype="S")
        for k in ("img", "zodi", "lam", "flags"):
            o.create_dataset(k, data=np.stack([d[k] for d in F]).astype(np.float32), compression="gzip")
        o.attrs["target"] = f"north ecliptic pole RA {RA0} Dec {DEC0}"; o.attrs["grid"] = f"{NG}x{NG} TAN, {PIX * 3600:.2f} arcsec, north up"
        o.attrs["box"] = f"{2 * BOX + 1}x{2 * BOX + 1} px median, pixels at {LAM_LO}-{LAM_HI} um"
    print(f"wrote {sys.argv[3]}: {len(F)} frames; target wavelength {lam0.min():.3f}-{lam0.max():.3f} um; "
          f"in {LAM_LO}-{LAM_HI}: {np.sum((lam0 >= LAM_LO) & (lam0 <= LAM_HI))}")


if __name__ == "__main__":
    main()
