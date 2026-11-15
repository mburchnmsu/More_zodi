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
* **Follow-ups (section 6):** with the pixel's wavelength as an input, the network reproduces SPHEREx's zodi to
  **0.20%** (3× better than the best wavelength correction). Star masking (dropping MP_SOURCE pixels) helps every model on
  the measured sky by 10–30%, but the network (2.3%) still trails SPHEREx zodi + constant (1.7%) off the plane.
* **Robust loss and clean rows (section 7):** with a relative Huber loss and only rows ≥ 50% unmasked, the network beats
  SPHEREx zodi + constant on the measured sky off the plane (median 1.20% vs 1.44%).
* **Flag census (section 8):** 41% of pixel samples are on catalogued sources, 3.7% carry other flags. Of the flagged
  objects, 60% are Gaia stars and 6% galaxies or quasars; 11% of exposures have a satellite streak; bright known
  asteroids are detected and flagged TRANSIENT/OUTLIER.
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
* Top row: the network without wavelength removes the smooth ecliptic pattern of Kelsall × 1.164 but adds 1–3% misses in
  single patches; per-patch medians tie (0.43% vs 0.44%).
* Bottom row: see section 6.

## 6. Wavelength as an input, and the star mask (Nov 14, later)
The user approved both. **Wavelength:** the row's wavelength (4.9–5.01 μm) is one more input, placed before the band
layer's 6 inputs (`zodi5L`; Colibrí job 232, 10 runs). **Star mask:** the tall table's default query already drops the
artifact flags; Discovery job 700324 re-extracted the medians without MP_SOURCE pixels (bit 21, pixels on catalog
sources; `TTX_MASK=1 realdata/talltable_extract.py`, `realdata/ttx_mask_merge.py`). 59% of pixels kept (73% at
|b| > 15°, 13% on the plane). Then `flux5m` and `flux5mL` (masked, without / with wavelength; job 243, 20 runs).
The report above already includes them (all 5 folds); summary:

| Target, held out | Network | Network + λ | Best baseline |
|---|---|---|---|
| SPHEREx zodi | 1.02% (2.03%) | **0.20% (0.28%)** | Kelsall × f(λ) 0.62% (0.95%) |
| Measured sky, \|b\| > 15°, unmasked | 3.2% (13.8%) | — | SPHEREx zodi + b 1.9% (4.1%) |
| Measured sky, \|b\| > 15°, star-masked | 3.0% (18.7%) | 2.3% (12.2%) | SPHEREx zodi + b 1.7% (3.2%) |

* **With the wavelength input the network reproduces SPHEREx's zodi to 0.20%**, 3× better than the best wavelength-only
  correction: it learns how SPHEREx's model differs from Kelsall with both wavelength and geometry. Per-patch medians
  0.04% (bottom-left map).
* **The star mask helps every model by 10–30%** on the measured sky, but the network still doesn't beat SPHEREx's zodi + a
  constant. Its misses are a few patches it gets badly wrong (8% of rows off by > 10%, vs 1.2% for the baseline), mostly
  near the Galactic plane. The same inputs work for SPHEREx's zodi, so the noisy target is the problem.

## 7. A robust loss and clean rows only (Nov 14, afternoon)
The user picked two fixes: a relative Huber loss (quadratic below 2% relative error, linear above; `target=:relhuber`
in `sweeps/mb_train.jl`) and training only on rows that keep ≥ 50% of their pixels after the star mask
(`train_real.jl ... huber 0.5`). Colibrí job 254: flux5mL with both, and with the cut only (MSE), 2 seeds × 5 folds each.

Star-masked measured sky, |b| > 15°, rows ≥ 50% clean (the same 141,387 rows for every line):

| Model | Median \|Δ\| | rms | Rows off by > 10% |
|---|---|---|---|
| Network + λ (all masked rows, MSE) | 2.16% | 8.85% | 6.5% |
| Network + λ, ≥ 50%-clean rows (MSE) | 1.29% | 4.46% | 2.2% |
| **Network + λ, ≥ 50%-clean rows, Huber** | **1.20%** | **2.77%** | **0.8%** |
| SPHEREx zodi + constant | 1.44% | 2.63% | — |

* **The network now predicts the measured sky better than SPHEREx's zodi model plus a constant** (median), with about
  the same rms. The clean-row cut gives most of the gain; the Huber loss removes most of the remaining outliers.
* The cut drops 27% of rows, mostly on the Galactic plane, so this holds for the sky away from the plane.
* Bottom-right map: the Huber + cut network (blank patches have no rows left).

## 8. What do the flags mark? (Nov 14, evening)
The user asked how many flags there are and how many flagged things are stars, galaxies, and satellites or asteroids.
Discovery jobs 700408–700415 read every pixel of the 192 patches at 4.9–5.1 μm with the flag filter removed
(`realdata/talltable_flags.py`): per-bit counts; static objects = level-15 cells (≈ one 6″ pixel) flagged SOURCE in at
least half of their exposures, joined into groups; single-exposure events = TRANSIENT/OUTLIER pixels plus unflagged
pixels > 5σ above their cell's median. On the ThinkPad (`realdata/flags_xmatch.py`), objects in every 8th patch off the
plane were matched within 6″ to Gaia DR3 and AllWISE, and known asteroids were looked up with IMCCE SkyBoT. Choices and
fixes: see the choices log (Nov 14, "Flag census").

**Pixel flags (682 million pixel samples):** 56.5% carry no flag; 40.9% are SOURCE (on a catalogued source); 3.65%
carry any other flag, mostly OUTLIER 1.5%, TRANSIENT 1.1%, SUR_ERROR 0.7%, NONFUNC 0.4%. Bit 28, which the FITS header
doesn't name, is set on 1.4%.

**Flagged static objects:** 184,370 groups (~1200 per patch, median 40″ across). Sample of 24,891 in 21 patches:

| Class | Objects | Share |
|---|---|---|
| Star (Gaia parallax or proper motion > 5σ) | 13,749 | 55.2% |
| Star (Gaia point source, no significant motion) | 1,205 | 4.8% |
| Galaxy (AllWISE extended or Gaia galaxy probability > 0.5) | 849 | 3.4% |
| Quasar / AGN (Gaia quasar probability > 0.5, or WISE W1 − W2 ≥ 0.8) | 589 | 2.4% |
| Seen only by WISE (likely faint galaxies or dusty stars) | 3,069 | 12.3% |
| No match within 6″ | 5,430 | 21.8% |

**Single-exposure events:** 11.5 million (1284 per patch-exposure):

| Class | Events | Share |
|---|---|---|
| Flagged by the pipeline (TRANSIENT/OUTLIER): cosmic rays, detector, and moving objects | 10,224,263 | 89.1% |
| On a static source (variable stars, residuals) | 1,246,663 | 10.9% |
| Satellite streak (≥ 8 pixels, axis ratio ≥ 5) | 2,109 | 0.02% |
| Unflagged point brightening (sky transient candidate) | 5,440 | 0.05% |

* **Stars dominate:** 60% of the flagged objects are Gaia stars, 6% are galaxies or quasars. The unmatched 22% are smaller
  (median 17 cells vs 40) and fainter than the matched ones: faint sources and fragments of bigger groups.
* **Satellites:** 1028 of 8939 patch-exposures (11%) have a streak; median 1.7′ long inside the patch, longest 64′. No
  meteors: SPHEREx orbits above the atmosphere.
* **Asteroids:** of the known asteroids SkyBoT puts inside 254 exposures near the ecliptic, the bright ones (V < 18) sit on
  an event 30 of 37 times, against 12 expected by chance (the same test 2′ away). The pipeline flags them TRANSIENT or
  OUTLIER, so they land in the first class above, not among the transient candidates (none of which is a known
  asteroid). Fainter asteroids (5514 with V > 18) are barely detected: 1759 on an event against 1608 by chance.
""",

"code" => raw"""
f = joinpath(R, "data", "tt_flags", "flag_census.txt")   # written by realdata/flags_xmatch.py (git-ignored data)
isfile(f) ? print(read(f, String)) : println("data/tt_flags/flag_census.txt not present (run realdata/flags_xmatch.py)")
""",

]
