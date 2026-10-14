"""Reproduce the ORIGINAL simulated data (data/spherex_zodipy_5um_boresight_interpolated.h5) exactly, to document
how it was made and what is wrong with it. Read-only: writes nothing.

Finding (2026-10-13): the original matches ZodiPy 1.1.5 (dirbe, 5 um, builtin ephemeris) to ~3e-7 when
  (1) obspos = SPHEREx's BARYCENTRIC position (ZodiPy expects heliocentric -> observer off by the Sun-barycentre
      offset, ~0.007 AU), and
  (2) all exposures are evaluated in ONE batch in FILE order, so ZodiPy's Earth-position spline spans only
      [first, last] exposure in the file = day 0 .. day 51.6 and is EXTRAPOLATED for every other exposure
      (Earth off by 2e-4 AU at day 65, 0.01 AU at day 88, 0.12 AU / 5.6 deg at day 124). Earth's position sets the
      circumsolar ring and the Earth-trailing feature.

Run:  <zodipy env python> -I zodipy_gen/reproduce_original.py <More_zodi root>   (~1 min; prints the match)
"""
import sys, numpy as np, h5py, astropy.units as u
from astropy.time import Time
from astropy.coordinates import SkyCoord
import zodipy, zodipy.model as zm

D = f"{sys.argv[1]}/data"
with h5py.File(f"{D}/boresight_pointing.h5") as f:
    lon = f["pointing/ecliptic_longitude_deg"][:]; lat = f["pointing/ecliptic_latitude_deg"][:]; jd = f["times/julian_date"][:]
with h5py.File(f"{D}/spherex_zodipy_5um_boresight_interpolated.h5") as f:
    old = f["emission"][:]; days = f["times/days_since_start"][:]
with h5py.File(f"{D}/spherex_vectors_bore_interpolated.h5") as f:
    S = f["spherex/positions"][:]

tt = Time(jd, format="jd")                                   # as a user would write it (scale UTC by default)
orig = zm.arrange_obstimes
zm.arrange_obstimes = lambda t0, t1: orig(tt[0].mjd, tt[-1].mjd)   # = what a single file-order batch would use
k = np.sort(np.random.default_rng(3).choice(len(jd), 20000, replace=False))
m = zodipy.Model(x=5 * u.um)                                 # defaults: dirbe, builtin ephemeris
c = SkyCoord(lon[k] * u.deg, lat[k] * u.deg, frame="barycentricmeanecliptic", obstime=tt[k])
v = m.evaluate(c, obspos=S[k].T * u.AU).value                # barycentric position passed as if heliocentric
r = v / old[k]
print(f"file order runs from day {days[0]:.2f} to day {days[-1]:.2f} (mission {days.min():.2f}..{days.max():.2f})")
print(f"reproduction of the original on {len(k)} exposures: median ratio {np.median(r):.8f}, max |ratio - 1| {np.max(np.abs(r - 1)):.2e}")
