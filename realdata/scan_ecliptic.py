"""Choose an ecliptic sky point for the real-data movie: for ecliptic longitudes every 15 deg (latitude 0), count the D6
images that see the point at 4.9-5.1 um (estimated, same method as find_frames.py), and give the Galactic latitude so
points in the Milky Way's plane (bright, crowded) can be avoided. Only IRSA metadata, no images.

    python -I realdata/scan_ecliptic.py <wave_table_cutout.fits>
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import find_frames as ff
from astropy.coordinates import SkyCoord, GeocentricTrueEcliptic
import astropy.units as u

lam = ff.wave_table(sys.argv[1])
print(f"{'lon':>5} {'RA':>8} {'Dec':>8} {'gal b':>6} {'cover':>6} {'in 4.9-5.1':>10}  by release")
for lon in range(0, 360, 15):
    c = SkyCoord(lon=lon * u.deg, lat=0 * u.deg, frame=GeocentricTrueEcliptic(equinox="J2000")).icrs
    ff.RA0, ff.DEC0 = round(c.ra.deg, 6), round(c.dec.deg, 6)
    rows = ff.tap(f"SELECT obs_collection, t_min, s_region FROM spherex.obscore WHERE energy_bandpassname = '{ff.DET}' "
                  f"AND CONTAINS(POINT('ICRS', {ff.RA0}, {ff.DEC0}), s_region) = 1")
    n, by = 0, {}
    for r in rows:
        x, y = ff.point_pixel(r["s_region"])
        if 1 <= x <= 2040 and 1 <= y <= 2040 and ff.LAM_LO - ff.MARGIN <= lam(x, y) <= ff.LAM_HI + ff.MARGIN:
            n += 1; by[r["obs_collection"]] = by.get(r["obs_collection"], 0) + 1
    print(f"{lon:5d} {ff.RA0:8.3f} {ff.DEC0:8.3f} {c.galactic.b.deg:6.1f} {len(rows):6d} {n:10d}  {dict(sorted(by.items()))}", flush=True)
