# Cell contents for 10282026.ipynb — Oct 27–28: round 35, cos×exp learning-rate schedule vs one-cycle.
#     julia --project=. sweeps/build_nb.jl sweeps/r35_text.jl 10282026.ipynb
CELLS = Pair{String,String}[

"markdown" => raw"""
# Learning-rate schedule: cos×exp vs one-cycle (round 35, Oct 27–28, 2026)

The user's idea (Oct 27): replace the one-cycle learning-rate schedule with an exponential cosine. A cos×exp schedule
had been compared on Oct 6–7 (`sweeps/REPORT.md`): it was indistinguishable from one-cycle at the time, but that was the
old 100-epoch setup with errors ~10⁴× larger. At today's accuracy most of the gain comes late in training, at small
learning rates, so the schedule's shape could matter more.

**Setup** (`sweeps/configs_v35.jl`): the parallax band layer, 500 epochs, shifts 0 (poster split) and 30 (the split
that overfit at 2000 epochs) × 5 seeds. New schedule `:cosexpw` (`sweeps/mb_train.jl`): a cosine warm-up from
peak/25 over the first 5% of training, then lr = peak · ½(1 + cos πu) · e^(−3u) + peak/10⁴ (u = 0 → 1 after the
warm-up). Peak 2e-3, chosen so the **average learning rate equals one-cycle's** at peak 1e-3 (5.1e-4 vs 5.06e-4): only
the shape differs. Baseline: rounds 31–32, the same model with one-cycle. Report: `sweeps/report35.jl`.

### Summary
* **cos×exp wins on both shifts.** Shift 0: ensemble test MSE **2.44e-8 → 1.94e-8 (−21%)**, ecliptic 0.029% → 0.025%.
  Shift 30: 2.53e-8 → 2.32e-8 (−8%).
* The shift-0 gain is larger than seed noise (per-seed means 2.94 ± 0.24 vs 2.43 ± 0.36 ×10⁻⁸, about 2.7 standard errors).
  The shift-30 gain is not (3.09 ± 0.19 vs 2.95 ± 0.19, about 1.2).
* **Why:** cos×exp reaches its peak after 25 epochs and starts decaying immediately, so the loss falls much faster early.
  It then spends the second half at small learning rates. The withheld-month loss flattens from ~epoch 350 while the
  training loss keeps falling, the same signature as the 2000-epoch shift-30 runs.
* For scale: at 500 epochs cos×exp gets shift 0 about halfway to the 2000-epoch result (1.47e-8) at a quarter of the
  cost. On shift 30 it beats both one-cycle runs (500 epochs 2.53e-8, 2000 epochs 2.80e-8).
""",

"code" => raw"""
using CairoMakie
const R = joinpath(@__DIR__, "..")
showpng(f) = CairoMakie.Makie.FileIO.load(joinpath(R, "figures", f))
""",

"markdown" => raw"""
## 1. Results on the withheld months

| | schedule | per-seed test MSE (×10⁻⁸) | ensemble MSE | median | p95 | ecliptic (<2°) |
|---|---|---|---|---|---|---|
| shift 0 | one-cycle 1e-3 | 2.78 2.94 3.20 2.64 3.14 | 2.44e-8 | 0.0162% | 0.051% | 0.0292% |
| shift 0 | **cos×exp 2e-3** | 1.98 2.66 2.60 2.11 2.79 | **1.94e-8** | **0.0149%** | **0.046%** | **0.0247%** |
| shift 30 | one-cycle 1e-3 | 2.81 3.18 2.99 3.19 3.29 | 2.53e-8 | 0.0171% | 0.054% | 0.0299% |
| shift 30 | **cos×exp 2e-3** | 2.93 2.96 2.83 2.77 3.25 | **2.32e-8** | **0.0162%** | **0.050%** | **0.0261%** |
""",

"markdown" => raw"""
## 2. Loss curves and the two schedules
Left and middle: epoch-averaged loss, 5 seeds averaged (dashed = training months, solid = withheld months). Right: the
learning rate against epoch.
""",

"code" => raw"""
showpng("10282026_r35_schedule.png")
""",

"markdown" => raw"""
## 3. Options for next (need the user's OK)
* cos×exp on the remaining 4 shifts at 500 epochs (~11 h) → a full sky map to compare with rounds 32 and 34.
* cos×exp at 2000 epochs, to see whether the schedule and longer training add up. It may overfit more, since it spends
  even longer at small learning rates.
* A fix for the late flattening seen on shift 30 (a validation month with best-epoch selection, or weight decay).
""",
]
