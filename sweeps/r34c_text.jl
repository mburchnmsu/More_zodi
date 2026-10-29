# Cell contents for 10272026.ipynb — Oct 27: round 34 complete (parallax band layer, 2000 vs 500 epochs, all 6 shifts),
# the shift-30 exception, fitted band parameters at 2000 epochs, round 35 queued.
#     julia --project=. sweeps/build_nb.jl sweeps/r34c_text.jl 10272026.ipynb
CELLS = Pair{String,String}[

"markdown" => raw"""
# 2000-epoch training of the parallax band layer — complete (Oct 27, 2026)

Round 34 (`sweeps/configs_v34.jl`, started 16:35 Fri Oct 23, finished 23:11 Tue Oct 27, with ~36 h lost to standby over
the weekend): the parallax dust-band layer trained for 2000 epochs instead of 500, on all 6 month-on/month-off shifts ×
5 seeds. Earlier parts: `notebooks/10242026.ipynb`, `notebooks/10262026.ipynb`.

### Summary
* **Full 6-shift sky map, 500 → 2000 epochs:** median 0.0157% → **0.0130%**, p95 0.049% → **0.035%**, within 2° of the
  ecliptic 0.0285% → **0.0162%** (−43%), above 60° 0.0134% → **0.0120%**. This is the best 500-day model so far.
* **5 of 6 shifts improve by 29–41%** in ensemble test MSE. **Shift 30 is the exception (+11%):** two of its five seeds
  (43, 45) generalise clearly worse on the withheld days 180–270. On that split the test loss flattens from ~epoch 1600
  while the training loss keeps falling.
* **Fitted dust bands** stay consistent across the 30 networks: inclinations ~1°, band 2 width 1.6°. The nodes move to
  26–29° and bands 1 and 3 come out narrower and closer than at 500 epochs.
* **Next:** round 35 (started 23:10) tests a cos×exp learning-rate schedule against one-cycle on shifts 0 and 30.
  Remedies for the shift-30 overfitting (a validation month with best-epoch selection, or weight decay) are for later.
""",

"code" => raw"""
using CairoMakie
const R = joinpath(@__DIR__, "..")
struct PNGFile; path::String; end; Base.show(io::IO, ::MIME"image/png", p::PNGFile) = write(io, read(p.path))   # raw PNG bytes: renders in any Jupyter front end
showpng(f) = PNGFile(joinpath(R, "figures", f))
""",

"markdown" => raw"""
## 1. Every shift: ensemble test MSE on the withheld months, (MJy/sr)²

| shift (days) | 500 epochs | 2000 epochs | change |
|---|---|---|---|
| 0 (poster split) | 2.44e-8 | **1.47e-8** | −40% |
| 10 | 2.37e-8 | **1.48e-8** | −38% |
| 20 | 2.40e-8 | **1.54e-8** | −36% |
| 30 | **2.53e-8** | 2.80e-8 | +11% |
| 40 | 2.43e-8 | **1.73e-8** | −29% |
| 50 | 2.37e-8 | **1.43e-8** | −40% |

Shifts 40 and 50: every seed is better at 2000 epochs (shift 50: 1.6–1.8e-8 vs 2.7–3.1e-8 per network).
Numbers from `sweeps/report34.jl` and `sweeps/diag34_shift30.jl <shift>`.
""",

"markdown" => raw"""
## 2. Full sky map (all 6 shifts)
Each pointing is predicted by the versions that withheld it (between-month windows), in 3.5° patches. Difference panel:
blue = 2000 epochs better. The ecliptic stripe is gone, and most of the rest of the sky improves slightly.

| 6 shifts | median | p95 | ecliptic (<2°) | above 60° |
|---|---|---|---|---|
| 500 epochs (rounds 31–32) | 0.0157% | 0.049% | 0.0285% | 0.0134% |
| **2000 epochs (round 34)** | **0.0130%** | **0.035%** | **0.0162%** | **0.0120%** |
""",

"code" => raw"""
showpng("10272026_r34_sky_6shifts.png")
""",

"markdown" => raw"""
## 3. Loss curves
Poster split, 5 seeds averaged, on the full log range (MSE 1 → 1e-9). The withheld-month loss keeps falling to
epoch 2000.
""",

"code" => raw"""
showpng("10272026_r34_loss.png")
""",

"markdown" => raw"""
## 4. The exception: shift 30
Per-seed withheld-month loss, epoch-averaged, shifts 20 and 30 (dashed = training months; white dotted = the 500-epoch
final test loss). On shift 20 every seed keeps improving to the end. On shift 30 seeds 43 and 45 sit well above the rest
from epoch ~1000, and all five flatten from ~1600 while the training loss keeps falling. That is mild overfitting, not
a sharp turn upward. The extra error is concentrated in the withheld windows at days 180–270 (`sweeps/diag34b.jl`).

| shift 30, test MSE (×10⁻⁸) | s42 | s43 | s44 | s45 | s46 |
|---|---|---|---|---|---|
| 500 epochs | 2.8 | 3.2 | 3.0 | 3.2 | 3.3 |
| 2000 epochs | 2.7 | **4.2** | 2.9 | **4.7** | 3.0 |
""",

"code" => raw"""
showpng("10272026_r34_seed_curves.png")
""",

"markdown" => raw"""
## 5. Fitted dust-band parameters, 30 networks (`BAND_FAM=z500h_bandplx2k_shift julia --project=. sweeps/band_params_r32.jl`)
Mean ± spread over the 30 networks; nodes are circular means.

| band | epochs | i | Ω (node) | δζ (width) | v (shape) | R (effective distance) |
|---|---|---|---|---|---|---|
| 1 | 500 | 1.08 ± 0.18° | 22.6 ± 5.4° | 3.52 ± 0.29° | 0.21 | 1.76 ± 0.17 AU |
| 1 | 2000 | 1.11 ± 0.15° | 29.4 ± 4.3° | 3.00 ± 0.37° | 0.06 | 1.56 ± 0.13 AU |
| 2 | 500 | 0.91 ± 0.11° | 17.8 ± 8.6° | 1.69 ± 0.21° | 1.06 | 1.42 ± 0.15 AU |
| 2 | 2000 | 0.98 ± 0.12° | 25.6 ± 7.0° | 1.62 ± 0.36° | 0.50 | 1.41 ± 0.11 AU |
| 3 | 500 | 1.13 ± 0.29° | 19.2 ± 7.8° | 5.57 ± 0.43° | 0.06 | 2.04 ± 0.29 AU |
| 3 | 2000 | 1.13 ± 0.19° | 28.9 ± 5.1° | 4.64 ± 0.61° | 0.02 | 1.72 ± 0.25 AU |

The inclinations and band 2's width and distance barely move. The nodes shift by ~7–10° with a smaller spread, and
bands 1 and 3 become narrower and closer. As before, R is an effective distance: ZodiPy's bands have inner cutoffs and
a ~1/R falloff, which a single R cannot represent exactly.
""",

"markdown" => raw"""
## 6. Next
* **Round 35** (running since 23:10 Tue, ~5.5 h): cos×exp schedule with a 5% warm-up (peak 2e-3, the same average
  learning rate as one-cycle 1e-3), parallax band layer, 500 epochs, shifts 0 and 30 × 5 seeds (`sweeps/configs_v35.jl`).
* Later: a fix for the shift-30 overfitting (validation month + best epoch, or weight decay); a per-band radial profile
  instead of one effective R; the move to the NMSU HPC cluster (Slurm) once access is granted.
""",
]
