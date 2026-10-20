"""Regenerate the simulated 5 um zodiacal light for the 500-day delivery (Oct 19, 2026) with ZodiPy 1.1.5, using the
same corrected setup as generate.py (which made the 140-day "z115" data).

Reads the 500-day mentor files in data/ (never modified):
  boresight_pointing.h5, spherex_vectors_bore_interpolated.h5, spherex_zodipy_5um_boresight_interpolated.h5,
  spherex_zodipy_5um_boresight_healpix_components_interpolated.h5   (made by data/regen_pipeline.py)
Writes NEW files:
  data/zodipy115_500d_boresight.h5           per-exposure emission + the 6 Kelsall components (same layout as z115)
  data/zodipy115_500d_healpix_components.h5  all-sky map (the delivery's nside-256 pixels) at the earliest exposure

Differences from the delivered emission (regen_pipeline.py), both deliberate:
  * observer = SPHEREx HELIOCENTRIC position (the pipeline passes the barycentric one: error #1 of the old data);
  * the 6 components are kept per exposure.
Times: regen_pipeline.py writes julian_date = obscore t_min (MJD) + 2400000.5 and treats it as UTC, so it is read as UTC
here (generate.py read the 140-day file's JD as TDB). ZodiPy batches are time-sorted chunks (the file is time-sorted).

Run:  <zodipy env python> -I zodipy_gen/generate_500.py <More_zodi root>
"""
import sys, time, ctypes, numpy as np, h5py, astropy.units as u
from astropy.time import Time
from astropy.coordinates import SkyCoord, BarycentricMeanEcliptic, HeliocentricMeanEcliptic, CartesianRepresentation, \
                                solar_system_ephemeris, get_body
import zodipy
from importlib.metadata import version

if sys.platform == "win32":                       # low priority: be nice to anything else on this PC
    ctypes.windll.kernel32.SetPriorityClass(ctypes.windll.kernel32.GetCurrentProcess(), 0x4000)  # BELOW_NORMAL

ROOT = sys.argv[1]; D = f"{ROOT}/data"
X = 5 * u.um; EPHEM = "de432s"; CHUNK = 2000
COMPS = ["smooth_cloud", "dust_band_1", "dust_band_2", "dust_band_3", "circum_solar_ring", "earth_trailing_feature"]

with h5py.File(f"{D}/boresight_pointing.h5") as f:
    lon = f["pointing/ecliptic_longitude_deg"][:]; lat = f["pointing/ecliptic_latitude_deg"][:]
    jd = f["times/julian_date"][:]
with h5py.File(f"{D}/spherex_zodipy_5um_boresight_interpolated.h5") as f:
    days = f["times/days_since_start"][:]; old = f["emission"][:]
    assert np.array_equal(f["times/julian_date"][:], jd)
with h5py.File(f"{D}/spherex_vectors_bore_interpolated.h5") as f:
    S_bary = f["spherex/positions"][:]; E_bary = f["earth/positions"][:]   # (N, 3) AU, barycentric ecliptic
N = len(jd)
assert S_bary.shape == (N, 3) and E_bary.shape == (N, 3), (S_bary.shape, N)
print(f"{N} exposures, JD {jd.min():.4f} .. {jd.max():.4f} ({jd.max() - jd.min():.2f} d), time-sorted: {bool(np.all(np.diff(jd) >= 0))}", flush=True)

def helio(xyz_bary, t):
    """barycentric ecliptic (N,3) AU -> heliocentric ecliptic (3,N) AU (astropy subtracts the Sun's position)."""
    c = BarycentricMeanEcliptic(CartesianRepresentation(xyz_bary.T * u.AU))
    with solar_system_ephemeris.set(EPHEM):
        return c.transform_to(HeliocentricMeanEcliptic(obstime=t)).cartesian.xyz.to_value(u.AU)

model = zodipy.Model(x=X, name="dirbe", ephemeris=EPHEM)

def evaluate(ii, comps=True):
    """ii must be sorted by time (ZodiPy splines Earth's position over [t_first, t_last]); times are UTC."""
    t = Time(jd[ii], format="jd", scale="utc")
    c = SkyCoord(lon[ii] * u.deg, lat[ii] * u.deg, frame="barycentricmeanecliptic", obstime=t)
    P = helio(S_bary[ii], t)
    if len(ii) == 1: P = P[:, 0]
    return model.evaluate(c, obspos=P * u.AU, return_comps=comps).value

# --- sanity checks ------------------------------------------------------------------------------------------------
idx = np.linspace(0, N - 1, 50).astype(int)
t_s = Time(jd[idx], format="jd", scale="utc")
E_file = helio(E_bary[idx], t_s)
E_eph = get_body("earth", t_s, ephemeris=EPHEM).transform_to(HeliocentricMeanEcliptic).cartesian.xyz.to_value(u.AU)
print(f"Earth: vectors file vs {EPHEM} (50 exposures across the 500 days): max |diff| {np.max(np.abs(E_file - E_eph)):.2e} AU", flush=True)
order = np.argsort(jd, kind="stable"); pos_in_order = np.empty(N, int); pos_in_order[order] = np.arange(N)
samp = order[np.linspace(0, N - 1, 40).astype(int)]
one = np.array([evaluate(np.array([k]), comps=False)[0] for k in samp])
chk = []
for k in samp:
    j0 = (pos_in_order[k] // CHUNK) * CHUNK; blk = order[j0:j0 + CHUNK]
    chk.append(evaluate(blk, comps=False)[pos_in_order[k] - j0])
rel = np.max(np.abs(np.array(chk) / one - 1))
print(f"vectorised chunks vs one-by-one (40 exposures across the 500 days): max rel diff {rel:.2e}", flush=True)
assert rel < 1e-7, "vectorised evaluation disagrees with single-exposure evaluation"

# --- boresight series ---------------------------------------------------------------------------------------------
t0 = time.time(); out = np.empty((len(COMPS), N))
for j in range(0, N, CHUNK):
    ii = order[j:j + CHUNK]
    out[:, ii] = evaluate(ii)
    if (j // CHUNK) % 50 == 0:
        el = time.time() - t0; print(f"  {j + len(ii):8d}/{N}  {el:6.0f}s  (eta {el / (j + len(ii)) * (N - j - len(ii)):5.0f}s)", flush=True)
tot = out.sum(0)
assert np.all(np.isfinite(out)) and np.all(tot > 0)
r = tot / old
print(f"boresight done in {time.time() - t0:.0f}s; new/delivered median {np.median(r):.5f}, range {r.min():.4f}..{r.max():.4f}", flush=True)
for a, b in ((0, 140), (140, 300), (300, 501)):
    k = (days >= a) & (days < b)
    print(f"  days {a:3d}-{b:3d}: new/delivered median {np.median(r[k]):.5f}, p1 {np.percentile(r[k], 1):.4f}, p99 {np.percentile(r[k], 99):.4f}", flush=True)

def stamp(g, **extra):
    m = g.create_group("metadata")
    for k, v in dict(created=time.strftime("%Y-%m-%dT%H:%M:%S"), zodipy_version=version("zodipy"),
                     astropy_version=version("astropy"), zodipy_model="dirbe (Kelsall 1998)", wavelength=5.0,
                     wavelength_units="micron", bandpass="none (monochromatic)", gauss_quad_degree=50,
                     ephemeris=EPHEM, time_scale="UTC (as written by regen_pipeline.py)",
                     observer="SPHEREx (spherex_vectors_bore_interpolated.h5, barycentric->heliocentric)",
                     emission_units="MJy/sr", generator="zodipy_gen/generate_500.py", **extra).items():
        m.attrs[k] = v

with h5py.File(f"{D}/zodipy115_500d_boresight.h5", "w") as f:
    stamp(f, description="Zodiacal light for the 500-day SPHEREx pointings, regenerated with ZodiPy", data_points=N)
    f["emission"] = tot
    for k, n in enumerate(COMPS): f[f"emission_{n}"] = out[k]
    f["coordinates/ecliptic_latitude_deg"] = lat; f["coordinates/ecliptic_longitude_deg"] = lon
    f["times/julian_date"] = jd; f["times/days_since_start"] = days
print("wrote data/zodipy115_500d_boresight.h5", flush=True)

# --- all-sky map at the earliest exposure ---------------------------------------------------------------------------
with h5py.File(f"{D}/spherex_zodipy_5um_boresight_healpix_components_interpolated.h5") as f0:
    plat = f0["ecliptic_latitude_deg"][:]; plon = f0["ecliptic_longitude_deg"][:]; pix = f0["pixels"][:]
k0 = order[0]; t = Time(jd[k0], format="jd", scale="utc")
c = SkyCoord(plon * u.deg, plat * u.deg, frame="barycentricmeanecliptic", obstime=t)
t1 = time.time()
sky = model.evaluate(c, obspos=helio(S_bary[k0:k0 + 1], t)[:, 0] * u.AU, return_comps=True).value
print(f"all-sky map ({len(pix)} pixels) at exposure index {k0} (jd {jd[k0]:.4f}) in {time.time() - t1:.0f}s", flush=True)
with h5py.File(f"{D}/zodipy115_500d_healpix_components.h5", "w") as f:
    stamp(f, description="All-sky zodiacal light at one epoch, regenerated with ZodiPy", epoch_index_0based=int(k0),
          epoch_jd=float(jd[k0]))
    f["emission"] = sky.sum(0)
    for k, n in enumerate(COMPS): f[f"emission_{n}"] = sky[k]
    f["ecliptic_latitude_deg"] = plat; f["ecliptic_longitude_deg"] = plon; f["pixels"] = pix
print("DONE", flush=True)
