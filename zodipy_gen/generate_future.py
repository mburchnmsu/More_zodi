"""Synthetic 'future' exposures for the extrapolation-in-time test (round 10). Writes data/zodipy115_future.h5 (new file).

The real SPHEREx survey is Sun-synchronous: its orbit plane and its pointing pattern turn with the Sun. So "the same
survey Δ days later" = every exposure moved to t + Δ, with its pointing and SPHEREx's Earth-relative orbit rotated about
the ecliptic pole by φ = λ⊕(t + Δ) − λ⊕(t) (how far Earth moved around the Sun). Ecliptic latitudes and the
Sun–SPHEREx–pointing geometry are kept; Earth, its velocity and Jupiter come from the de432s ephemeris at t + Δ;
the target is ZodiPy 1.1.5 with exactly the settings of zodipy_gen/generate.py (observer = SPHEREx, heliocentric).

Run:  <zodipy env python> -I zodipy_gen/generate_future.py <More_zodi root>
"""
import sys, time, ctypes, numpy as np, h5py, astropy.units as u
from astropy.time import Time
from astropy.coordinates import (SkyCoord, BarycentricMeanEcliptic, HeliocentricMeanEcliptic, CartesianRepresentation,
                                 ICRS, solar_system_ephemeris, get_body_barycentric_posvel)
import zodipy
from importlib.metadata import version

if sys.platform == "win32":
    ctypes.windll.kernel32.SetPriorityClass(ctypes.windll.kernel32.GetCurrentProcess(), 0x4000)  # BELOW_NORMAL

ROOT = sys.argv[1]; D = f"{ROOT}/data"; EPHEM = "de432s"
DELTAS = np.arange(30, 541, 30)            # days
NBASE = 6000                               # exposures per Δ
COMPS = ["smooth_cloud", "dust_band_1", "dust_band_2", "dust_band_3", "circum_solar_ring", "earth_trailing_feature"]

with h5py.File(f"{D}/boresight_pointing.h5") as f:
    nvec = f["pointing/nvec_unit_cartesian"][:]; jd = f["times/julian_date"][:]
with h5py.File(f"{D}/spherex_vectors_bore_interpolated.h5") as f:
    S = f["spherex/positions"][:]; vS = f["spherex/velocities"][:]
    E = f["earth/positions"][:]; vE = f["earth/velocities"][:]; J = f["jupiter/positions"][:]
N = len(jd)

def body_ecl(body, t):
    """barycentric ecliptic (J2000) position [AU] and velocity [AU/day], shape (n, 3), from EPHEM."""
    p, v = get_body_barycentric_posvel(body, t, ephemeris=EPHEM)
    to_ecl = lambda r: ICRS(r).transform_to(BarycentricMeanEcliptic()).cartesian.xyz.to_value(u.AU).T
    pos = to_ecl(p)
    # velocity: same rotation (ICRS -> ecliptic J2000 is a fixed rotation), applied to the velocity as a "position"
    vel = to_ecl(CartesianRepresentation(v.xyz.to_value(u.AU / u.day) * u.AU))
    return pos, vel

def helio(xyz_bary, t):
    c = BarycentricMeanEcliptic(CartesianRepresentation(xyz_bary.T * u.AU))
    with solar_system_ephemeris.set(EPHEM):
        return c.transform_to(HeliocentricMeanEcliptic(obstime=t)).cartesian.xyz.to_value(u.AU)

def rotz(phi_deg, X):                      # rotate rows of X (n, 3) about the ecliptic pole by phi (per row)
    c, s = np.cos(np.radians(phi_deg)), np.sin(np.radians(phi_deg))
    return np.stack([c * X[:, 0] - s * X[:, 1], s * X[:, 0] + c * X[:, 1], X[:, 2]], axis=1)

def lam_earth(t):                          # Earth's heliocentric ecliptic longitude [deg]
    h = helio(body_ecl("earth", t)[0], t)
    return np.degrees(np.arctan2(h[1], h[0]))

# ---- 1. validate the ephemeris code against the vectors file (same times) ----------------------------------
k = np.random.default_rng(5).choice(N, 300, replace=False); t = Time(jd[k], format="jd", scale="tdb")
Ep, Ev = body_ecl("earth", t); Jp, _ = body_ecl("jupiter", t)
dE, dvE, dJ = (np.max(np.linalg.norm(a - b, axis=1)) for a, b in ((Ep, E[k]), (Ev, vE[k]), (Jp, J[k])))
print(f"ephemeris check vs vectors file: |ΔE| {dE:.1e} AU, |ΔvE| {dvE:.1e} AU/day (|vE| ≈ {np.median(np.linalg.norm(vE[k], axis=1)):.4f}), |ΔJ| {dJ:.1e} AU", flush=True)
assert dE < 1e-5 and dvE < 1e-6 and dJ < 1e-4

# ---- 2. build the shifted exposures --------------------------------------------------------------------------
base = np.sort(np.random.default_rng(2026).choice(N, NBASE, replace=False))
t0 = Time(jd[base], format="jd", scale="tdb"); lam0 = lam_earth(t0)
rows = {key: [] for key in ("delta", "src", "jd", "phi", "nvec", "S", "vS", "E", "vE", "J")}
for dl in DELTAS:
    t1 = Time(jd[base] + dl, format="jd", scale="tdb")
    E1, vE1 = body_ecl("earth", t1); J1, _ = body_ecl("jupiter", t1)
    phi = (lam_earth(t1) - lam0 + 180) % 360 - 180 + 360 * np.floor((dl + 182.6) / 365.25)   # unwrapped turning angle
    rows["delta"].append(np.full(NBASE, dl)); rows["src"].append(base); rows["jd"].append(jd[base] + dl); rows["phi"].append(phi)
    rows["nvec"].append(rotz(phi, nvec[base]))
    rows["S"].append(E1 + rotz(phi, S[base] - E[base])); rows["vS"].append(vE1 + rotz(phi, vS[base] - vE[base]))
    rows["E"].append(E1); rows["vE"].append(vE1); rows["J"].append(J1)
F = {key: np.concatenate(v) for key, v in rows.items()}
M = len(F["jd"])
lat = np.degrees(np.arcsin(np.clip(F["nvec"][:, 2], -1, 1))); lon = np.degrees(np.arctan2(F["nvec"][:, 1], F["nvec"][:, 0])) % 360
# geometry checks: latitudes kept, solar elongation kept (to within Earth-distance changes)
src_lat = np.degrees(np.arcsin(np.clip(nvec[F["src"], 2], -1, 1)))
def elong(n, Sx, tt):
    h = helio(Sx, tt).T; return np.degrees(np.arccos(np.clip(-np.sum(n * h, 1) / np.linalg.norm(h, axis=1), -1, 1)))
el1 = elong(F["nvec"], F["S"], Time(F["jd"], format="jd", scale="tdb"))
el0 = elong(nvec[F["src"]], S[F["src"]], Time(jd[F["src"]], format="jd", scale="tdb"))
print(f"{M} future exposures (Δ = {DELTAS[0]}..{DELTAS[-1]} d); max |Δlatitude| {np.max(np.abs(lat - src_lat)):.1e}°, "
      f"solar elongation change median {np.median(np.abs(el1 - el0)):.3f}°, max {np.max(np.abs(el1 - el0)):.3f}°", flush=True)
print(f"turning angle φ per Δ (median): " + ", ".join(f"{dl}d→{np.median(F['phi'][F['delta'] == dl]):.1f}°" for dl in DELTAS[::3]), flush=True)

# ---- 3. ZodiPy truth (sorted by time; same settings as generate.py) -----------------------------------------------
model = zodipy.Model(x=5 * u.um, name="dirbe", ephemeris=EPHEM)
order = np.argsort(F["jd"], kind="stable"); out = np.empty((len(COMPS), M)); tic = time.time()
for j in range(0, M, 2000):
    ii = order[j:j + 2000]; tt = Time(F["jd"][ii], format="jd", scale="tdb")
    c = SkyCoord(lon[ii] * u.deg, lat[ii] * u.deg, frame="barycentricmeanecliptic", obstime=tt.utc)
    out[:, ii] = model.evaluate(c, obspos=helio(F["S"][ii], tt) * u.AU, return_comps=True).value
print(f"ZodiPy: {M} exposures in {time.time() - tic:.0f}s; emission range {out.sum(0).min():.3f}..{out.sum(0).max():.3f} MJy/sr", flush=True)
assert np.all(np.isfinite(out)) and np.all(out.sum(0) > 0)

with h5py.File(f"{D}/zodipy115_future.h5", "w") as f:
    m = f.create_group("metadata")
    for key, v in dict(created=time.strftime("%Y-%m-%dT%H:%M:%S"), zodipy_version=version("zodipy"), zodipy_model="dirbe (Kelsall 1998)",
                       wavelength=5.0, wavelength_units="micron", ephemeris=EPHEM, emission_units="MJy/sr",
                       generator="zodipy_gen/generate_future.py",
                       description="Synthetic future exposures: mission exposures moved forward by delta days, pointing and "
                                   "SPHEREx's Earth-relative orbit rotated about the ecliptic pole with Earth's orbital motion").items():
        m.attrs[key] = v
    f["emission"] = out.sum(0)
    for i, n in enumerate(COMPS): f[f"emission_{n}"] = out[i]
    f["delta_days"] = F["delta"]; f["source_index_0based"] = F["src"]; f["turn_angle_deg"] = F["phi"]
    f["times/julian_date"] = F["jd"]
    f["pointing/nvec_unit_cartesian"] = F["nvec"]; f["pointing/ecliptic_longitude_deg"] = lon; f["pointing/ecliptic_latitude_deg"] = lat
    for key, nm in (("S", "spherex/positions"), ("vS", "spherex/velocities"), ("E", "earth/positions"), ("vE", "earth/velocities"),
                    ("J", "jupiter/positions")):
        f[nm] = F[key]
print("DONE", flush=True)
