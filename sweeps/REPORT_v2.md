# Round 2 — validation period, feature/regularization tests, all-sky test (2026-10-07)

Recipe throughout: 64-64-32-16 gelu MLP, batch 512, one-cycle LR (peak 1e-3), 100 epochs, 5 seeds averaged.
38 runs. Code: `sweeps/mb_train.jl` (now with `val_days`, `weight_decay`), `sweeps/extra_features.jl`,
`sweeps/configs_v2.jl`, `sweeps/analyze_v2.jl`, `sweeps/allsky.jl`. Tables: `results/summary_v2.txt`.

## 1. Validation protocol
Fit on days 0–100, **select on days 100–111.4 (validation)**, report days 111.4–139.7 (test, untouched).
Checked: fit/val/test disjoint, cover all 423,607 exposures, strictly ordered in time, normalization from fit rows only.

| config (5-seed ensemble) | val MSE | test MSE | late-test bias (MJy/sr) |
|---|---|---|---|
| + n·δ̂ | **2.37e-5** | 2.70e-4 | −0.016 |
| − n·J | 2.97e-5 | 6.76e-4 | −0.019 |
| baseline n·* | 3.10e-5 | **2.67e-4** | −0.014 |
| weight decay 1e-6 | 3.25e-5 | 2.95e-4 | −0.016 |
| weight decay 1e-5 | 6.39e-5 | 5.52e-4 | −0.028 |
| **30-day alternating blocks** (diagnostic) | — | **1.05e-5** | **+0.000** |

- **Validation ranks models like the test, with one exception:** dropping n·J looks fine 0–11 days out but is 2.5× worse
  11–40 days out. A nearby validation period can't see damage that only appears further from the training data.
- **Training 11 days less raises test error ~3×** (2.7e-4 vs ~0.9e-4) — extrapolation error grows fast with distance in time.
- **Weight decay:** 1e-6 no effect, 1e-5 underfits. Not useful here.
- **Dropping n·J hurts** (test 2.5× worse) — the "Jupiter null" is *not* null for extrapolation. Likely n·J acts as a slowly
  varying inertial direction the net leans on; worth a dedicated look.

## 2. The drift is an unseen-season effect, not missing physics
On the 30-day alternating-block split (test periods sit *between* training periods) the same recipe gets
**test MSE 1.05e-5 with zero bias** — 25× better than the chronological split. The steady negative drift only
appears when predicting *beyond* the training period. Expect that whenever a model is applied to a time of year
it never saw — a key point for real data.

## 3. Final models (refit on all of days 0–111.4) and the all-sky test (Rung 3, epoch TINDX = 13170)

| | baseline n·* | + n·δ̂ |
|---|---|---|
| test MSE, 5-seed ensemble | 9.4e-5 (rms 0.0097, 2.05%) | 7.6e-5 (rms 0.0087, 1.85%) |
| test MSE, mean of single seeds | **1.4e-4** | 3.1e-4 (seed 45: 8.9e-4) |
| **sky in training domain** | **33.1%** | **5.6%** |
| in-domain rms / median frac. error | 0.0067 MJy/sr / **0.54%** | 0.0036 / 0.12% (tiny region) |
| out-of-domain median frac. error | **7.8%** | 32% |
| in-domain residual corr. with Kelsall components | **|r| ≤ 0.03** for all six | up to 0.16 |
| previous best (brief) in-domain rms | 0.233 MJy/sr | |

**n·δ̂ is a survey-pointing feature, not a zodi feature.** SPHEREx always points ≥139° from the Earth's centre, so
n·δ̂ only spans 0.76–1.00 in training. Adding it shrinks the valid sky from 33% to 6% and makes the model
worse almost everywhere off the survey track, even though it squeezes the chronological test slightly. Physically
it should be a null for Kelsall (as the onboarding predicts). **Recommendation: keep baseline n·\*** for the emulator;
n·δ̂ belongs in the real-data model (Earthshine/stray light), where it is genuine physics.

**Baseline all-sky:** in-domain rms 0.0067 MJy/sr (**35× better than the previous 0.233**), median 0.54% fractional
error, residuals uncorrelated with every Kelsall component. Out of domain (toward the Sun) it still fails
(rms ~80 MJy/sr) — expected for an emulator that never saw those geometries. **Ensemble spread is not a reliable
out-of-domain alarm**: near the Sun all seeds agree on the same wrong answer. Use the feature-range mask instead.

## Recommended model
Baseline `n·*`, 64-64-32-16, one-cycle 1e-3, 100 epochs, 5-seed ensemble, trained on days 0–111.4.
Test MSE 9.4e-5 (2.05%); all-sky in-domain 0.54% median fractional error.

## Suggested next steps
1. **Log-target / positive output** to push fractional error below 0.5% and stabilize the faint poles.
2. **n·J follow-up:** why does removing the Jupiter "null" hurt extrapolation? (Try replacing it with a fixed inertial
   axis, or check what n·J correlates with over the mission.)
3. **More training seasons** are the real fix for the drift: the block-split result says the model interpolates well;
   real data covering the full year (or multiple years) will remove most of the chronological penalty.
4. Carry the verification + all-sky cells forward unchanged to real data; add n·δ̂ / Moon features there.
