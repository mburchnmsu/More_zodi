# Cell contents for 11072026.ipynb — Nov 7: round 46, the one-at-a-time ablation of the best model (sweeps/configs_v46.jl;
# report sweeps/report46.jl, figure sweeps/plot46.jl).
#     julia --project=. sweeps/build_nb.jl sweeps/r46_text.jl 11072026.ipynb
CELLS = Pair{String,String}[

"markdown" => raw"""
# Which inputs does the model need? One-at-a-time ablation (Nov 7, 2026)

### Summary
* While the tall-table service is down, round 46 measured what each part of the best model is worth: the best model
  (parallax band layer + MLP, cos×exp 1000 epochs) retrained with **one input, one input pair, or the band layer removed**.
  8 variants × shifts 0 and 30 × seeds 42–44 = 48 runs on Discovery (jobs 693547–693554, 7.4–11.9 h each).
* **Two inputs are essential:** without the ecliptic-latitude input n·z, the error is 2090× higher; without Earth's orbital
  phase (sin/cos λ⊕), 1060× higher.
* **The band layer is worth 29% in MSE and 35% on the ecliptic** (0.0289% → 0.0189%).
* **The rest are redundant.** Removing n·S, n·E, n·vS, n·vE or n·x⊕/n·y⊕ changes nothing beyond seed noise, because each
  one can be rebuilt from the others.
""",

"code" => raw"""
const R = joinpath(@__DIR__, "..")
struct PNGFile; path::String; end; Base.show(io::IO, ::MIME"image/png", p::PNGFile) = write(io, read(p.path))   # raw PNG bytes: renders in any Jupyter front end
showpng(f) = PNGFile(joinpath(R, "figures", f))
using DelimitedFiles
A, h = readdlm(joinpath(R, "sweeps", "results_z500_helio", "r46_summary.csv"), ',', header=true)
println(join(h, "  ")); for i in axes(A, 1); println(join(A[i, :], "  ")); end
""",

"markdown" => raw"""
## 1. The result
3-network ensembles (seeds 42–44). MSE is on all withheld exposures of shifts 0 and 30 (together these withhold every
day once). The sky-map errors are on the interpolation windows. The full model is rounds 37–38 at the same shifts and seeds.

| removed | MSE ×10⁻⁸ shift 0 / 30 | × full | median | p95 | \|β\| < 2° | \|β\| > 60° |
|---|---|---|---|---|---|---|
| nothing (full model) | 1.42 / 1.71 | 1.00 | 0.0133% | 0.042% | 0.0189% | 0.0120% |
| n·S | 1.36 / 1.62 | 0.95 | 0.0131% | 0.041% | 0.0179% | 0.0119% |
| n·E | 1.43 / 1.74 | 1.01 | 0.0135% | 0.042% | 0.0191% | 0.0124% |
| n·vS | 1.37 / 1.55 | 0.93 | 0.0129% | 0.041% | 0.0184% | 0.0116% |
| n·vE | 1.36 / 1.56 | 0.93 | 0.0131% | 0.041% | 0.0186% | 0.0119% |
| n·x⊕, n·y⊕ | 1.39 / 1.69 | 0.98 | 0.0132% | 0.042% | 0.0188% | 0.0119% |
| **band layer** | 2.00 / 2.04 | **1.29** | 0.0135% | 0.044% | **0.0289%** | 0.0120% |
| **sin/cos λ⊕** | 1327 / 2003 | **1062** | 0.151% | 1.09% | 0.305% | 0.128% |
| **n·z** | 3044 / 3508 | **2090** | 0.080% | 2.00% | 0.098% | 0.362% |
""",

"code" => raw"""
showpng("11072026_r46_ablation.png")
""",

"markdown" => raw"""
## 2. What it means
* **n·z (ecliptic latitude) is essential.** The other inputs give |n·z| (n·x⊕² + n·y⊕² + n·z² = 1) but not its
  **sign**, so without n·z the model can't tell north from south. Kelsall's cloud is tilted ~2° and Earth sits above or
  below its mid-plane, so the two hemispheres differ. The large errors at high latitude (0.36%) and the 2% tail (p95) fit
  this. The band layer still gets n·z, but it only passes on band profiles that are nearly symmetric about the plane.
* **Earth's orbital phase is essential.** Without it, the model can't tell where Earth is in its orbit, so it can't
  follow the yearly changes (perihelion, the cloud's tilt and offset, the trailing cloud). This repeats the 44–65× gain
  from adding it on Oct 9; the gain is larger now because the rest of the model is better.
* **The band layer matters mainly on the ecliptic** (+53% error there without it, 1.29× MSE overall); away from the bands
  it makes no difference. This matches rounds 29–32.
* **n·S, n·E, n·vS, n·vE, n·x⊕/n·y⊕ are redundant with each other.** SPHEREx is ~5×10⁻⁵ AU from Earth, so n·S ≈ n·E and
  n·vS ≈ n·vE. Also n·E ≈ |E| n·x⊕, and n·y⊕ follows from n·vE. Removing any one leaves its copy in. The 0.93–1.01 ratios
  are seed noise: for comparison, the full model's 3-seed MSE (1.42 / 1.71) differs from its 5-seed MSE (1.38 / 1.57) by up
  to 9%.
* So the model could probably be slimmed: one input each from the S/E, vS/vE and x⊕/y⊕ groups, plus n·z and sin/cos λ⊕.
  Removing several at once was not tested here, and pairs may not be fully interchangeable. For real data, though, the
  SPHEREx-vs-Earth distinction is what the Earth-centric terms need, so we keep them for now.
""",
]
