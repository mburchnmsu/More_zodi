# Cell contents for 10072026.ipynb ("markdown" or "code" => source). Edited by hand; built by build_10072026.jl.
CELLS = Pair{String,String}[

"markdown" => raw"""
# SPHEREx zodiacal-light emulator — progress summary (Oct 6–7, 2026)

**Goal.** Train a fast, differentiable neural-network emulator of the Kelsall (1998) 5 μm zodiacal emission (via ZodiPy)
as a function of observing geometry, and validate it carefully before moving to real SPHEREx data.

**Data.** 423,607 SPHEREx boresight exposures spanning **139.7 days** (rows are *not* in time order), with JPL ephemerides
and the Kelsall emission along each line of sight (0.32–1.09 MJy/sr). Plus one all-sky HEALPix map (nside 256) at a
single epoch for an out-of-distribution test.

**How to run this notebook.** Top to bottom, ~5–8 minutes. Heavy training was done in `sweeps/` (≈150 runs);
this notebook **loads the saved results** from `sweeps/results/` and rebuilds every table and figure. The appendix
has an optional `RETRAIN = true` switch that retrains the recommended model from scratch (~30 min).

### Headline results (80/20 chronological split: train days 0–111.4, test days 111.4–139.7)

| stage | model | test MSE (MJy/sr)² | test rms | median \|frac. error\| |
|---|---|---|---|---|
| day 1, start | all 36 dot products, full-batch 36→32→16→1 | 3.1e-2 (≈ predicting the mean) | 0.177 | — |
| day 1 | look-direction `n·*` only, full-batch 64-64-32-16 (2000 epochs, ~2 h) | 9.3e-4 | 0.030 | — |
| night 1 | mini-batch 64-64-32-16, one-cycle LR (100 epochs, ~6 min), single seed (mean of 5) | 1.4e-4 | 0.012 | — |
| **final** | **same, 5-seed ensemble** | **9.4e-5** | **0.0097** | **0.54%** |

* **All-sky (Rung 3), inside the training domain:** rms **0.0067 MJy/sr** (previous best 0.233), median error **0.54%**,
  residuals uncorrelated with every Kelsall component.
* **Interpolation (random / 7-day / 30-day splits):** median error **~0.1%**, 100–170× better than a quadratic fit.

### Five take-aways
1. **Features must not act as clocks.** Orbit-only dot products change monotonically with time and break any
   chronological test; the 8 look-direction features (`n·*`) generalize.
2. **Mini-batching + one-cycle LR** replaces 2-hour full-batch runs with 6-minute runs that are 6× better.
3. **Seed noise is large** (~2×, up to 13× for big nets) — always compare seed means, and **average seeds** (ensemble).
4. **The remaining error is extrapolation in time:** flat to ~5 days beyond the training data, then rising steeply.
   With training data on both sides the model is ~0.1% accurate.
5. **The emulator works in-domain but not toward the Sun**, and seed spread does not warn about it — a feature-range mask does.
""",

"code" => raw"""
# Setup: environment, data, features, splits (zodi_setup.jl), then the sweep code:
#   mb_train.jl        — mini-batch training (schedules, validation period, target transforms)
#   extra_features.jl  — n·δ̂ feature + named feature sets
#   nb_verify_fns.jl   — verification checks (split integrity, metrics, residual plots)
#   summary_helpers.jl — loads saved results → tables (DataFrames) and figures
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl", "nb_verify_fns.jl", "summary_helpers.jl")
    include(joinpath(@__DIR__, "..", "sweeps", f))
end
println("\nloaded; saved results live in ", RES)
""",

"markdown" => raw"""
## 1. Data and sky coverage

* Mission span **139.7 days** (not ~150): rows are unsorted and `times[1]` is not the earliest exposure, so all
  chronological splits sort by time first.
* Solar elongation of the boresight spans **85.2°–129.7°** — below the nominal 91° avoidance limit (a sharp floor at 85.2°;
  likely the restriction in the simulated pointing is looser than published).
* The maps below bin exposures into HEALPix pixels (nside 16 ≈ one SPHEREx footprint): ~82% of the sky is observed at
  least once, two large regions never are, and much of the sky is seen at only one Sun angle.
""",

"code" => raw"""
include(joinpath(@__DIR__, "..", "elongation_map.jl"))   # → Mollweide maps: exposure count, mean elongation, elongation range
""",

"markdown" => raw"""
## 2. Day 1 — why the first network failed on the 80/20 chronological split

With all 36 dot products, a 36→32→16→1 network was **no better than predicting the training mean** on the last 20% of
the mission. Reason: ~20 "orbit-only" features (`S·x`, `E·x`, `z·E`, `J·J`, …) change monotonically with time, act as
a clock, and are **outside their training range for essentially every test exposure**. The look-direction features
(`n·*`) stay in range. Training on `n·*` only fixed it; adding `S·S` (heliocentric distance², also a clock) hurt.
""",

"code" => raw"""
display(first(feature_shift_table(), 24))   # fraction of TEST exposures outside the TRAINING range, per feature
""",

"code" => raw"""
fullbatch_fig()   # full-batch training (day 1): all-36 vs n·* vs n·*+S·S, small and larger nets
""",

"markdown" => raw"""
## 3. Mini-batch training and learning-rate schedules

Mini-batching (batch 512) reached the 2-hour full-batch result in ~2 epochs (seconds). Every run then fits the training
period to ~1e-6 while the test plateaus at ~1–2e-4 by epoch ~20 → **the limit is extrapolation, not optimization.**
Three seeds per schedule show **seed-to-seed scatter (~2×) is larger than the differences between schedules**;
peak learning rates of 1e-2 are unstable (one seed 56× worse).
""",

"code" => raw"""
display(schedule_table())
schedule_fig()
""",

"markdown" => raw"""
## 4. Architecture scan

Bigger networks fit the training period better but **extrapolate worse and less consistently**; 64-64-32-16 (7.4k
parameters) is the sweet spot. Residual MLPs are extremely seed-sensitive (best single run of the sweep *and* some of the
worst). **Averaging seeds (★) helps every architecture**, because each seed extrapolates differently.
""",

"code" => raw"""
display(arch_table())
arch_fig()
""",

"markdown" => raw"""
## 5. Validation period and feature / regularization tests

Model selection now uses a **validation period**: fit on days 0–100, select on 100–111.4, report the untouched test
period 111.4–139.7. Validation ranks models like the test, except it cannot see damage that only appears further out
(dropping `n·J`). Weight decay doesn't help. `n·δ̂` (Earth-centric LEO direction) wins validation narrowly but is
rejected in §8 (it shrinks the valid sky from 33% to 6%).
""",

"code" => raw"""
display(round2_table())
val_vs_test_fig()
""",

"markdown" => raw"""
## 6. Generalization ladder — the same recipe on every split

The network **interpolates superbly** (0.1% median error on random / 7-day / 30-day splits — 100–170× better than a
quadratic fit) and **degrades smoothly when extrapolating in time**. The second figure shows one universal curve:
error is flat out to ~5 days from the nearest training exposure, then rises steeply (×10 by ~15 days, ×1000 by ~90 days).
Polynomial baselines blow up when extrapolating (lin+quad MSE 3×10³ on chrono 25/75).
""",

"code" => raw"""
L = ladder_data()
display(ladder_table(L))
ladder_fig(L)
""",

"code" => raw"""
gap_fig(L)
""",

"markdown" => raw"""
## 7. Output transforms — log target, positive output, relative-error loss

Four ways to produce the output, same recipe otherwise:
* **linear** — predict y, MSE loss (baseline);
* **log target** — predict log y (MSE on log y ≈ squared *fractional* error; exp(·) is always positive);
* **softplus output** — predict y through a softplus layer (always positive);
* **relative-error loss** — predict y, loss mean(((ŷ − y)/y)²).

**Result.** No variant — not even the plain linear output — ever predicts a negative value, so positivity constraints
are not needed for this emulator. The **log target wins on validation and on all-sky fractional error**, and removes the
late-test negative drift, but it is **1.4× worse on the chronological test and much more seed-sensitive**. That is the
same pattern seen when dropping `n·J`: a validation period 0–11 days out is too close to see damage that appears
further away. **Linear output stays the recommendation; the log target is the promising alternative**, especially for
fractional accuracy and behaviour toward the Sun.
""",

"code" => raw"""
display(target_table())       # 80/20 chronological; val = 3 seeds fit on days 0–100, test = 5 seeds fit on days 0–111.4
""",

"code" => raw"""
display(target_allsky_table())   # all-sky behaviour of each output choice (5-seed ensembles) — ~2 min
""",

"code" => raw"""
# residuals of each output choice (5-seed ensembles): note the linear model's late-test negative drift vs the
# more symmetric (but noisier) log-target / relative-error residuals
target_ens = Dict{String, Any}(lbl => as_ensemble(target_full_runs(t), lbl) for (lbl, t) in TARGETS)
verify_residuals(target_ens, first.(TARGETS); tag="_targets")
""",

"markdown" => raw"""
## 8. Final recommended model — verification

**Recipe:** the 8 look-direction features `n·*` (robustly standardized with training-row medians/IQRs) →
64 → 64 → 32 → 16 → 1 gelu MLP; batch 512; Adam with a one-cycle learning rate (peak 1e-3); 100 epochs; linear output,
MSE loss; **5 seeds (42–46) trained on days 0–111.4, predictions averaged.** Total training ≈ 30 min on a laptop CPU.

Checks: fit/test split is a clean chronological partition, normalization constants come from training rows only, stored
metrics match recomputed ones, and no negative predictions. Residual plots show the ensemble vs its best and worst seed.
""",

"code" => raw"""
FINAL_TARGET = :linear                                          # output choice selected in §7
final_runs = target_full_runs(FINAL_TARGET)                     # 5 seeds, trained on days 0–111.4
fin = Dict{String, Any}("ensemble (5 seeds)" => as_ensemble(final_runs, "ensemble (5 seeds)"))
for r in final_runs; fin["seed $(r.seed)"] = r; end
seeds_sorted = sort([k for k in keys(fin) if startswith(k, "seed")], by = k -> fin[k].te_hist[end])
verify_integrity(fin, ["ensemble (5 seeds)"])
verify_metrics(fin, ["ensemble (5 seeds)", seeds_sorted...]; tag="_summary")
""",

"code" => raw"""
verify_residuals(fin, ["ensemble (5 seeds)", first(seeds_sorted), last(seeds_sorted)]; tag="_summary")
""",

"markdown" => raw"""
## 9. Rung 3 — all-sky out-of-distribution test

The full sky at one epoch, dominated by geometries SPHEREx never observes (e.g. toward the Sun). "In-domain" = pixels
whose features all lie inside their training range. Inside, the emulator matches Kelsall to ~0.5% with residuals
uncorrelated with every physical component; outside (toward the Sun) it fails, and **the seed spread does not warn
about it** — use the feature-range mask as the out-of-domain flag.
""",

"code" => raw"""
A = allsky_eval(final_runs; title="final model, 5-seed ensemble")
display(A.metrics); display(A.comps)
A.fig
""",

"markdown" => raw"""
## 10. Conclusions and next steps

**What works**
* A small (7.4k-parameter) MLP on 8 rotation-invariant look-direction features, trained with mini-batches and a one-cycle
  schedule and averaged over 5 seeds, emulates the Kelsall 5 μm sky to **~0.1% when interpolating**, **~0.5% at
  ~2 weeks beyond the training data**, and **~0.5% across the in-domain all-sky map**.
* The validation protocol, verification checks and all-sky test are reusable as-is for real data.

**What limits it**
* **Extrapolation in time.** The ladder shows a single error-vs-distance curve; the cure is training data that covers
  the period you predict (real data spanning the full year), not a bigger network.
* **Out-of-domain geometry** (toward the Sun) — an emulator can't know what it never saw; flag it with the feature-range mask.
* **Validation that sits too close to the training data** can miss problems that appear further out (`n·J`, log target).

**Open questions / next steps**
1. Why does removing the Jupiter "null" feature `n·J` hurt extrapolation? (Replace with a fixed inertial axis; check what it tracks.)
2. Log-target model: can a few more seeds or a mixed loss keep its fractional-accuracy gains without the seed sensitivity?
3. Earth-centric control from the onboarding (`S → E + δ`): confirm accuracy is unchanged before adding Earthshine/Moon features.
4. Real data: carry over the pipeline (validation period, ensembles, verification, feature-range mask); add `n·δ̂` and Moon
   features there, where they are genuine physics (Earthshine, stray light); train on the full year.
""",

"markdown" => raw"""
## Appendix — retrain the recommended model from scratch

Set `RETRAIN = true` to train the final recipe live (5 seeds × ~5–6 min on a laptop CPU) and compare it with the
saved runs. Training is deterministic for a given seed, so the numbers should match the saved ones.
""",

"code" => raw"""
RETRAIN = false
if RETRAIN
    live = [train_mb(FEATURE_SETS[:look_dir]; target=FINAL_TARGET, hidden=(64, 64, 32, 16), schedule=:onecycle,
                     lr_max=1e-3, epochs=100, batchsize=512, seed=s, label="live seed $s") for s in 42:46]
    for (a, b) in zip(live, final_runs)
        @printf("seed %d: live test MSE %.4e | saved %.4e\n", a.seed, a.te_hist[end], b.te_hist[end])
    end
    @printf("live 5-seed ensemble test MSE: %.4e\n", mse_on(ens_pred(live), live[1].te_idx))
else
    println("RETRAIN = false → using the saved runs in sweeps/results (set RETRAIN = true to retrain, ~30 min)")
end
""",
]
