# Cell contents for 11042026.ipynb — Nov 4: the mentor's request from the Nov 3 meeting: the 2-D residual map as Mollweide
# maps, with vs without the Earth-centric inputs (round 43, sweeps/configs_v43.jl; figure sweeps/earth2d.jl).
#     julia --project=. sweeps/build_nb.jl sweeps/r43_text.jl 11042026.ipynb
CELLS = Pair{String,String}[

"markdown" => raw"""
# 2-D residuals with and without the Earth-centric inputs (Nov 4, 2026)

### Summary
* Dr. Saydjari asked (Nov 3) for the 2-D residual map (notebook 10282026 §5) to be redone as **Mollweide maps**,
  comparing the model **with** and **without the Earth-centric inputs**.
* **Round 43** trained the best model (parallax band layer, cos×exp at 1000 epochs) with n·δ̂ (Earth-limb direction) and
  n·M̂ (Moon direction) added, on all 6 shifts × 5 seeds (Discovery jobs 692009–692014, 6.5–10.5 h each).
* **The two maps are the same to within ~0.006% (rms)** in both frames, and **neither shows a trailing-cloud residual.**
  As expected, the simulated Kelsall sky has no Earth- or Moon-centred light. This repeats round 33's null test on the
  current best model. These inputs only matter for real data (Earthshine, moonlight).
""",

"code" => raw"""
const R = joinpath(@__DIR__, "..")
struct PNGFile; path::String; end; Base.show(io::IO, ::MIME"image/png", p::PNGFile) = write(io, read(p.path))   # raw PNG bytes: renders in any Jupyter front end
showpng(f) = PNGFile(joinpath(R, "figures", f))
""",

"markdown" => raw"""
## 1. The maps (`sweeps/earth2d.jl`)
Mean residual (network − Kelsall, %) of the 5-network ensembles on the withheld interpolation windows of all 6 shifts, in
3° cells. Red means the network is too bright, blue too faint.
* **Top row: Earth-motion frame.** Longitude is measured from Earth's direction of motion (0 = ahead, 90 = Sun, 180 =
  behind, 270 = away from the Sun); latitude is ecliptic latitude. The map is centred on **behind Earth**, where Kelsall's
  trailing cloud sits. SPHEREx always looks ~90° from the Sun, so it covers only the band ahead of Earth (split across the
  two edges) and the band behind it (centre). The Sun and anti-Sun directions are never observed (grey).
* **Bottom row: ecliptic frame**, centred on ecliptic longitude 0°, like our other sky maps. The whole sky is covered.
* **Columns:** without the Earth-centric inputs (cos×exp 1000, rounds 37–38), with them (round 43), and with − without.
""",

"code" => raw"""
showpng("11042026_earth2d_moll.png")
""",

"markdown" => raw"""
## 2. Numbers

| | without Earth-centric inputs | with (n·δ̂, n·M̂) |
|---|---|---|
| ensemble test MSE, shifts 0/10/20/30/40/50 (×10⁻⁸) | 1.38 1.46 1.70 1.57 1.50 1.53 | 1.40 1.54 1.68 1.56 1.59 1.56 |
| mean over shifts | **1.52** | 1.56 |
| sky map: median / p95 | 0.0130% / 0.038% | 0.0130% / **0.037%** |
| within 2° of the ecliptic | 0.0181% | **0.0173%** |
| missing share of the trailing cloud, \|β\| < 15° | −0.0000 ± 0.0001 | −0.0001 ± 0.0001 |
| missing share of the trailing cloud, whole sky | +0.0002 ± 0.0001 | +0.0000 ± 0.0001 |
| mean residual behind Earth (φ 150–210°, \|β\| < 15°) | +0.0004% | +0.0001% |
| mean residual ahead of Earth (φ 330–30°, \|β\| < 15°) | +0.0007% | +0.0014% |

with − without, per exposure: mean +0.0003%, rms 0.006% (half the typical error, 0.013%).

* **No trailing-cloud residual in either model.** The missing share is the fitted slope of residual against the cloud's
  share of the light. −1 would mean the model misses the whole cloud, −0.01 would mean it misses 1% of it. We get
  0.0000–0.0002 ± 0.0001, so the network reproduces the trailing cloud to better than ~0.02% of it, with or without the
  Earth-centric inputs.
* **The Earth-centric inputs neither help nor hurt.** The mean MSE is 3% higher with them (1.56 vs 1.52), and the ecliptic
  is 4% better (0.0173% vs 0.0181%). Both are within the usual seed-to-seed spread, and the difference maps are almost
  white. The only visible structure is a few cells at the inner edge of the ahead band (±0.01–0.02%), at high latitude. The behind/ahead residuals differ by ~0.001%, 10× below the typical error.
* So on simulated data the network finds no spurious Earth- or Moon-related signal, consistent with round 33. On real
  SPHEREx data, where Earthshine and moonlight can leak into the images, these are the inputs that would pick them up.
""",
]
