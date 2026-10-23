# Cell contents for 10232026.ipynb — Oct 22–23: the parallax dust-band layer (round 31), the full 500-day sky map with it
# (round 32) and the mentor's Earth-centric null test (round 33).
#     julia sweeps/build_nb.jl sweeps/r31_text.jl 10232026.ipynb
CELLS = Pair{String,String}[

"markdown" => raw"""
# Parallax dust-band layer, its full sky map, and the Earth-centric null test (Oct 22–23, 2026)

The user's plan (Oct 22, "C, then D"): test a **parallax** version of the learnable band layer on the poster split; run the
winning layer on all 6 month-on/month-off shifts for a full sky map; then the mentor's **Earth-centric null test**. All
runs: heliocentric 500-day data, 5 μm, 5 seeds, 500 epochs, band parameters started from Kelsall's values
(`sweeps/configs_v31.jl`, chained by `sweeps/run_round31.ps1`; log `sweeps/round31.log`).

### Summary
* **Parallax wins (round 31, poster split):** ecliptic error **0.0326% → 0.0292%**, ensemble MSE 2.66e-8 → 2.44e-8;
  median, p95 and poles unchanged.
* **Full sky map with the parallax band layer (rounds 31–32, 30 networks):** within 2° of the ecliptic
  **0.050% → 0.0285%** (43% lower) vs the same model without bands (round 29). Elsewhere essentially unchanged: median
  0.0157% (0.0154%), p95 0.049% (0.050%), above 60° 0.0134% (0.0130%).
* **Fitted bands are consistent across all 30 networks** (inclinations ~1°; band 2 width 1.7°; effective distances
  1.4–2.0 AU, ordered like ZodiPy's inner cutoffs).
* **Earth-centric null test passes (round 33):** adding n·δ̂ (Earth-limb direction) and n·M̂ (Moon direction) changes
  nothing beyond seed scatter, as it should on simulated data (ZodiPy has no Earth- or Moon-centred light).
""",

"code" => raw"""
using CairoMakie
const R = joinpath(@__DIR__, "..")
showpng(f) = CairoMakie.Makie.FileIO.load(joinpath(R, "figures", f))
""",

"markdown" => raw"""
## 1. The parallax band layer (round 31)
Round 30's layer measured each band's latitude **as seen from the Sun's centre**. Kelsall's bands are 3-D structures
1–3 AU from the Sun, seen from SPHEREx at ~1 AU, so their apparent latitude shifts with the observer's position
(parallax). `BandLayerPLX` (`sweeps/band_layer.jl`, `arch = :bandplx`) adds that: for band k with plane normal Nₖ and a
**trainable distance** Rₖ = 1.05 + softplus(rₖ) AU (start 1.5 AU), it finds where the line of sight from the observer O
reaches distance Rₖ, s = −n̂·O + √((n̂·O)² − |O|² + Rₖ²), and uses that point's height above the band plane,
ζₖ = (Nₖ·O + s Nₖ·n̂)/Rₖ, in Kelsall's profile gₖ = exp(−uₖ⁶)(vₖ + uₖ⁴). The observer's heliocentric position enters
through S·x, S·y, S·z (inputs `FEATURE_SETS[:sunseason_learnband_plx]`). Smoke test: at the start values the layer matches
the fixed band@1.5 AU profiles to 1e-6, and all 5 parameters per band get non-zero gradients.

Poster split (shift 0), 5-network average (`sweeps/decide31.jl`, `sweeps/earthc_compare.jl`):

| model | median | p95 | ecliptic (<2°) | above 60° | ensemble MSE |
|---|---|---|---|---|---|
| no bands (round 27) | 0.0157% | 0.051% | 0.0442% | 0.0140% | 3.10e-8 |
| learnable bands, no parallax (round 30) | 0.0161% | 0.051% | 0.0326% | 0.0144% | 2.66e-8 |
| **learnable bands + parallax (round 31)** | 0.0162% | 0.051% | **0.0292%** | 0.0143% | **2.44e-8** |

The rule set in advance (lower ecliptic error wins; MSE breaks a tie within 3%) picked the parallax layer for the map.
""",

"markdown" => raw"""
## 2. Full sky map with the parallax band layer (round 32)
Shifts 10–50 (25 runs) plus round 31's shift 0; map from `sweeps/r24_data.jl` (`R24_FAM = "z500h_bandplx_kelsall_shift"`,
`R24_OUT = "r32_summary.jld2"`) and `sweeps/plot_r32.jl`. Each pointing is predicted by the versions that withheld it
(between-month windows), 3.5° patches.

| 500-day sky map (heliocentric, 6 shifts) | median | p95 | ecliptic (<2°) | above 60° |
|---|---|---|---|---|
| no band layer (round 29) | 0.0154% | 0.050% | 0.0499% | 0.0130% |
| **parallax band layer (round 32)** | 0.0157% | 0.049% | **0.0285%** | 0.0134% |

Per shift (between-month medians 0.0157–0.0167%; ensemble test MSE 2.37–2.53e-8) all six behave alike. In the
difference map (right) the bright stripe along the ecliptic is gone (blue); away from it the change is ±0.005%, i.e.
noise-level with a slight (0.0003%) cost in the median.
""",

"code" => raw"""
showpng("10232026_skymap_bandplx.png")
""",

"markdown" => raw"""
### Fitted band parameters (all 30 networks; `sweeps/band_params_r32.jl`)

| band | inclination i (°) | node Ω (°, circular) | width δζ (°) | shape v | distance R (AU) | ZodiPy inner cutoff δr (AU) |
|---|---|---|---|---|---|---|
| 1 | 1.08 ± 0.18 | 22.6 ± 5.4 | 3.52 ± 0.29 | 0.21 ± 0.07 | 1.76 ± 0.17 | 1.5 |
| 2 | 0.91 ± 0.11 | 17.8 ± 8.6 | 1.69 ± 0.21 | 1.06 ± 0.33 | 1.42 ± 0.15 | 0.94 |
| 3 | 1.13 ± 0.29 | 19.2 ± 7.8 | 5.57 ± 0.43 | 0.06 ± 0.01 | 2.04 ± 0.29 | 1.5 |
| Kelsall (i / Ω / δζ / v) | 0.56 / 80 / 8.78 / 0.10 · 1.20 / 30.35 / 1.99 / 0.90 · 0.80 / 80 / 15.0 / 0.05 | | | | | |

**Reading.**
* A plain average of round 31's band-2 node gave "89°" — an artefact: one seed's node is 359.96° (≡ 0°) and was averaged
  with values near 20–30°. The circular mean is 18°; nodes scatter by ±5–9° from seed to seed, which is expected for
  planes tilted only ~1° (the node of a nearly flat ring is weakly constrained).
* Band 2 (the one that matters most) keeps a Kelsall-like tilt (0.9° vs 1.2°) and width (1.7° vs 2.0°).
* Kelsall's bands are not thin rings: in ZodiPy each starts at an inner cutoff δr and fades outward as ~1/R. The layer's
  single R is therefore an *effective* distance; the fits land a little outside each inner cutoff and in the same order
  (band 2 closest). Bands 1 and 3 remain faint (≤0.05% of the light), so their parameters are less like Kelsall's.
""",

"markdown" => raw"""
## 3. The mentor's Earth-centric null test (round 33)
Inputs: the 9 heliocentric poster inputs **plus** n·δ̂ (direction of Earth's limb) and n·M̂ (direction to the Moon from
SPHEREx) — `FEATURE_SETS[:sunseason_earthcentric]`. ZodiPy's simulated sky has no Earth- or Moon-centred light, so on
this data these inputs should not help; on real SPHEREx data (Earthshine, moonlight) they may. Poster split, 5 seeds:

| model | median | p95 | ecliptic (<2°) | above 60° | ensemble MSE | single-network MSE (mean ± std) |
|---|---|---|---|---|---|---|
| poster inputs (round 27) | 0.0157% | 0.051% | 0.0442% | 0.0140% | 3.10e-8 | 3.66e-8 ± 0.20e-8 |
| + n·δ̂ + n·M̂ (round 33) | 0.0158% | 0.052% | 0.0444% | 0.0138% | 3.12e-8 | 3.79e-8 ± 0.40e-8 |

**Null passes:** every difference is within the seed-to-seed spread. The network neither finds a spurious signal in the
Earth/Moon directions nor is hurt by having them. They are ready to add for real data.
""",

"markdown" => raw"""
## 4. Next
* The parallax band layer is the best 500-day model so far (ecliptic 0.0285% on the full sky map).
* Possible: a radial profile for each band (inner cutoff + ~1/R falloff, as in ZodiPy) instead of one effective R; a
  one-at-a-time ablation table; the Earth-centric terms on real SPHEREx data (with star masking, when the user says so).
""",
]
