# Cell contents for 11092026.ipynb — the Nov 8 offset map and component fits redone on the 192-patch grid (grid 2, level-6
# patches ~15° apart, 8 wavelength windows): Discovery job 695791 + the ThinkPad chain (ZodiPy, talltable_offsetmap.jl,
# offset_fit.jl, talltable_zodipy_comps.py, offset_comps.jl, plot_comps_spectrum.jl, all with tag 11092026).
#     julia --project=. sweeps/build_nb.jl sweeps/tt_offset_g2_text.jl 11092026.ipynb
CELLS = Pair{String,String}[

"markdown" => raw"""
# The offset map with 4× the patches (Nov 9, 2026)

### Summary
* Yesterday's (11082026) answer to Dr. Saydjari's mean-sky offset question used 48 patches (34 off the Galactic plane).
  Overnight the same pipeline ran on **192 patches, 144 with |b| > 15°**, at the same 8 wavelengths (1.3–5 μm).
* **The main result holds, with errors 2–4× smaller:** off the plane, the offset is zodi that Kelsall misses. Kelsall is too
  faint by **7% (1.3 μm), 12–14% (1.6–2.9 μm), 31% (3.45 μm), 14–19% (4.1–5 μm)**, plus a constant 0.03–0.06 MJy/sr.
* **The 3.45 μm peak is real:** c1 = 0.31 ± 0.03, against 0.12–0.17 in the windows on either side.
* **SPHEREx's zodi model still leaves no proportional part** (c1 −0.06 to +0.01), only a constant 0.026–0.056 MJy/sr.
* **Components:** the smooth cloud is too faint at every wavelength (over time: +4% to +32%). The Earth-trailing feature is
  weaker than Kelsall at 4.1 and 5 μm (k ≈ −0.65 ± 0.08), but not consistently at other wavelengths. With 4× the patches,
  the "brighter bands" hint from yesterday is gone (all within ~1.7σ of zero).
* The fits explain less of the patch-to-patch scatter than on grid 1 (R² 0.15–0.68 with the Galactic term, vs 0.54–0.77),
  mostly below 4 μm: the larger grid has more patches at 15–30° from the plane and near bright stars (no masking yet).
""",

"code" => raw"""
const R = joinpath(@__DIR__, "..")
struct PNGFile; path::String; end; Base.show(io::IO, ::MIME"image/png", p::PNGFile) = write(io, read(p.path))   # raw PNG bytes: renders in any Jupyter front end
showpng(f) = PNGFile(joinpath(R, "figures", f))
using DelimitedFiles, Printf
D = joinpath(R, "data", "spherex_real")     # git-ignored; made by the scripts listed in the first line of sweeps/tt_offset_g2_text.jl
function showtab(f)
    A, h = readdlm(joinpath(D, f), ',', header=true); println(join(h, "  "))
    for i in axes(A, 1); println(join((x isa AbstractFloat ? @sprintf("%.4g", x) : string(x) for x in A[i, :]), "  ")); end
end
""",

"markdown" => raw"""
## 1. The run
* Discovery job 695791: 228 partitions (389 GB) downloaded to scratch, then `talltable_bins.py 6 grid 2` in 8 windows,
  ~20 min per window, all 192 patches with data (finished 17:05).
* ThinkPad: ZodiPy at every exposure (~18 min per window), offset maps and fits (done 20:15), then Kelsall's six
  components at every exposure and the component fits (done 22:10).
* Ours vs ZodiPy at 5 μm over all 192 patches: ≤ 0.050% (median per patch), so "ours" = Kelsall below.
* (The 5 μm map title says "4.9–5.0 μm"; the window is 4.9–5.1 μm. The label is fixed in the script for future runs.)
""",

"markdown" => raw"""
## 2. The offset map at 4.9–5.1 μm
""",

"code" => raw"""
showpng("11092026_offsetmap_L6_grid2.png")
""",

"markdown" => raw"""
* In the ecliptic frame (left) the offset is largest along the ecliptic; in the Galactic frame (right) the bright points
  are on the plane. The bottom panels show the same: a few Galactic-plane patches at 0.5–2.2 MJy/sr, everything else
  0.08–0.35 MJy/sr.
* Against SPHEREx's zodi model (orange) the off-plane offset is flat at ~0.04 MJy/sr at every ecliptic latitude.

Fits over the 144 patches with |b| > 15°:

| model of the offset | coefficients (MJy/sr) | rms left | R² |
|---|---|---|---|
| c0 + c1·Kelsall | c0 = 0.036 ± 0.006, **c1 = 0.181 ± 0.006** | 0.017 | 0.65 |
| c0 + c1·Kelsall + c2·csc\|b\| | 0.021, 0.187, c2 = 0.0064 ± 0.0020 | 0.017 | 0.68 |
| c0 + c2·csc\|b\| (a Galactic sky only) | 0.128, 0.001 | 0.030 | **0.00** |
| SPHEREx zodi model: c0 + c1·(its model) | c0 = 0.036 ± 0.004, c1 = 0.009 ± 0.008 | 0.012 | 0.01 |

Grid 1 gave c1 = 0.188 ± 0.020 (R² 0.74): the same number, with a third of the error.
""",

"markdown" => raw"""
## 3. The 8-wavelength spectrum
|b| > 15°, 144 patches (grid-1 value in brackets):

| window (μm) | Kelsall, median (MJy/sr) | c1, Kelsall only | c1 with a csc\|b\| term | c2 (csc\|b\|) | R² with c2 | per-patch time-fit scale a | SPHEREx: c0, c1 |
|---|---|---|---|---|---|---|---|
| 1.25–1.35 | 0.180 | 0.03 ± 0.04 | 0.07 ± 0.04 (0.05) | 0.017 | 0.15 | 1.16 | 0.056, −0.06 |
| 1.6–1.7 | 0.160 | 0.10 ± 0.03 | 0.14 ± 0.02 (0.13) | 0.016 | 0.36 | 1.30 | 0.043, −0.04 |
| 2.2–2.3 | 0.112 | 0.09 ± 0.03 | 0.12 ± 0.02 (0.14) | 0.011 | 0.34 | 1.12 | 0.031, −0.04 |
| 2.8–2.9 | 0.086 | 0.08 ± 0.03 | 0.12 ± 0.03 (0.11) | 0.009 | 0.27 | 1.09 | 0.028, −0.04 |
| 3.4–3.5 | 0.077 | 0.26 ± 0.03 | **0.31 ± 0.03** (0.27) | 0.011 | 0.59 | 1.19 | 0.026, −0.02 |
| 4.05–4.15 | 0.145 | 0.16 ± 0.03 | 0.17 ± 0.03 (0.18) | 0.007 | 0.21 | 1.08 | 0.036, −0.05 |
| 4.5–4.6 | 0.277 | 0.13 ± 0.01 | 0.14 ± 0.01 (0.14) | 0.006 | 0.43 | 1.06 | 0.039, −0.00 |
| 4.9–5.1 | 0.488 | 0.18 ± 0.01 | 0.19 ± 0.01 (0.19) | 0.006 | 0.68 | 1.09 | 0.036, +0.01 |
""",

"code" => raw"""
showpng("11092026_offset_spectrum_L6_grid2.png")
""",

"code" => raw"""
showtab("ttbin_L6_grid2_offset_fit.csv")
""",

"markdown" => raw"""
* **Every c1 agrees with grid 1 within its error**, and the per-patch scale over time (a = 1.06–1.30) again agrees on the sign.
* **The 3.45 μm peak** is now 0.31 ± 0.03, 3–6σ above its neighbours. DIRBE measured 3.5 μm directly, so it is not ZodiPy
  interpolating. Kelsall's 3.5 μm emissivity may be too low, or there is extra emission near 3.3–3.4 μm (the PAH band
  is at 3.3 μm, but this window is 3.4–3.5 μm). This is a question for the mentor.
* **R² is lower than on grid 1 below 4 μm** (0.15–0.36 vs 0.54–0.76). The rms left is about the same (0.012–0.031 MJy/sr),
  but grid 2 adds many patches where the zodi varies little and stars/Galaxy dominate the scatter. Star masking would help.
* SPHEREx's model: c1 ≈ 0 at all 8 windows, constant lowest at 2–3.5 μm (0.026–0.031) and highest at 1.3 μm (0.056).
""",

"code" => raw"""
showpng("11092026_offsetmap_L6_grid2_w3.4.png")
""",

"markdown" => raw"""
## 4. Which Kelsall component is too faint? (192 patches)
Same method as 11082026 §5: measured − Kelsall = constant + Σ k·component, (A) across the sky (144 off-plane patch medians),
(B) over time with one constant per patch (all 192 patches pooled), and (B) with SPHEREx's zodi model in place of the
measurement. Bootstrap over patches. Off the plane at 5 μm: cloud 94.0% of Kelsall, ring 2.8%, feature 2.6%, bands 0.4%.

At 4.9–5.1 μm (grid 1 in brackets):

| component | (A) across the sky | (B) over time | (B) with SPHEREx's model as the "sky" |
|---|---|---|---|
| smooth cloud | +0.10 ± 0.02 (+0.14) | **+0.059 ± 0.005** (+0.055) | +0.117 ± 0.005 |
| dust bands | +2.1 ± 0.7 (+2.2) | +0.96 ± 0.57 (+2.3) | +0.70 ± 0.50 |
| ring | +1.0 ± 0.3 (+0.45) | +0.09 ± 0.13 (−0.08) | −0.01 ± 0.10 |
| trailing feature | +0.14 ± 0.23 (−0.24) | **−0.63 ± 0.07** (−0.79) | −0.32 ± 0.06 |
| one scale for all of Kelsall (B) | | +0.092 ± 0.005 | |
""",

"code" => raw"""
showpng("11092026_offset_comps_L6_grid2.png")
""",

"code" => raw"""
showpng("11092026_offset_comps_spectrum_L6_grid2.png")
""",

"code" => raw"""
for w in ("", "_w1.25", "_w1.6", "_w2.2", "_w2.8", "_w3.4", "_w4.05", "_w4.5")
    println("── window ", isempty(w) ? "4.9–5.1" : w[3:end]); showtab("ttbin_L6_grid2$(w)_comps_fit.csv")
end
""",

"markdown" => raw"""
(B) over time, all 8 windows:

| window (μm) | 1.3 | 1.65 | 2.25 | 2.85 | 3.45 | 4.1 | 4.55 | 4.95 |
|---|---|---|---|---|---|---|---|---|
| smooth cloud | +0.12 | +0.32 | +0.14 | +0.09 | +0.18 | +0.04 | +0.04 | +0.06 |
| dust bands | +0.1 ± 0.3 | −0.2 ± 0.3 | +0.1 ± 0.3 | −0.2 ± 0.3 | −0.3 ± 0.3 | +0.0 ± 0.3 | −0.3 ± 0.3 | +1.0 ± 0.6 |
| ring | +0.12 ± 0.16 | +0.52 ± 0.21 | −0.02 ± 0.20 | −0.18 ± 0.18 | **+1.00 ± 0.18** | +0.32 ± 0.15 | +0.28 ± 0.12 | +0.09 ± 0.13 |
| trailing feature | −0.30 ± 0.10 | +0.48 ± 0.13 | +0.13 ± 0.11 | +0.04 ± 0.10 | −0.25 ± 0.11 | **−0.67 ± 0.09** | −0.29 ± 0.07 | **−0.63 ± 0.07** |

(cloud errors 0.005–0.017)

* **The smooth cloud is too faint at every wavelength**, in both (A) and (B), and in SPHEREx's own model (+0.09 to +0.26).
  This is the robust result and the same scale-up as §3. (B) gives a smaller k than (A) at 4–5 μm (0.04–0.06 vs 0.06–0.10).
* **Trailing feature:** weaker than Kelsall at 4.1 and 5 μm (~8σ each), weaker at 1.3, 3.45 and 4.55 μm (2.5–4σ), but
  *stronger* at 1.65 μm (+0.48 ± 0.13). The feature and the cloud are anti-correlated in the fit (−0.5), and the values
  scatter more than their errors, so this is still a hint, not a measurement.
* **Dust bands:** yesterday's +1–2σ "brighter" hint is gone; with 4× the patches every window is within ~1.7σ of zero.
* **Ring:** +1.0 ± 0.2 at 3.45 μm, the same window as the c1 peak in §3. Part of the 3.45 μm excess may sit near the
  ecliptic plane / close to the Sun (where the ring is), but the ring is only ~3% of Kelsall, so this needs caution.
""",

"markdown" => raw"""
## 5. Caveats and next steps
* No star masking (user's rule for now). The csc|b| term and the lower R² below 4 μm are where it would matter.
* Each patch is seen at only a few elongations per year, so (B) mostly compares leading vs trailing views; the feature
  and the cloud are hard to separate this way (fit correlation −0.5).
* The scratch copy of the tall table (~470 GB) is no longer needed for these results; delete it, or keep it for a
  grid-3 / star-masked rerun (the user decides).
* Questions for Dr. Saydjari: is the 3.45 μm excess known (SPHEREx's own zodi model absorbs it)? Should the emulator be
  retrained on SPHEREx's zodi model, or should we fit a per-wavelength scale to Kelsall? Is it time to mask stars?
""",
]
