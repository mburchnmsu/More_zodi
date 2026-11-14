# Cell contents for 11142026.ipynb — the Week 14 tasks (Nov 13–14): grey bands, the MJD 61,200 "jump", SPHEREx's zodi
# column vs Kelsall, the behind − ahead leak, and task 7 (the emulator architecture trained on real tall-table pixels,
# 31 runs on Colibrí, jobs 211 and 222). Slide text: docs/slides_week14.md; choices: docs/choices_log.md.
#     julia --project=. sweeps/build_nb.jl sweeps/week14_text.jl 11142026.ipynb
CELLS = Pair{String,String}[

"markdown" => raw"""
# Week 14 tasks (Nov 13–14, 2026)

### Summary
* **Grey bands** in the Earth-frame maps are sky SPHEREx never sees (it points ~90–115° from the Sun).
* **The "jump" near MJD 61,200** is not a release step: the tall table has none. From Apr 29 to Jun 18, 2026 the north
  ecliptic pole was visited 3× as often, many times at the noisy 4.98–5.01 μm edge.
* **SPHEREx's zodi column is Kelsall × 1.165**, with only 1–2% geometric terms; the biggest remaining term is wavelength
  (−1.4% per 0.05 μm).
* **The Week 13 behind − ahead deficit (−5% near the ecliptic) is mostly Kelsall's scale error leaking in**, because
  "behind" is seen at larger elongation. After scaling, −0.7 ± 0.4% remains (−2.6% in a joint fit): a v_e term of 1–3%
  may remain.
* **Training on real data (task 7):** 192 patches are enough to learn Kelsall (0.026% on held-out patches), but on
  SPHEREx's zodi the network ties a single scale factor (1.02% vs 0.96%), and on the measured sky it overfits
  (3.2% vs 1.9% for SPHEREx zodi + constant, off the plane).
""",

"code" => raw"""
const R = joinpath(@__DIR__, "..")
struct PNGFile; path::String; end; Base.show(io::IO, ::MIME"image/png", p::PNGFile) = write(io, read(p.path))   # raw PNG bytes: renders in any Jupyter front end
showpng(f) = PNGFile(joinpath(R, "figures", f))
""",

"markdown" => raw"""
## 1. What are the grey bands?
Our model's error on withheld months in the frame of Earth's motion (centre = behind Earth), labelled. A and B are the
Sun-avoidance and anti-Sun limits, C is outside the ellipse, D is cells with fewer than 30 exposures.
""",

"code" => raw"""
showpng("11132026_earth2d_gray_annot.png")
""",

"markdown" => raw"""
## 2. The MJD 61,200 "jump"
Measured − SPHEREx zodi at the north ecliptic pole against time (orange: 4.98–5.01 μm), and exposures per 5 days.
The level stays at ~0.026 MJy/sr; the scatter doubles at the detector edge (0.010 vs 0.0055 MJy/sr).
""",

"code" => raw"""
showpng("11132026_nep_burst.png")
""",

"markdown" => raw"""
No release step in the tall table: SPHEREx zodi / ZodiPy against time, coloured by release.
""",

"code" => raw"""
showpng("11132026_release_jump_L6_grid2.png")
""",

"markdown" => raw"""
## 3. What model is SPHEREx's zodi column?
SPHEREx zodi / ZodiPy for 8938 exposures in 192 patches. Median 1.165 (16–84%: 1.147–1.186). A regression on wavelength,
elongation, |β|, side of Earth and season leaves 1.03% of the 1.69% rms.
""",

"code" => raw"""
showpng("11132026_spherex_vs_kelsall.png")
""",

"markdown" => raw"""
## 4. The behind − ahead leak
Per patch, behind − ahead in the median-subtracted residual, before and after scaling our model by 1.181, and the
elongations at which each side is seen (109° behind vs 93° ahead near the ecliptic).

| Behind − ahead (|β| < 30°, 74 patches) | As in Week 13 | Scale fixed first | Joint fit |
|---|---|---|---|
| Measured − our model | −5.0 ± 0.3% | −0.7 ± 0.4% | −2.6 ± 0.2% |
| Measured − SPHEREx zodi | −0.1 ± 0.3% | — | −1.4 ± 0.2% |
""",

"code" => raw"""
showpng("11132026_residual_leak.png")
""",

"markdown" => raw"""
## 5. The emulator trained on real data (task 7)
**Training set (7a):** Discovery extracted per-exposure medians in level-9 sub-pixels of the 192 grid-2 patches at
4.9–5.0 μm (`realdata/talltable_extract.py`, `ttx_merge.py`): 197,523 rows, 8938 exposures. ZodiPy was evaluated at
every row (`realdata/ttx_zodipy.py`, times sorted, see the choices log for the ZodiPy 1.1.5 batching bug), and our
inputs taken from the nearest simulated exposure (median 1 min apart; `realdata/ttx_ours.jl`). Our emulator matches
ZodiPy on these rows to 0.016% (median), 0.055% (p99).

**Runs (7b):** `sweeps/train_real.jl` with the best simulation architecture (parallax band layer, sun-season inputs,
cos×exp schedule, 1000 epochs). Targets at 5.0 μm via Kelsall's colour: `zodi5` = SPHEREx zodi, `flux5` = measured sky,
`kel5` = ZodiPy (control). Fold f holds out patches with index % 5 == f. 5 seeds on fold 0 (all three targets), 2 seeds
on folds 1–4 (zodi5, flux5): 31 runs on Colibrí (jobs 211, 222; ~23 min, 5 GB each).

The report below averages the seeds and compares with baselines fit on the training patches only
(`sweeps/report_real.jl`; needs the git-ignored `data/tt_train/` tables and `sweeps/results_real/` predictions).
""",

"code" => raw"""
include(joinpath(R, "sweeps", "report_real.jl"))
""",

"markdown" => raw"""
| Trained on | Network, median \|Δ\| (rms) | Best simple baseline, median \|Δ\| (rms) |
|---|---|---|
| ZodiPy (Kelsall), fold 0 | 0.026% (0.069%) | our emulator: 0.011% (0.017%) |
| SPHEREx zodi, all folds | 1.02% (2.03%) | Kelsall × a: 0.96% (1.45%) |
| Measured sky, \|b\| > 15°, all folds | 3.2% (13.8%) | SPHEREx zodi + b: 1.9% (4.1%) |

* The control shows the patch coverage is enough: the network learns Kelsall on unseen patches to 0.026%.
* On SPHEREx's zodi the network ties a single scale factor. It has no wavelength input, and SPHEREx zodi / Kelsall
  changes by −1.4% per 0.05 μm; a wavelength-only linear fit alone would take the spread from 0.96% to 0.65%.
* On the measured sky it fits training patches to 1.2% but held-out ones to 4%: it learns the stars and residual sky of
  the training patches (no masking yet).
""",

"code" => raw"""
showpng("11142026_real_maps.png")
""",

"markdown" => raw"""
* Left vs middle: the network removes the smooth ecliptic pattern of Kelsall × 1.164 but adds 1–3% misses in single
  patches; per-patch medians tie (0.43% vs 0.44%).
* Right: the measured-sky misses are scattered patch by patch (±10% scale), not tied to geometry.

### Next (needs approval)
Add wavelength as an input (or train in narrower wavelength bins) and rerun the zodi5 cross-validation.
""",

]
