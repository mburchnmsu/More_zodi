"""Speed benchmark, ZodiPy side (for the poster's speed claim). Pair: poster/bench_emulator.jl.

Times ZodiPy 1.1.5 (Kelsall/DIRBE, 5 um, default gauss_quad_degree 50, total emission only) on the SAME exposures the
emulator is timed on: a time-contiguous block of mission exposures (indices written to poster/bench_idx.txt, 1-based for
Julia). Observer-position conversion (astropy) is done BEFORE the clock starts -- only model.evaluate is timed, which is
the generous choice for ZodiPy. Also times single-exposure calls (one pointing, one time).

Run:  <zodipy env python> -I -X utf8 poster/bench_zodipy.py <More_zodi root>
"""
import sys, time, os, numpy as np, h5py, astropy.units as u
from astropy.time import Time
from astropy.coordinates import SkyCoord, BarycentricMeanEcliptic, HeliocentricMeanEcliptic, CartesianRepresentation, \
                                solar_system_ephemeris
import zodipy

ROOT = sys.argv[1]; D = f"{ROOT}/data"; EPHEM = "de432s"
NB = 20000          # batch size (block of exposures)
NSINGLE = 30        # single-exposure calls

with h5py.File(f"{D}/d140/boresight_pointing.h5") as f:
    lon = f["pointing/ecliptic_longitude_deg"][:]; lat = f["pointing/ecliptic_latitude_deg"][:]
    jd = f["times/julian_date"][:]
with h5py.File(f"{D}/d140/spherex_vectors_bore_interpolated.h5") as f:
    S_bary = f["spherex/positions"][:]

order = np.argsort(jd, kind="stable")
mid = len(order) // 2
ii = order[mid:mid + NB]                                 # contiguous in time, middle of the mission
np.savetxt(f"{ROOT}/poster/bench_idx.txt", ii + 1, fmt="%d")

def helio(xyz_bary, t):
    c = BarycentricMeanEcliptic(CartesianRepresentation(xyz_bary.T * u.AU))
    with solar_system_ephemeris.set(EPHEM):
        return c.transform_to(HeliocentricMeanEcliptic(obstime=t)).cartesian.xyz.to_value(u.AU)

model = zodipy.Model(x=5 * u.um, name="dirbe", ephemeris=EPHEM)
t = Time(jd[ii], format="jd", scale="tdb").utc
c = SkyCoord(lon[ii] * u.deg, lat[ii] * u.deg, frame="barycentricmeanecliptic", obstime=t)
P = helio(S_bary[ii], t) * u.AU

model.evaluate(c[:200], obspos=P[:, :200])              # warm-up (ephemeris load, caches)
times = []
for rep in range(3):
    t0 = time.perf_counter(); yz = model.evaluate(c, obspos=P).value; times.append(time.perf_counter() - t0)
tb = min(times)
print(f"ZodiPy batch: {NB} exposures, best of 3 = {tb:.2f} s  ->  {1e6 * tb / NB:.1f} us per exposure  (all: {[round(x, 2) for x in times]})")

ts = []
for k in ii[:NSINGLE]:
    tk = Time(jd[k], format="jd", scale="tdb").utc
    ck = SkyCoord(lon[k] * u.deg, lat[k] * u.deg, frame="barycentricmeanecliptic", obstime=tk)
    Pk = helio(S_bary[k:k + 1], tk)[:, 0] * u.AU
    t0 = time.perf_counter(); model.evaluate(ck, obspos=Pk); ts.append(time.perf_counter() - t0)
print(f"ZodiPy single exposure: median {1e3 * np.median(ts[1:]):.1f} ms per call ({NSINGLE} calls)")
np.save(f"{ROOT}/poster/bench_zodipy_y.npy", yz)
print(f"threads: OMP={os.environ.get('OMP_NUM_THREADS')}  cpu_count={os.cpu_count()}")
