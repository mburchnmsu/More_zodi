# Cell contents for 10242026.ipynb — Oct 23–24: round 34 (parallax band layer at 2000 epochs), first 2 of 6 shifts.
#     julia sweeps/build_nb.jl sweeps/r34a_text.jl 10242026.ipynb
CELLS = Pair{String,String}[

"markdown" => raw"""
# 2000-epoch training of the parallax band layer — first results (Oct 23–24, 2026)

The user's weekend plan (Oct 23): train the best 500-day model — the learnable **parallax dust-band layer** (rounds 31–32,
`notebooks/10232026.ipynb`) — for **2000 epochs instead of 500**, on all 6 month-on/month-off shifts × 5 seeds
(`sweeps/configs_v34.jl`, `sweeps/run_round34.ps1`; started 16:35 Fri, ~11 h per shift, done ~Mon morning). Same
architecture, data (heliocentric 500 days, 5 μm), batch 512 and one-cycle schedule (peak 1e-3), stretched over the 2000
epochs: a fresh, longer run, not a continuation. Progress reports: `sweeps/report34.jl`.

### Summary (shifts 0 and 10 done, 10 of 30 runs)
* **2000 epochs is much better than 500.** Poster split (shift 0): ensemble test MSE **2.44e-8 → 1.47e-8**, ecliptic
  **0.0292% → 0.0161%**, median 0.0162% → 0.0135%, p95 0.051% → 0.040%. Shift 10 the same (MSE 2.37e-8 → 1.48e-8).
* **No overfitting:** the withheld-month loss falls throughout and is still falling slowly at epoch 2000; the train/test
  gap widens (final epoch-averaged MSE 7.1e-9 / 1.8e-8) but the test error never turns up.
* Sky map from the two finished shifts: ecliptic 0.0294% → **0.0164%**, median 0.0156% → **0.0132%**,
  p95 0.049% → 0.037%, above 60° 0.0134% → 0.0128%.
""",

"code" => raw"""
using CairoMakie
const R = joinpath(@__DIR__, "..")
showpng(f) = CairoMakie.Makie.FileIO.load(joinpath(R, "figures", f))
""",

"markdown" => raw"""
## 1. Loss curves, poster split (5 seeds averaged; dashed = training months, solid = withheld months)
Left: against epoch. Right: against the fraction of the schedule, so the two one-cycle schedules line up. At the same
point of its schedule the 2000-epoch run is always lower, and it ends ~40% lower on the withheld months.
""",

"code" => raw"""
showpng("10242026_r34_loss.png")
""",

"markdown" => raw"""
## 2. Sky map from the shifts finished so far (0 and 10)
Each pointing predicted by the versions that withheld it (between-month windows), 3.5° patches; grey = sky not yet covered
by a finished shift. Difference panel: blue = 2000 epochs better. The ecliptic stripe is almost gone; the improvement is
broad, with scattered small red patches at the noise level of a 2-shift map.

| shifts 0 + 10 | median | p95 | ecliptic (<2°) | above 60° |
|---|---|---|---|---|
| 500 epochs (rounds 31–32) | 0.0156% | 0.049% | 0.0294% | 0.0134% |
| **2000 epochs (round 34)** | **0.0132%** | **0.037%** | **0.0164%** | **0.0128%** |
""",

"code" => raw"""
showpng("10242026_r34_sky_2shifts.png")
""",

"markdown" => raw"""
## 3. Next
Shifts 20–50 continue (~02:00 Sun, ~13:00 Sun, ~00:00 Mon, ~11:00 Mon); the full 6-shift map follows. Since the test loss
is still falling at 2000 epochs, a longer run (or more width) may still help; this is the first time training length,
not inputs, has been the limit.
""",
]
