"""Week 15 task 6: Earth's barycentric position and velocity (ecliptic J2000, AU and AU/day) at each exposure's mid-time,
for the onboarding registry vectors S⃗ (SPHEREx ≈ Earth; the 5×10⁻⁵ AU low-Earth-orbit offset is ignored for now) and v̂_E.
    C:\\JuliaDEPOT\\conda\\3\\x86_64\\envs\\zodipy\\python.exe -I realdata/exposure_ephem.py \
        data/tt_diffmed_sum/tt_diffmed_exposures.csv data/tt_change_ephem.csv
Input: a CSV with imageid, t_beg, t_end (MJD). Output: imageid, t_mid, Sx, Sy, Sz, vx, vy, vz."""
import sys
import numpy as np
from astropy.time import Time
from astropy.coordinates import get_body_barycentric_posvel, solar_system_ephemeris

src, dst = sys.argv[1], sys.argv[2]
h = open(src).readline().strip().split(",")
A = np.genfromtxt(src, delimiter=",", skip_header=1, usecols=(h.index("imageid"), h.index("t_beg"), h.index("t_end")),
                  dtype=[("id", "i8"), ("tb", "f8"), ("te", "f8")])
tm = 0.5 * (A["tb"] + A["te"])
with solar_system_ephemeris.set("builtin"):
    p, v = get_body_barycentric_posvel("earth", Time(tm, format="mjd", scale="utc"))
eps = np.deg2rad(23.4392911)                          # ICRS (equatorial) → ecliptic J2000: rotate about x by −ε
def ecl(xyz):
    x, y, z = xyz
    return np.vstack([x, y * np.cos(eps) + z * np.sin(eps), -y * np.sin(eps) + z * np.cos(eps)])
P = ecl(p.xyz.to_value("AU")); V = ecl(v.xyz.to_value("AU/d"))
with open(dst, "w") as f:
    f.write("imageid,t_mid,Sx,Sy,Sz,vx,vy,vz\n")
    for i in range(len(tm)):
        f.write(f"{A['id'][i]},{tm[i]:.7f},{P[0,i]:.9f},{P[1,i]:.9f},{P[2,i]:.9f},{V[0,i]:.9e},{V[1,i]:.9e},{V[2,i]:.9e}\n")
print(f"{len(tm)} exposures, |S| {np.linalg.norm(P, axis=0).min():.4f}–{np.linalg.norm(P, axis=0).max():.4f} AU, "
      f"max |Sz| {np.abs(P[2]).max():.2e} AU -> {dst}")
