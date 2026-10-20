"""Regenerate the simulated 5 um zodiacal light with ZodiPy 1.1.5 (Kelsall/DIRBE model), self-consistently.

Writes NEW files only (the original data/*.h5 are read, never modified):
  data/zodipy115_5um_boresight.h5           per-exposure emission (+ the 6 components), same layout as
                                            spherex_zodipy_5um_boresight_interpolated.h5
  data/zodipy115_5um_healpix_components.h5  all-sky map (nside 256, same pixels/lat/lon as the original) at the
                                            earliest exposure (the epoch of the original all-sky map)

Settings: model 'dirbe' (Kelsall 1998), x = 5 um (no bandpass), gauss_quad_degree 50 (default), ephemeris de432s,
observer = SPHEREx's own position from spherex_vectors_bore_interpolated.h5 (barycentric -> heliocentric ecliptic),
obstime = each exposure's JD (TDB).

Run:  <zodipy env python> -I zodipy_gen/generate.py <More_zodi root>
"""
import sys, time, ctypes, numpy as np, h5py, astropy.units as u
from astropy.time import Time
from astropy.coordinates import SkyCoord, BarycentricMeanEcliptic, HeliocentricMeanEcliptic, CartesianRepresentation, \
                                solar_system_ephemeris
import zodipy
from importlib.metadata import version

if sys.platform == "win32":                       # be nice to the other project running on this PC
    ctypes.windll.kernel32.SetPriorityClass(ctypes.windll.kernel32.GetCurrentProcess(), 0x4000)  # BELOW_NORMAL

ROOT = sys.argv[1]; D = f"{ROOT}/data"
X = 5 * u.um; EPHEM = "de432s"; CHUNK = 2000
COMPS = ["smooth_cloud", "dust_band_1", "dust_band_2", "dust_band_3", "circum_solar_ring", "earth_trailing_feature"]

with h5py.File(f"{D}/d140/boresight_pointing.h5") as f:
    lon = f["pointing/ecliptic_longitude_deg"][:]; lat = f["pointing/ecliptic_latitude_deg"][:]
    jd = f["times/julian_date"][:]
with h5py.File(f"{D}/d140/spherex_zodipy_5um_boresight_interpolated.h5") as f:
    days = f["times/days_since_start"][:]
    assert np.array_equal(f["times/julian_date"][:], jd)
with h5py.File(f"{D}/d140/spherex_vectors_bore_interpolated.h5") as f:
    S_bary = f["spherex/positions"][:]; E_bary = f["earth/positions"][:]   # (N, 3) AU, barycentric ecliptic
N = len(jd)

def helio(xyz_bary, t):
    """barycentric ecliptic (N,3) AU -> heliocentric ecliptic (3,N) AU (astropy subtracts the Sun's position)."""
    c = BarycentricMeanEcliptic(CartesianRepresentation(xyz_bary.T * u.AU))
    with solar_system_ephemeris.set(EPHEM):          # the Sun's barycentric position from the same ephemeris
        return c.transform_to(HeliocentricMeanEcliptic(obstime=t)).cartesian.xyz.to_value(u.AU)

model = zodipy.Model(x=X, name="dirbe", ephemeris=EPHEM)

def evaluate(ii, comps=True):
    """ii must be sorted by time (ZodiPy splines Earth's position over [t_first, t_last])."""
    # Same instants, expressed in UTC: in batch mode ZodiPy builds its Earth-position spline on UTC nodes
    # (bodies.arrange_obstimes) but looks up obstime.mjd in the obstime's own scale -> a 69 s (TDB-UTC) shift.
    t = Time(jd[ii], format="jd", scale="tdb").utc
    c = SkyCoord(lon[ii] * u.deg, lat[ii] * u.deg, frame="barycentricmeanecliptic", obstime=t)
    P = helio(S_bary[ii], t)
    if len(ii) == 1: P = P[:, 0]                      # ZodiPy wants shape (3,) for a single time, (3, n) otherwise
    return model.evaluate(c, obspos=P * u.AU, return_comps=comps).value

# --- sanity: Earth from the vectors file vs ZodiPy's ephemeris; vectorised == one-by-one -------------
t_s = Time(jd[:50], format="jd", scale="tdb")
E_file = helio(E_bary[:50], t_s)
from astropy.coordinates import get_body
E_eph = get_body("earth", t_s, ephemeris=EPHEM).transform_to(HeliocentricMeanEcliptic).cartesian.xyz.to_value(u.AU)
print(f"Earth: vectors file vs {EPHEM}: max |diff| {np.max(np.abs(E_file - E_eph)):.2e} AU", flush=True)

# Vectorised chunks (as used below) vs one exposure at a time, for 40 exposures spread over the mission.
order = np.argsort(jd, kind="stable")              # time order; chunks are contiguous in time
pos_in_order = np.empty(N, int); pos_in_order[order] = np.arange(N)
samp = order[np.linspace(0, N - 1, 40).astype(int)]
one = np.array([evaluate(np.array([k]), comps=False)[0] for k in samp])
chk = []
for k in samp:
    j0 = (pos_in_order[k] // CHUNK) * CHUNK; blk = order[j0:j0 + CHUNK]     # the exact chunk k will be in
    chk.append(evaluate(blk, comps=False)[pos_in_order[k] - j0])
rel = np.max(np.abs(np.array(chk) / one - 1))
print(f"vectorised chunks vs one-by-one (40 exposures across the mission): max rel diff {rel:.2e}", flush=True)
assert rel < 1e-7, "vectorised evaluation disagrees with single-exposure evaluation"

# --- boresight series ---------------------------------------------------------------------------------
t0 = time.time(); out = np.empty((len(COMPS), N))
for j in range(0, N, CHUNK):
    ii = order[j:j + CHUNK]
    out[:, ii] = evaluate(ii)
    if (j // CHUNK) % 20 == 0:
        el = time.time() - t0; print(f"  {j + len(ii):7d}/{N}  {el:6.0f}s  (eta {el / (j + len(ii)) * (N - j - len(ii)):5.0f}s)", flush=True)
tot = out.sum(0)
assert np.all(np.isfinite(out)) and np.all(tot > 0)
with h5py.File(f"{D}/d140/spherex_zodipy_5um_boresight_interpolated.h5") as f0:
    old = f0["emission"][:]
print(f"boresight done in {time.time() - t0:.0f}s; new/old median {np.median(tot / old):.5f}, range {np.min(tot / old):.4f}..{np.max(tot / old):.4f}", flush=True)

def stamp(g, **extra):
    m = g.create_group("metadata")
    for k, v in dict(created=time.strftime("%Y-%m-%dT%H:%M:%S"), zodipy_version=version("zodipy"),
                     astropy_version=version("astropy"), zodipy_model="dirbe (Kelsall 1998)", wavelength=5.0,
                     wavelength_units="micron", bandpass="none (monochromatic)", gauss_quad_degree=50,
                     ephemeris=EPHEM, observer="SPHEREx (spherex_vectors_bore_interpolated.h5, barycentric->heliocentric)",
                     emission_units="MJy/sr", generator="zodipy_gen/generate.py", **extra).items():
        m.attrs[k] = v

with h5py.File(f"{D}/zodipy115_5um_boresight.h5", "w") as f:
    stamp(f, description="Zodiacal light for SPHEREx pointing directions, regenerated with ZodiPy", data_points=N)
    f["emission"] = tot
    for k, n in enumerate(COMPS): f[f"emission_{n}"] = out[k]
    f["coordinates/ecliptic_latitude_deg"] = lat; f["coordinates/ecliptic_longitude_deg"] = lon
    f["times/julian_date"] = jd; f["times/days_since_start"] = days

# --- all-sky map at the earliest exposure ---------------------------------------------------------------
with h5py.File(f"{D}/d140/spherex_zodipy_5um_boresight_healpix_components_interpolated.h5") as f0:
    plat = f0["ecliptic_latitude_deg"][:]; plon = f0["ecliptic_longitude_deg"][:]; pix = f0["pixels"][:]
k0 = order[0]; t = Time(jd[k0], format="jd", scale="tdb")
c = SkyCoord(plon * u.deg, plat * u.deg, frame="barycentricmeanecliptic", obstime=t)
t1 = time.time()
sky = model.evaluate(c, obspos=helio(S_bary[k0:k0 + 1], t)[:, 0] * u.AU, return_comps=True).value
print(f"all-sky map ({len(pix)} pixels) at exposure index {k0} (jd {jd[k0]:.4f}) in {time.time() - t1:.0f}s", flush=True)
with h5py.File(f"{D}/zodipy115_5um_healpix_components.h5", "w") as f:
    stamp(f, description="All-sky zodiacal light at one epoch, regenerated with ZodiPy", epoch_index_0based=int(k0),
          epoch_jd=float(jd[k0]))
    f["emission"] = sky.sum(0)
    for k, n in enumerate(COMPS): f[f"emission_{n}"] = sky[k]
    f["ecliptic_latitude_deg"] = plat; f["ecliptic_longitude_deg"] = plon; f["pixels"] = pix
print("DONE", flush=True)
