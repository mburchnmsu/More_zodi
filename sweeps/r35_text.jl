# Cell contents for 10282026.ipynb — Oct 27–28: round 35, cos×exp learning-rate schedule vs one-cycle; the mentor's
# requests (interpolation vs extrapolation sky maps, 2-D trailing-cloud residual map; sweeps/mentor1028.jl).
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
struct PNGFile; path::String; end; Base.show(io::IO, ::MIME"image/png", p::PNGFile) = write(io, read(p.path))   # raw PNG bytes: renders in any Jupyter front end
showpng(f) = PNGFile(joinpath(R, "figures", f))
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

"markdown" => raw"""
# Mentor's requests (Oct 28 afternoon)
Both use the best model (round 34: parallax band layer, 2000 epochs, 6 shifts × 5 seeds) and only saved runs, no new
training. Script: `sweeps/mentor1028.jl`.

## 4. Sky map: interpolation only vs interpolation + extrapolation
In the month-on/month-off splits, a withheld month with training months on both sides tests **interpolation**. The
first or last withheld window of a split has training data on one side only, so it tests **extrapolation** in time.
Our usual sky maps already use the interpolation windows only (`is_interior`).

| windows used | exposures | median | p95 | within 2° of the ecliptic | above 60° |
|---|---|---|---|---|---|
| interpolation only (usual map) | 98% | 0.0130% | 0.035% | 0.0162% | 0.0120% |
| interpolation + extrapolation | 100% | 0.0132% | 0.035% | 0.0166% | 0.0122% |
| extrapolation only | 10% | 0.0168% | 0.043% | 0.0226% | 0.0153% |

* Adding the extrapolation windows barely changes the map: they hold only 10% of the withheld exposures, and those
  exposures are mostly also covered by interpolation windows from other splits.
* On their own, the extrapolation windows are about **30% worse** (median 0.0168% vs 0.0130%). They come from different
  parts of the sky (the first and last ~30 days of the data), so this comparison is not exactly like for like.
* These windows extrapolate only 10–30 days past the training data. Longer extrapolation (predicting a whole future
  period) would need its own training run, like the Oct 14 test.
""",

"code" => raw"""
showpng("10282026_r34_interp_extrap_sky.png")
""",

"markdown" => raw"""
## 5. The Earth-trailing cloud on the full 0–360° sky
The frame moves with Earth. Longitude is measured in the ecliptic plane from Earth's direction of motion: 0° = ahead,
90° = the Sun, 180° = behind Earth (where Kelsall's trailing cloud sits), 270° = away from the Sun. Latitude is
ecliptic latitude. Bins are 3° × 3°; colours are means over the withheld (interpolation) exposures.
SPHEREx always looks about 90° from the Sun, so it only sees near 0° and 180° longitude (and near the poles). The grey
areas are never observed, so 38% of the frame is covered.

**Do we see residuals from the trailing cloud? No.**
* Kelsall's cloud is up to ~8% of the light near longitude 180–210°, latitude 0 (top left). Missing just 1% of it would
  leave residuals of about −0.07% there (top right).
* Our mean residuals (bottom left) are a few thousandths of a percent everywhere, with no feature where the cloud is.
* Fitting residual = a × (cloud share) + b gives a = −0.0001 ± 0.0001 near the plane (|β| < 15°) and 0.0000 ± 0.0002
  over the whole sky. **The network has learned the cloud to about 0.01% of its own brightness.**
* Behind Earth (longitude 150–210°, |β| < 15°; the cloud is 6.9% of the light) the mean residual is −0.0006%. Ahead
  (330–30°; 1.0% of the light) it is +0.0005%. That difference is ~100× smaller than a 1%-missing cloud would give.
* The bottom-right panel divides by the standard error. That error assumes every exposure is independent, but nearby
  exposures share the same sky and time, so it overstates how significant the stripes are. The stripes follow the scan
  pattern, not the cloud. The largest real residual feature is near longitude 330°, latitude +30° (about +0.02%),
  well away from the cloud.
""",

"code" => raw"""
showpng("10282026_r34_trailing_2d.png")
""",

"markdown" => raw"""
## 6. To keep in mind: how precise does the emulator need to be?
Our ~0.013% is the **emulation error**: how well the network copies the Kelsall model. Kelsall's own residuals are
**model vs the real DIRBE sky**, which is a different comparison (numbers to come from the paper; the user is reading
it). The precision target should come from SPHEREx: how well zodiacal light has to be subtracted compared with the noise
in one image. The plan is to put all three on one plot once the numbers are in.
""",
]
