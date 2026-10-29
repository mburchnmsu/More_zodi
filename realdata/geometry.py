"""Geometry behind the real-data light curves: where Earth was, which way SPHEREx looked, and where along the line of
sight the 5 um zodiacal light comes from. Writes data/spherex_real/geometry.h5 for realdata/plot_geometry.jl.

  * Earth's heliocentric ecliptic position (J2000) at every in-band frame of the north ecliptic pole (nep_d6.h5) and of
    the ecliptic point at longitude 45 deg (ecl045_d6.h5), plus a daily orbit for one year.
  * ZodiPy (DIRBE/Kelsall model) at a fixed 4.93 um on those dates, so the colours show the yearly change without the
    two-wavelength tracks.
  * The Kelsall smooth cloud (the main component; Kelsall et al. 1998, Table 1) written out explicitly: dust density
    n = n0 Rc^-alpha f(zeta) about the tilted, offset cloud, temperature T = T0 R^-delta. At 4.9 um there is no scattered
    sunlight in the model, so the brightness is the integral of n(s) B_nu(T(s)) ds along the line of sight. The integrand
    is "how much light per AU comes from distance s". Its integral is checked against ZodiPy.
  * A vertical cut of the cloud's density through the Sun, along the direction in which the cloud's 2 deg tilt is largest.

    python -I realdata/geometry.py
"""
import os
import numpy as np
import h5py
import astropy.units as u
from astropy.coordinates import SkyCoord, get_body_barycentric
from astropy.time import Time
import zodipy

D = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data", "spherex_real")
LAM = 4.93                                   # um, for the fixed-wavelength ZodiPy curve and the emission profiles
# Kelsall et al. (1998) smooth cloud
N0, ALPHA, BETA, GAMMA, MU = 1.13e-7, 1.34, 4.14, 0.942, 0.189
INC, OMEGA = np.radians(2.03), np.radians(77.7)
X0, Y0, Z0 = 0.0119, 0.00548, -0.00215
T0, DELTA = 286.0, 0.467
EPS = np.radians(23.43928)                   # obliquity (J2000), ICRS -> ecliptic
NHAT = np.array([np.sin(OMEGA) * np.sin(INC), -np.cos(OMEGA) * np.sin(INC), np.cos(INC)])   # cloud's symmetry axis


def ecl(v):
    """ICRS (equatorial) cartesian -> ecliptic cartesian."""
    x, y, z = v
    return np.array([x, np.cos(EPS) * y + np.sin(EPS) * z, -np.sin(EPS) * y + np.cos(EPS) * z])


def earth_helio(t):
    e = get_body_barycentric("earth", t); s = get_body_barycentric("sun", t)
    return ecl(np.array([(e.x - s.x).to_value(u.AU), (e.y - s.y).to_value(u.AU), (e.z - s.z).to_value(u.AU)]))


def density(X, Y, Z):
    xc, yc, zc = X - X0, Y - Y0, Z - Z0
    rc = np.sqrt(xc**2 + yc**2 + zc**2)
    zeta = np.abs(xc * NHAT[0] + yc * NHAT[1] + zc * NHAT[2]) / rc
    g = np.where(zeta < MU, zeta**2 / (2 * MU), zeta - MU / 2)
    return N0 * rc**-ALPHA * np.exp(-BETA * g**GAMMA)


def bnu(T, lam_um):
    """Planck B_nu in MJy/sr."""
    h, c, k = 6.62607e-34, 2.99792e8, 1.380649e-23
    nu = c / (lam_um * 1e-6)
    return 2 * h * nu**3 / c**2 / np.expm1(h * nu / (k * T)) * 1e20


S = np.linspace(1e-4, 6.0, 6000)             # AU from Earth along the line of sight
AU_PER_AU = 1.0                              # n0 is per AU, ds in AU -> integral in MJy/sr


def profile(r_earth, dhat, lam=LAM):
    P = r_earth[:, None] + dhat[:, None] * S[None, :]
    R = np.sqrt((P**2).sum(0))
    return density(*P) * bnu(T0 * R**-DELTA, lam)          # MJy/sr per AU


def unit_ecl(lon, lat):
    lon, lat = np.radians(lon), np.radians(lat)
    return np.array([np.cos(lat) * np.cos(lon), np.cos(lat) * np.sin(lon), np.sin(lat)])


def main():
    out = {}
    model = zodipy.Model(x=LAM * u.micron, name="dirbe", ephemeris="de432s")
    targets = {"nep": (270.0, 66.560708, unit_ecl(0, 90)), "ecl045": (42.536, 16.336, unit_ecl(45, 0))}
    for name, (ra, dec, dhat) in targets.items():
        with h5py.File(os.path.join(D, f"{name}_d6.h5")) as f:
            mjd, lam0, img0 = f["mjd"][:], f["lam0"][:], f["img0"][:]
        m = (lam0 >= 4.9) & (lam0 <= 5.1) & np.isfinite(img0)
        t = Time(mjd[m], format="mjd", scale="utc")
        r = earth_helio(t)                                   # (3, n)
        zp = model.evaluate(SkyCoord(np.full(m.sum(), ra) * u.deg, np.full(m.sum(), dec) * u.deg, frame="icrs", obstime=t),
                            obspos="earth").value
        prof = np.array([profile(r[:, k], dhat) for k in range(m.sum())])
        integ = np.trapezoid(prof, S, axis=1)
        out[name] = dict(mjd=mjd[m], earth=r.T, zodipy_fixed=zp, img0=img0[m], lam0=lam0[m], dhat=dhat,
                         prof=prof, integ=integ, height=r.T @ NHAT)
        cc = np.corrcoef(integ, zp)[0, 1]
        print(f"{name}: {m.sum()} frames; smooth-cloud integral / ZodiPy = {np.median(integ / zp):.3f} "
              f"(range {np.min(integ / zp):.3f}-{np.max(integ / zp):.3f}), correlation {cc:.4f}")
        half = np.array([S[np.searchsorted(np.cumsum(p) / p.sum(), 0.5)] for p in prof])
        print(f"   half the light comes from within {half.min():.2f}-{half.max():.2f} AU of Earth")
    # daily orbit over one year, with the cloud-midplane height and ZodiPy at the pole
    td = Time(np.arange(61000, 61366), format="mjd", scale="utc")
    rd = earth_helio(td)
    zpd = model.evaluate(SkyCoord(np.full(len(td), 270.0) * u.deg, np.full(len(td), 66.560708) * u.deg, frame="icrs",
                                  obstime=td), obspos="earth").value
    integ_d = np.array([np.trapezoid(profile(rd[:, k], unit_ecl(0, 90)), S) for k in range(len(td))])
    # vertical cut through the Sun along the direction of steepest tilt (ecliptic longitude OMEGA - 90 deg)
    uhat = np.array([np.cos(OMEGA - np.pi / 2), np.sin(OMEGA - np.pi / 2), 0.0])
    sx = np.linspace(-2.2, 2.2, 881); sz = np.linspace(-0.6, 0.6, 241)
    SX, SZ = np.meshgrid(sx, sz, indexing="ij")
    cut = density(SX * uhat[0], SX * uhat[1], SZ)
    with h5py.File(os.path.join(D, "geometry.h5"), "w") as o:
        for name, d in out.items():
            g = o.create_group(name)
            for k, v in d.items():
                g[k] = v
        o["S"] = S; o["day_mjd"] = td.mjd; o["day_earth"] = rd.T; o["day_zodipy_nep"] = zpd; o["day_integ_nep"] = integ_d
        o["day_height"] = rd.T @ NHAT
        o["cut_s"] = sx; o["cut_z"] = sz; o["cut_density"] = cut; o["uhat"] = uhat; o["nhat"] = NHAT
        o.attrs["lam"] = LAM; o.attrs["omega_deg"] = np.degrees(OMEGA); o.attrs["inc_deg"] = np.degrees(INC)
    print(f"daily: ZodiPy at the pole {zpd.min():.4f}-{zpd.max():.4f} MJy/sr (max on MJD {td.mjd[zpd.argmax()]:.0f}, "
          f"min on MJD {td.mjd[zpd.argmin()]:.0f}); smooth-cloud integral max on MJD {td.mjd[integ_d.argmax()]:.0f}")
    print(f"Earth farthest below the cloud midplane on MJD {td.mjd[(rd.T @ NHAT).argmin()]:.0f}, "
          f"closest to the Sun on MJD {td.mjd[np.sqrt((rd**2).sum(0)).argmin()]:.0f}")
    print("wrote", os.path.join(D, "geometry.h5"))


if __name__ == "__main__":
    main()
