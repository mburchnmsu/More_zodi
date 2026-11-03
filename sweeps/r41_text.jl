# Cell contents for 11032026.ipynb — Nov 3: round 41 (AdamW λ = 1e-4 on all 6 shifts, sweeps/report41.jl) and round 42
# (best-epoch selection, sweeps/report42.jl).
#     julia --project=. sweeps/build_nb.jl sweeps/r41_text.jl 11032026.ipynb
CELLS = Pair{String,String}[

"markdown" => raw"""
# AdamW on all 6 shifts, and why best-epoch selection failed (Nov 3, 2026)

### Summary
* **Round 41 (§1):** AdamW λ = 1e-4 on the 3 remaining shifts, so it now has a full 6-shift sky map. It is marginally the
  best 2000-epoch setting (ecliptic 0.0161% vs 0.0163%, mean ensemble MSE 1.58 vs 1.61 × 10⁻⁸), but the gain is within
  the noise and cos×exp 1000 still has the lowest mean MSE (1.52).
* **Round 42 (§2): best-epoch selection made things 3–5× worse** (ensemble test MSE), and the last-epoch networks of
  the same runs were just as bad. The cause is the validation window itself: holding out days Δ + 240–270 removes the only training data
  for that part of Earth's orbit. Not usable as designed; a better design is in §2.
""",

"code" => raw"""
const R = joinpath(@__DIR__, "..")
struct PNGFile; path::String; end; Base.show(io::IO, ::MIME"image/png", p::PNGFile) = write(io, read(p.path))   # raw PNG bytes: renders in any Jupyter front end
showpng(f) = PNGFile(joinpath(R, "figures", f))
""",

"markdown" => raw"""
## 1. Round 41: AdamW λ = 1e-4 on all 6 shifts (`sweeps/configs_v41.jl`, report `sweeps/report41.jl`)
Shifts 10, 20, 50 × 5 seeds (Discovery jobs 691528–691530, 12–20 h each); shifts 0, 30, 40 are from round 40.

| ensemble test MSE (×10⁻⁸) | 0 | 10 | 20 | 30 | 40 | 50 | mean |
|---|---|---|---|---|---|---|---|
| cos×exp, 1000 epochs | 1.38 | 1.46 | 1.70 | **1.57** | **1.50** | 1.53 | **1.52** |
| cos×exp, 2000 epochs (round 39) | 1.39 | 1.46 | 1.58 | 2.12 | 1.68 | 1.43 | 1.61 |
| + AdamW λ = 1e-4 | **1.29** | 1.51 | 1.59 | 1.99 | 1.70 | **1.40** | 1.58 |

| sky map, interpolation windows of all 6 shifts | median | p95 | within 2° of the ecliptic | above 60° |
|---|---|---|---|---|
| cos×exp, 1000 epochs | 0.0130% | 0.038% | 0.0181% | 0.0118% |
| cos×exp, 2000 epochs | 0.0129% | 0.035% | 0.0163% | 0.0119% |
| + AdamW λ = 1e-4 | 0.0129% | 0.035% | **0.0161%** | 0.0118% |

λ = 1e-4 is a small, mostly neutral change: the difference map against 2000 epochs without decay (bottom right) is
almost white. The comparison with 1000 epochs (bottom left) shows the same trade as before: 2000 epochs wins along the
ecliptic, but its mean MSE is pulled up by shift 30.
""",

"code" => raw"""
showpng("11032026_r41_sky.png")
""",

"markdown" => raw"""
## 2. Round 42: best-epoch selection (`sweeps/configs_v42.jl`, report `sweeps/report42.jl`)
cos×exp 2000 without decay, with one training window (k = 8, t_rel ∈ [Δ + 240, Δ + 270)) held out as validation and the
best-validation epoch kept. Shifts 0, 30, 40 × 5 seeds (jobs 691539–691541, 17–20 h each).

| ensemble test MSE (×10⁻⁸) | shift 0 | 30 | 40 |
|---|---|---|---|
| cos×exp 2000 (round 39) | **1.39** | **2.12** | **1.68** |
| best epoch (round 42) | 6.72 | 7.70 | 4.54 |

| per seed (×10⁻⁸) | shift 0 | 30 | 40 |
|---|---|---|---|
| round 39, last epoch | 1.5–2.1 | 1.9–3.9 | 1.8–2.4 |
| round 42, best epoch | 12–23 | 8–31 | 9–19 |
| round 42, last epoch | 11–21 | 21–36 | 6–9 |
| round 42, best epoch number | 145–531 | 111–325 | 177–514 |

**What went wrong.** The last-epoch networks are just as bad, so the problem is the training data, not the epoch
selection. The data span 500 days, so Earth's orbital phases from day ~135 to day 365 are seen only once. The
validation window (days Δ + 240–270) sits in that once-seen stretch, between test windows 7 and 9. Holding it out leaves a
**90-day stretch of Earth's orbit with no training data at all**. The validation loss (~1–4 × 10⁻⁶, 50× the test MSE)
therefore measures 45-day extrapolation in orbital phase. It bottoms out early (epochs 110–530) and says little about the
30-day test gaps. The errors are worst around the hole (windows 5–9), but every test window got 2–7× worse, even ones
200 days away. A plausible reason is that the network's orbital-phase inputs (sin/cos λ⊕) are shared by the whole year, so a fit
left unconstrained over 90° of orbit also bends elsewhere. That part is not proven.

**A better design, if we retry:**
* Hold out a window whose orbital phase is also seen elsewhere in training (days 365–500 repeat days 0–135).
* Or validate on a few days from the middle of each training window, not a whole window.
* Or choose the epoch count from the shifts themselves (1000 vs 2000 epochs already does this roughly).
""",
]
