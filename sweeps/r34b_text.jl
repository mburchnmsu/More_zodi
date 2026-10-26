# Cell contents for 10262026.ipynb — Oct 26: round 34 (parallax band layer at 2000 epochs), 3 of 6 shifts.
#     julia sweeps/build_nb.jl sweeps/r34b_text.jl 10262026.ipynb
CELLS = Pair{String,String}[

"markdown" => raw"""
# 2000-epoch training of the parallax band layer — halfway (Oct 26, 2026)

Continuation of `notebooks/10242026.ipynb`: round 34 trains the parallax dust-band layer for 2000 epochs (vs 500) on all
6 month-on/month-off shifts × 5 seeds (`sweeps/configs_v34.jl`). Progress figures from `sweeps/report34.jl`.

### Summary (shifts 0, 10 and 20 done, 15 of 30 runs)
* **Shift 20 repeats the gain:** ensemble test MSE **2.40e-8 → 1.54e-8** (shift 0: 2.44e-8 → 1.47e-8, shift 10:
  2.37e-8 → 1.48e-8). It is consistent across splits, not a property of the poster split.
* Sky map from the three finished shifts: ecliptic 0.0288% → **0.0167%**, median 0.0158% → **0.0133%**,
  p95 0.050% → **0.036%**, above 60° 0.0135% → 0.0127%.
* **Interruption:** from Sat 22:39 to Mon 10:28 the laptop ran on battery and kept entering Modern Standby, which pauses
  training. Nothing was lost (finished runs are saved and the batch resumed where it stopped). The shift-20 batch then
  finished at 14:28 Mon on AC power.
""",

"code" => raw"""
using CairoMakie
const R = joinpath(@__DIR__, "..")
showpng(f) = CairoMakie.Makie.FileIO.load(joinpath(R, "figures", f))
""",

"markdown" => raw"""
## 1. Per-shift ensemble test MSE (5-network average on the withheld months, (MJy/sr)²)

| shift (days) | 500 epochs | 2000 epochs | change |
|---|---|---|---|
| 0 (poster split) | 2.44e-8 | **1.47e-8** | −40% |
| 10 | 2.37e-8 | **1.48e-8** | −38% |
| 20 | 2.40e-8 | **1.54e-8** | −36% |

Loss curves, poster split (unchanged since Oct 24, repeated for reference): the withheld-month loss falls through all
2000 epochs, with no sign of overfitting.
""",

"code" => raw"""
showpng("10262026_r34_loss.png")
""",

"markdown" => raw"""
## 2. Sky map from the shifts finished so far (0, 10, 20)
Each pointing predicted by the versions that withheld it (between-month windows), 3.5° patches. Difference panel: blue =
2000 epochs better. The ecliptic stripe is mostly gone, and the improvement covers most of the sky. The red patches are
small, about 0.01%, and scattered.

| shifts 0 + 10 + 20 | median | p95 | ecliptic (<2°) | above 60° |
|---|---|---|---|---|
| 500 epochs (rounds 31–32) | 0.0158% | 0.050% | 0.0288% | 0.0135% |
| **2000 epochs (round 34)** | **0.0133%** | **0.036%** | **0.0167%** | **0.0127%** |
""",

"code" => raw"""
showpng("10262026_r34_sky_3shifts.png")
""",

"markdown" => raw"""
## 3. Next
Shifts 30, 40 and 50 continue (estimates on AC power: ~01:30 Tue, ~13:00 Tue, ~00:00 Wed), then the full 6-shift map,
fitted band parameters at 2000 epochs, and a final notebook.
""",
]
