# Cell contents for 10102026.ipynb — generalization tests for the mentor meeting.
CELLS = Pair{String,String}[

"markdown" => raw"""
# How far can the emulator be trusted? Gap length, unseen sky, and data volume (Oct 10, 2026)

Three new generalization tests, each comparing the **baseline** (`n·*` look-direction features) with the **season model**
(`n·*` + `sin/cos λ⊕`, Earth's orbital phase — the 10/09 result). Same recipe throughout: 64-64-32-16 MLP, one-cycle LR
(peak 1e-3), 3 seeds per configuration, predictions averaged into an ensemble (average first, then score).

1. **Block-length sweep** — alternate train/test windows of 1, 3, 7, 15, 30, 45 days. *How does accuracy depend on the
   time gap to the nearest training data?* (the onboarding's block-length question)
2. **Sky-patch holdouts** — remove every exposure within 12° of a direction, for the whole mission, and test only there.
   *Can the model predict sky it never saw?* Three patches: on the ecliptic (dust bands), mid-latitude, near the north pole.
3. **Learning curve** — train on 1%, 3%, 10%, 30%, 100% of the 30-day-block training data (same test blocks, same number of
   optimizer steps). *How much data does a given accuracy need?* — a planning number for real data.

Runs: `sweeps/configs_v8.jl` (69 new runs; identical earlier runs reused). This notebook loads the saved results and runs
top-to-bottom in a few minutes.

### Summary (3-seed ensembles; median |error| of the ensemble on the held-out data)
| test | baseline `n·*` | **season model** | what it shows |
|---|---|---|---|
| **Block length** 1 → 45 days (median gap 0.25 → 10 d) | 0.12% → 0.19% | **0.026% → 0.035%** | With training data on both sides, gaps up to ~3 weeks cost almost nothing. |
| **Unseen sky patch**, ecliptic (210°, 0°) | 0.145% | **0.054%** | Hardest patch — the error concentrates in a thin stripe at β = 0 (dust bands). |
| **Unseen sky patch**, mid-latitude (180°, +45°) | 0.051% | **0.034%** | |
| **Unseen sky patch**, near pole (240°, +75°) | 0.95% | **0.025%** | Baseline fails here (no season information); season model doesn't. |
| **Learning curve** 1% → 100% of training data | 0.19% → 0.17% | **0.039% → 0.035%** | 2,400 well-spread exposures already reach 0.04%. |

**Take-home:** the season model is accurate to ~0.03–0.05% wherever it is *interpolating* — in time (gaps up to weeks),
on the sky (12°-radius holes; interiors ≤ 0.08%), and with as little as 1% of the data. What limits it is **coverage**
(time of year, sky, and the ecliptic dust bands), not data volume or model size.
""",

"code" => raw"""
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl", "extra_splits.jl", "nb_verify_fns.jl", "summary_helpers.jl",
          "checks_helpers.jl", "season_helpers.jl", "gen_helpers.jl")
    include(joinpath(@__DIR__, "..", "sweeps", f))
end
""",

"markdown" => raw"""
## 1. Block-length sweep — accuracy vs time gap
Each block length L alternates L days of training with L days of test across the mission. Longer blocks = test
exposures further (in time) from any training exposure. The season features are in range for every L (the test blocks sit
between training blocks), except the last partial block of the 45-day split.
""",

"code" => raw"""
blocklength_table()
""",

"code" => raw"""
blocklength_fig()
""",

"markdown" => raw"""
## 2. Sky-patch holdouts — predicting sky the model never saw
Every exposure within 12° of the patch centre is held out for the *entire* mission; the model trains on the rest of the sky
(all times). `test_out_of_range_pct` = fraction of held-out exposures with at least one feature outside its training range
(the patch's look directions are new, but they are surrounded by observed sky).
""",

"code" => raw"""
patch_table()
""",

"code" => raw"""
patch_map_fig("season")
""",

"code" => raw"""
patch_map_fig("base")
""",

"markdown" => raw"""
## 3. Learning curve — how much data is needed?
Random subsets of the 30-day-block **training** exposures; the **test** blocks are always the same. Every run takes about
the same number of optimizer steps (100 epochs of the full set), so smaller sets aren't simply undertrained. Dashed lines =
training error: when train ≪ test the model is data-limited (overfitting); when they meet, it is capacity-limited.
""",

"code" => raw"""
lc_table()
""",

"code" => raw"""
lc_fig()
""",

"markdown" => raw"""
## Physics checks on the held-out results
(i) The held-out patches must not be "easy" because of near-duplicate exposures: report the angular distance from each
held-out exposure to the nearest training exposure. (ii) Residuals of the season model on the patches vs latitude,
elongation and time — any structure points at what the model can't interpolate.
""",

"code" => raw"""
for (i, (nm, lo, la)) in enumerate(PATCHES)
    rs = patch_runs(i, "season"); isempty(rs) && continue
    tr, te = rs[1].tr_idx, rs[1].te_idx
    sub = te[1:max(1, length(te) ÷ 400):end]                         # a few hundred held-out exposures
    Ntr = nvec_unit_cartesian[:, tr]
    dmin = [acosd(clamp(maximum(Ntr' * nvec_unit_cartesian[:, k]), -1, 1)) for k in sub]
    dcentre = patch_dist(lo, la)[sub]
    @printf("patch %-16s held-out exposures are %.1f–%.1f° from the nearest training exposure (median %.1f°); %.0f%% are >6° inside the patch\n",
            nm, extrema(dmin)..., median(dmin), 100mean(dcentre .< PATCH_RADIUS - 6))
    # is the patch INTERIOR as good as its edge? (interior = more than 6° from the patch boundary)
    e = ensemble_pred(rs); fe = 100abs.(e[te] .- y[te]) ./ y[te]; dc = patch_dist(lo, la)[te]
    inner, edge = dc .< PATCH_RADIUS - 6, dc .>= PATCH_RADIUS - 6
    @printf("      season-model median |error|: interior %.3f%% (n=%d)  vs  edge %.3f%% (n=%d)\n",
            median(fe[inner]), count(inner), median(fe[edge]), count(edge))
end
""",

"code" => raw"""
P8 = Dict{String, Any}()
for (i, (nm, _, _)) in enumerate(PATCHES)
    rs = patch_runs(i, "season"); isempty(rs) || (P8["patch: $nm"] = as_ensemble(rs, "patch: $nm"))
end
verify_residuals(P8, sort(collect(keys(P8))); tag="_patches")
""",

"markdown" => raw"""
## Conclusions — for the mentor meeting

**1. Time gaps (block-length sweep).** With season features the error stays at 0.026–0.035% from 1-day to 45-day blocks
(median gap to the nearest training exposure 0.25 → 10 days, maximum ~22 days); the baseline sits ~50× higher at every
length and creeps up with gap. Physically: the zodiacal brightness changes smoothly with Earth's orbital position, so once
the model knows that position, filling a few-week hole between observations is easy. Contrast: *extrapolating* beyond the
data (chronological split) degrades much faster (10/07 ladder) — **bracketing matters more than distance**.

**2. Unseen sky (patch holdouts).** Every held-out direction is inside the training feature ranges (the holes are
surrounded by observed sky), so this is interpolation in direction. The season model predicts the never-seen patches at
0.025–0.054%; interiors (> 6° from the edge) are modestly worse than edges (up to 3.4× at the pole patch) but stay below
0.08%. The ecliptic patch is hardest, and the map shows why: errors line up along β = 0, where Kelsall's narrow dust
bands sit — the same residual seen on 10/09. The baseline fails on the polar patch (0.95%) for the known reason (no season).

**3. Data volume (learning curve).** The season model is essentially saturated from ~3% of the training exposures
(7,300) and already at 0.039% with 1% (2,434); the baseline's training error equals its test error (~1e-5) at every
size, i.e. it is limited by missing *information*, not data. **For real data, plan coverage (whole year, whole sky)
rather than raw exposure count.** (Subsets here are random over the training period, so they keep full time/sky
coverage; a real-data shortfall would usually also lose coverage, which matters more.)

**For the mentor meeting — suggested slides:** (a) block-length sweep figure; (b) held-out sky-patch map (season model),
with the dust-band stripe; (c) learning curve. Talking point: the emulator now interpolates at the ~0.03% level in time,
sky and data volume; the open problems are extrapolation beyond the observed season and the ecliptic dust bands.

**Next steps:** (1) a dust-band feature (sharp latitude structure near the ecliptic / the band planes) to remove the β = 0
stripe; (2) package emulator v2 with season features; (3) real data: maximize season and sky coverage in the training set.
""",
]
