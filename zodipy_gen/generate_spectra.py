"""Round 13: reference ZodiPy spectra (1.25–5.0 um, 120 wavelengths) for 6 mission exposures at different ecliptic
latitudes, to compare with the multi-wavelength emulator's predicted spectra. Writes data/zodipy115_spectra.h5 (new).
Same ZodiPy settings as generate.py.   Run:  <zodipy env python> -I -X utf8 zodipy_gen/generate_spectra.py <root>"""
import sys, time, numpy as np, h5py, astropy.units as u
from astropy.time import Time
from astropy.coordinates import SkyCoord, BarycentricMeanEcliptic, HeliocentricMeanEcliptic, CartesianRepresentation, solar_system_ephemeris
import zodipy
D = f"{sys.argv[1]}/data"; EPHEM = "de432s"
WAVES = np.geomspace(1.25, 5.0, 120)
with h5py.File(f"{D}/boresight_pointing.h5") as f:
    lon = f["pointing/ecliptic_longitude_deg"][:]; lat = f["pointing/ecliptic_latitude_deg"][:]; jd = f["times/julian_date"][:]
with h5py.File(f"{D}/spherex_vectors_bore_interpolated.h5") as f:
    S = f["spherex/positions"][:]
rng = np.random.default_rng(7)
targets = [0, 15, 35, 55, 75, 88]                      # ecliptic latitude (deg) of each chosen exposure
idx = np.array([rng.choice(np.where(np.abs(lat - b) < 1.0)[0]) for b in targets])
def helio(x, t):
    c = BarycentricMeanEcliptic(CartesianRepresentation(x.T * u.AU))
    with solar_system_ephemeris.set(EPHEM):
        return c.transform_to(HeliocentricMeanEcliptic(obstime=t)).cartesian.xyz.to_value(u.AU)
spec = np.empty((len(idx), len(WAVES)))
for j, w in enumerate(WAVES):
    m = zodipy.Model(x=w * u.um, name="dirbe", ephemeris=EPHEM)
    for i, k in enumerate(idx):
        t = Time(jd[k], format="jd", scale="tdb")
        sc = SkyCoord(lon[k] * u.deg, lat[k] * u.deg, frame="barycentricmeanecliptic", obstime=t.utc)
        spec[i, j] = m.evaluate(sc, obspos=helio(S[k:k + 1], t)[:, 0] * u.AU).value.ravel()[0]
with h5py.File(f"{D}/zodipy115_spectra.h5", "w") as f:
    f["index_0based"] = idx; f["wavelength_um"] = WAVES; f["emission"] = spec
    f["ecliptic_latitude_deg"] = lat[idx]; f["ecliptic_longitude_deg"] = lon[idx]
    f.attrs["created"] = time.strftime("%Y-%m-%dT%H:%M:%S"); f.attrs["generator"] = "zodipy_gen/generate_spectra.py"
for i, k in enumerate(idx):
    print(f"exposure {k:6d}  lat {lat[k]:6.1f}  spectrum min {spec[i].min():.4f} at {WAVES[spec[i].argmin()]:.2f} um, "
          f"1.25 um {spec[i, 0]:.4f}, 5.0 um {spec[i, -1]:.4f} MJy/sr")
print("DONE")
