# Cell contents for 10222026.ipynb — Oct 21–22: heliocentric inputs as the default, the full heliocentric 500-day sky map
# (round 29), ZodiOnboarding.ipynb, and the learnable dust-band layer (round 30).
#     julia sweeps/build_nb.jl sweeps/r30_text.jl 10222026.ipynb
CELLS = Pair{String,String}[

"markdown" => raw"""
# Full heliocentric sky map and a learnable dust-band layer (Oct 21–22, 2026)

The plan for this window (relayed by Project Hub): (1) switch to heliocentric inputs and rerun the 500-day sky map;
(2) `ZodiOnboarding.ipynb`; (3) start the learnable dust-band layer. The poster went to print on Oct 21 and is final.

### Summary
* **Heliocentric inputs are the default for the 500-day data** (`zodi_setup.jl`: `ZODI_HELIO` defaults to 1 for
  `z500`/`d500`; the 140-day modes stay barycentric because their saved models, incl. the poster model, were trained so).
* **Full heliocentric 500-day sky map** (6 shifts × 5 seeds, 500 epochs, no n·J): median **0.0154%**, p95 **0.050%**,
  within 2° of the ecliptic **0.050%**, above 60° **0.0130%** — better than barycentric + n·J on every measure
  (0.0162% / 0.053% / 0.064% / 0.0140%).
* **`ZodiOnboarding.ipynb`** (project root): the orientation notebook, organised like ExoOnboarding / SolOnboarding.
* **Learnable dust-band layer** (`sweeps/band_layer.jl`, `arch = :bandmlp`): Kelsall's band profile with *trainable*
  inclination, node, width and shape for each of the 3 bands. On the poster split it cuts the ecliptic error
  **0.044% → 0.033%** (median unchanged ~0.016%, ensemble MSE 3.1e-8 → 2.4–2.7e-8). Started from Kelsall's values or
  from deliberately wrong ones, the fits converge to the **same** parameters: the strong band 2 lands near Kelsall
  (node 30–32° vs 30.3°, inclination ~1.0° vs 1.2°, width 2.4° vs 2.0°); the faint bands 1 and 3 settle on different,
  consistent values (they carry ≤0.05% of the light and the layer has no parallax term).
""",

"code" => raw"""
using CairoMakie
const R = joinpath(@__DIR__, "..")
struct PNGFile; path::String; end; Base.show(io::IO, ::MIME"image/png", p::PNGFile) = write(io, read(p.path))   # raw PNG bytes: renders in any Jupyter front end
showpng(f) = PNGFile(joinpath(R, "figures", f))
""",

"markdown" => raw"""
## 1. The full heliocentric 500-day sky map (round 29)
Rounds 27 (shift 0), 28 (shift 30) and 29 (shifts 10, 20, 40, 50): the heliocentric, no-n·J model, 5 seeds each,
500 epochs (`sweeps/configs_v29.jl`; map from `sweeps/r24_data.jl` with `R24_FAM = "z500h_noJ_shift"` and
`sweeps/plot_r28.jl`). Right panel below; between-month medians per shift 0.0157–0.0165%.

| 500-day sky map | median | p95 | ecliptic (<2°) | above 60° |
|---|---|---|---|---|
| barycentric + n·J (round 24) | 0.0162% | 0.053% | 0.064% | 0.0140% |
| **heliocentric, no n·J (rounds 27–29)** | **0.0154%** | **0.050%** | **0.050%** | **0.0130%** |
""",

"code" => raw"""
showpng("10212026_skymap_helio.png")
""",

"markdown" => raw"""
## 2. A learnable dust-band layer (round 30)
The user's plan (Oct 19): don't feed Kelsall's *fixed* band shapes (that imports the simulator's answer); learn the band
parameters from the data, so that on real SPHEREx data the fitted values become a measurement.

For each band k the layer computes, from the pointing vector, the latitude above the band's plane and Kelsall's profile:
ζₖ = asin(n̂·Nₖ) with Nₖ = (sin iₖ sin Ωₖ, −sin iₖ cos Ωₖ, cos iₖ); uₖ = |ζₖ|/δζₖ; gₖ = exp(−uₖ⁶)(vₖ + uₖ⁴). The
inclination iₖ, node Ωₖ, width δζₖ and shape vₖ are **trainable**; the 3 profiles are appended to the 9 heliocentric
inputs and the usual MLP follows (`sweeps/band_layer.jl`; inputs `FEATURE_SETS[:sunseason_learnband]`). Smoke test: at
Kelsall's values the layer reproduces the fixed profiles of `extra_features.jl` to 1e-6.

Poster split (shift 0), heliocentric 500-day data, 5 seeds, 500 epochs (`sweeps/configs_v30.jl`, `sweeps/band_compare.jl`):

| model | median | p95 | ecliptic (<2°) | above 60° | ensemble MSE |
|---|---|---|---|---|---|
| no bands (round 27) | 0.0157% | 0.051% | 0.044% | 0.0140% | 3.1e-8 |
| learnable bands, Kelsall start | 0.0161% | 0.051% | **0.033%** | 0.0144% | 2.7e-8 |
| learnable bands, perturbed start | 0.0157% | 0.050% | **0.033%** | 0.0142% | 2.4e-8 |

Fitted parameters (mean ± spread over the 5 seeds):

| band | parameter | Kelsall | from Kelsall start | from perturbed start (start value) |
|---|---|---|---|---|
| 2 (strongest) | inclination i (°) | 1.20 | 0.97 ± 0.06 | 1.03 ± 0.15 (2.20) |
| 2 | node Ω (°) | 30.35 | 29.7 ± 4.7 | 31.9 ± 11.3 (60.35) |
| 2 | width δζ (°) | 1.99 | 2.47 ± 0.23 | 2.45 ± 0.52 (2.99) |
| 1 | i / Ω / δζ | 0.56 / 80 / 8.8 | 1.05 / 41.7 / 3.9 | 1.05 / 43.2 / 4.0 (1.56 / 110 / 13.2) |
| 3 | i / Ω / δζ | 0.80 / 80 / 15.0 | 1.11 / 41.6 / 5.7 | 1.07 / 43.4 / 5.8 (1.80 / 110 / 22.5) |

**Reading:** both starts converge to the same solution, so the parameters are identifiable from the data. Band 2, which
carries most of the band light near the ecliptic (~1.7%), comes back close to Kelsall's geometry — the recovery test
passes for it. Bands 1 and 3 are faint (≤0.05% of the light) and converge to different (but consistent) values: the
layer has no parallax term (Kelsall's bands are 3-D rings seen from 1 AU), so the network likely uses those two profiles
for other ecliptic structure. The ecliptic error drops 26% without hard-coding Kelsall's parameters.

## 3. Next
* Learnable bands on all 6 shifts (a full sky map; ~13 h) and a parallax version of the layer.
* The mentor's Earth-centric terms for real data (n̂·δ̂, the Moon), first as a null on simulated data.
""",
]
