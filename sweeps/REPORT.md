# Overnight sweep — mini-batch training, LR schedules, architectures (2026-10-06/07)

**Task:** lowest test MSE on the **80/20 chronological split** (train days 0–111.4, test days 111.4–139.7),
`n·*` features only (8 look-direction dot products). 49 training runs, ~6.5 h on 2 parallel CPU lanes.
Code: `sweeps/mb_train.jl`, configs: `sweeps/configs.jl`, raw results: `sweeps/results/*.jls`,
full table: `sweeps/results/summary.txt`.

## Headline

| model | test MSE | test rms (MJy/sr) | frac. error | wall time |
|---|---|---|---|---|
| full-batch 64-64-32-16, 2000 ep (yesterday) | 9.3e-4 | 0.030 | 6.5% | ~2 h |
| mini-batch 64-64-32-16, one-cycle 1e-3, 100 ep (7-seed mean) | 1.55e-4 | 0.012 | 2.6% | 6 min |
| **ensemble of 7 seeds of the above** | **9.5e-5** | **0.0097** | **2.1%** | 7 × 6 min |
| ensemble of 5 seeds (the notebook recipe) | 9.4e-5 | 0.0097 | 2.0% | 5 × 6 min |

**Recommended recipe:** 64-64-32-16 gelu MLP, batch 512, Adam, one-cycle LR (peak 1e-3), 100 epochs,
average 5+ seeds. ~10× lower test MSE than full-batch, in a fraction of the time.

## Findings

1. **Mini-batching is the big win.** Batch 512 reaches the full-batch 2-hour result in ~2 epochs (~5 s).
2. **The bottleneck is now extrapolation, not fitting.** Train MSE reaches 1e-6–1e-7, test plateaus at
   ~1–2e-4 by epoch ~20. Extra training/capacity improves the fit to days 0–111 without improving days 111–140.
3. **Seed noise ≈ 2× (up to 13× for big nets) — larger than schedule differences.** Never rank configs from one seed.
4. **Schedules (64-64-32-16, 3 seeds each, test MSE mean):** linear 1e-3 → 1.4e-4, one-cycle 1e-3 → 1.6e-4,
   cos×exp 3e-3 → 2.0e-4. Statistically indistinguishable. **Peak LR 1e-2 is unsafe**: one-cycle 1e-2 → 1.4e-3,
   cos×exp 1e-2 had one seed at 6.0e-3 (56× worse).
5. **Bigger is worse here.** Test MSE (seed mean): 32-16 → 6.9e-4 (underfits), **64-64-32-16 → 1.6e-4 (best)**,
   128-128-64-32 → 2.9e-4, 128×4-64-32 → 2.8e-4, 256-256-128-64 → 8.8e-4. Bigger nets fit training better
   but extrapolate worse and less consistently.
6. **ResMLPs:** best single run of the night (w128×4, seed 42: 6.8e-5) but its other seed was 8.7e-4.
   w64×3: 4-seed mean 4.1e-4, yet its 4-seed **ensemble 1.05e-4** — residual nets are high-variance;
   ensembling rescues them but doesn't beat the plain 64-64-32-16 ensemble. w256×4: 1.6e-3.
7. **Ensembling helps every config** (typ. 30–75% lower MSE than the seed mean) because seeds extrapolate differently.
8. **What's left:** test residuals drift steadily negative after the boundary (≈ −0.02 MJy/sr by day 140) and are
   largest near the ecliptic poles and at elongation 85–90°. The drift is shared by all seeds (ensembling doesn't
   remove it) → it's missing information (orbital phase vs. the tilted cloud), not noise.

## Caveat

Configs were compared on the test set itself (there is no separate validation period), so the very best
numbers are mildly optimistic. The recommendation relies on seed means and ensembles, not on the single luckiest run.

## Suggested next steps

1. Carve a **validation period** (e.g. days 100–111) out of training for model selection / early stopping.
2. **Weight decay / smaller LR late** — the train/test gap is now ~40×; mild regularization may help extrapolation.
3. Attack the drift with **non-clock Earth-anchored features** (`n·δ`, onboarding Earth-centric section) or by testing on
   splits where orbital phase is covered (30-day blocks), to separate "missing physics" from "unseen season".
4. **Positive output / log target** (onboarding stretch goal 4–5) to target fractional error at the poles.
