# Cell contents for 10092026.ipynb — season features (#1) and log target revisited (#3).
CELLS = Pair{String,String}[

"markdown" => raw"""
# Season features and the log target, revisited (Oct 9, 2026)

**#1 Season features.** Every remaining error traced back to one blind spot: the look-direction features `n·*` don't
know *where Earth is in its orbit* (the late-test drift, extra scatter within ~2° of the ecliptic poles, ~16% too-weak
north/south asymmetry from the tilted cloud). Here the model gets Earth's orbital phase explicitly: `sin λ⊕`, `cos λ⊕`
(λ⊕ = Earth's ecliptic longitude; periodic over a year).

*Physics caveat, decided in advance:* the mission covers only 134° of Earth's orbit (λ⊕ = 214.5° → 348.3°), so on a
**chronological** split the season features are out of their training range (84–100% of test rows) — exactly like the
earlier "clock" features. Their real test is **interpolation** (30-day blocks, random split), which is what a full year
of real data will look like. Primary verdict: interpolation; chronological shown for honesty.

**#3 Log target revisited.** On 10/07 the log target (predict log y) won validation and all-sky fractional error but was
seed-sensitive. Here: 10 seeds each of linear and log target (paired by seed), plus a **mixed loss**
`MSE(y) + α·MSE(log y)` (network predicts log y, so outputs are always positive) with α = 0.25 (≈ equal weight at y ≈ 0.5)
and α = 1 (log-leaning).

All runs: 64-64-32-16 MLP, one-cycle LR (peak 1e-3), 100 epochs (`sweeps/configs_v7.jl`). This notebook loads the saved
results and runs top-to-bottom in a few minutes.

### Summary
| question | result |
|---|---|
| **#1 Do season features help where the season is covered (interpolation)?** | **Yes — 44–65× lower test MSE.** 30-day blocks: ensemble 8.8e-6 → **2.0e-7** (median error 0.14% → **0.032%**); random: 1.0e-5 → **1.6e-7** (0.11% → **0.026%**). Leakage checks pass. |
| …and do the physical symptoms go away? | **Yes.** Error within 2° of the poles: rms 2.5–4.4% → **0.03–0.04%**; north/south asymmetry pattern correlation 0.58 → **0.998**, amplitude 73% → **98%** of Kelsall's; the model now tracks the seasonal pole brightness. |
| …and when extrapolating (chronological)? | Still better, despite season features being out of range: validation 3.1e-5 → 3.5e-7, test 2.7e-4 → **3.8e-5** (7×), late drift −0.014 → +0.003. |
| **#3 Is the log target better with 10 seeds?** | **No (chronological).** It beats linear in only 2 of 10 paired seeds (median MSE 2.4× worse); the mixed loss lands in between. It does give the best all-sky in-domain fractional error (0.32% vs 0.59%), but an exp output can blow up toward the Sun (mixed α=0.25: median 1100% near the Sun). **Linear output stays.** |

**Bottom line:** Earth's orbital phase was the missing variable. With it the emulator interpolates at ~0.03% —
about 20× below the 0.5–0.6% of the current model — and the remaining residuals sit at the ecliptic (dust bands).
""",

"code" => raw"""
include(joinpath(@__DIR__, "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl", "nb_verify_fns.jl", "summary_helpers.jl", "checks_helpers.jl", "season_helpers.jl")
    include(joinpath(@__DIR__, "sweeps", f))
end
""",

"markdown" => raw"""
## #1 Season features

### 1a. Pre-flight: are the season features physically right, and where are they in range?
""",

"code" => raw"""
o = sortperm(t_rel)
@printf("Earth's ecliptic longitude: day 0 → %.1f°, day 139.7 → %.1f° (%.1f° of the orbit)\n",
        λE_deg[o[1]], λE_deg[o[end]], mod(λE_deg[o[end]] - λE_deg[o[1]], 360))
sunλ = mod.(atand.(-spherex_positions[2, :], -spherex_positions[1, :]), 360)
@printf("consistency: λ⊕ − (Sun's longitude seen from SPHEREx) = 180° to within %.2f° (median)\n", median(abs.(mod.(λE_deg .- sunλ, 360) .- 180)))
s_, c_ = Fd_raw[:, findfirst(==("sinλE"), dot_names_all)], Fd_raw[:, findfirst(==("cosλE"), dot_names_all)]
for sp in ("random split", "30 day split", "80/20 Chronological")
    tr, te = splits[sp]; sp == "80/20 Chronological" && (tr = tr[t_rel[tr] .< 100])
    frac(v) = begin lo, hi = extrema(v[tr]); 100mean((v[te] .< lo) .| (v[te] .> hi)) end
    @printf("%-20s test rows outside the training range: sin λ⊕ %5.1f%%   cos λ⊕ %5.1f%%\n", sp, frac(s_), frac(c_))
end
println("(30-day blocks: sin λ⊕ reaches its minimum at λ⊕ = 270°, which falls inside a test block → 6.8% slightly out of range)")
""",

"markdown" => raw"""
### 1b. Accuracy — interpolation (primary) and chronological
""",

"code" => raw"""
println("30-day alternating blocks:"); display(compare_table(S_BLOCK))
println("random 50/50 (seeds 42–44):"); display(compare_table(S_RANDOM))
println("chronological, fit days 0–100 (season features extrapolate here):"); display(compare_table(S_CHRONO))
""",

"markdown" => raw"""
### 1b′. Is a 30–60× improvement real? Leakage checks
A gain this large deserves scrutiny. (1) Splits are clean partitions with training-only normalization. (2) Test exposures
are far from training ones in time on the block split, yet the gain matches the random split's → it is not "near-duplicate
neighbours" leaking. (3) `sin/cos λ⊕` is a function of time only — Earth's orbital position, which is exactly the observer
information Kelsall depends on (the line of sight starts at the observer) and which the `n·*` set lacked; it contains no
information about the target itself.
""",

"code" => raw"""
for (lbl, spec) in (S_BLOCK[2], S_RANDOM[2])
    rs = grp_runs(spec); r = rs[1]; tr, te = r.tr_idx, r.te_idx
    cols = [findfirst(==(nm), dot_names_all) for nm in r.feature_names]
    ok_part = isempty(intersect(tr, te)) && sort(vcat(tr, te)) == collect(1:N)
    ok_norm = all(r.μ ≈ [median(Fd_raw[tr, c]) for c in cols] for r in rs)
    gaps = gap_days(tr, te)
    @printf("%-28s %-14s partition ok: %s | normalization from training rows: %s | test→nearest training exposure: median %.2f d, max %.1f d\n",
            lbl, r.split_name, ok_part, ok_norm, median(gaps), maximum(gaps))
end
rs = grp_runs(S_BLOCK[2][2])
println("\npermutation importance on the 30-day-block TEST blocks (season model ensemble):")
perm_importance(rs, rs[1].te_idx)
""",

"markdown" => raw"""
### 1c. Does knowing the season fix the physical symptoms?
**(i) Scatter near the ecliptic poles** — on the test blocks of the interpolation split:
""",

"code" => raw"""
pole_table(S_BLOCK)
""",

"markdown" => raw"""
**(ii) The pole brightness through the mission** — the Kelsall pole brightness changes with the season (Earth's position
relative to the ~2°-tilted cloud). Without season information the network cannot follow it.
""",

"code" => raw"""
pole_series_fig(S_BLOCK; title="Ecliptic-pole exposures, 30-day-block split: truth vs baseline vs season model")
""",

"markdown" => raw"""
**(iii) North/south asymmetry of the tilted cloud on the all-sky map** (epoch 13170 = day 0, a training day for the block
split). Before: the model reproduced only ~84% of the amplitude.
""",

"code" => raw"""
asym_rows = map(S_BLOCK) do (lbl, spec)
    A = allsky_eval(grp_runs(spec); title=lbl); a = ns_asymmetry(A)
    (; model=lbl, in_domain_pct=round(A.metrics.sky_pct[1], digits=1), in_domain_median_err_pct=round(A.metrics.median_abs_frac_pct[1], digits=3),
       north_minus_south_model_pct=round(a.model_mean_pct, digits=2), truth_pct=round(a.truth_mean_pct, digits=2),
       pattern_corr=round(a.pattern_corr, digits=3), amplitude_ratio=round(a.amplitude_ratio, digits=3),
       above_60deg_model_pct=round(a.highlat_model_pct, digits=2), above_60deg_truth_pct=round(a.highlat_truth_pct, digits=2))
end
DataFrame(asym_rows)
""",

"markdown" => raw"""
**(iv) Residuals vs time, latitude and elongation** (5-seed ensembles, interpolation split):
""",

"code" => raw"""
D_s = Dict{String, Any}(lbl => as_ensemble(grp_runs(spec), lbl) for (lbl, spec) in S_BLOCK)
verify_residuals(D_s, first.(S_BLOCK); tag="_season")
""",

"markdown" => raw"""
## #3 Log target revisited

### 3a. Ten seeds, paired by initialization
""",

"code" => raw"""
P = paired_seeds()
display(P.df)
@printf("log target beats linear in %d of %d paired seeds; geometric-mean MSE ratio (log/linear) = %.2f\n", P.log_wins, P.n, P.geo_mean_ratio)
""",

"markdown" => raw"""
### 3b. All output choices — chronological and interpolation
""",

"code" => raw"""
println("chronological 80/20 (fit days 0–111.4):"); display(target_compare(T_CHRONO))
println("30-day blocks:"); display(target_compare(T_BLOCK))
""",

"code" => raw"""
seed_strip_fig(T_CHRONO, T_BLOCK)
""",

"markdown" => raw"""
### 3c. All-sky behaviour (chronological-fit ensembles)
""",

"code" => raw"""
rows = map(T_CHRONO) do (lbl, spec)
    A = allsky_eval(trun(spec); title=lbl); sun = A.elong .< 60
    (; output=lbl, in_domain_rms=round(A.metrics.rms_MJy_sr[1], digits=4), in_domain_median_err_pct=round(A.metrics.median_abs_frac_pct[1], digits=3),
       out_domain_median_err_pct=round(A.metrics.median_abs_frac_pct[2], digits=2), near_sun_median_err_pct=round(100median(abs.(A.res[sun]) ./ A.yt[sun]), digits=1),
       negative_predictions=A.metrics.negative_predictions[3])
end
DataFrame(rows)
""",

"markdown" => raw"""
## Conclusions

**#1 Season features — the missing variable found.**
* Physically, Kelsall's brightness along a line of sight depends on *where the observer is* in the (tilted, offset) dust
  cloud. The `n·*` features only described the look direction relative to moving vectors; they never told the network
  where Earth is in its orbit. `sin/cos λ⊕` supplies exactly that information (the same as `S·x`, `S·y`), in a periodic
  form that interpolates cleanly over a full year.
* On interpolation splits error drops 44–65× (median 0.03%), and each symptom traced to this blind spot disappears:
  pole scatter (rms 2.5–4.4% → 0.03–0.04%), the weak north/south asymmetry (amplitude 73% → 98%, pattern corr 0.998),
  and the inability to follow the seasonal pole brightness (see the pole time series).
* It is not leakage: partitions are clean, normalization uses training rows only, block-split test exposures are a median
  7.4 days (up to 15) from any training exposure yet gain as much as the random split, and the features contain only
  Earth's position.
* Even when extrapolating (chronological), season features help 7× on the test period — they are smooth and only slightly
  out of range — but the honest regime for them is a full year of data, where they are always in range.
* **What's left:** residuals now concentrate within ±10° of the ecliptic, where Kelsall's narrow asteroid dust bands
  live — the component the onboarding predicted would be hardest — plus a smooth wiggle near the end of the covered orbit.

**#3 Log target — linear output stays.**
* With 10 paired seeds the log target loses on the chronological test (2/10 wins; 2.4× median MSE) and has the widest
  seed spread; the mixed loss sits between the two.
* It does reach the best all-sky in-domain fractional error (0.32% vs 0.59%), and slightly better tails (95th percentile).
* Physically important caveat: an exponential output **extrapolates multiplicatively** — toward the Sun the mixed-loss
  model's median error is ~1100% (log target 66%, linear 44%). For an emulator that may be queried out of domain, the
  linear output is safer.
* No variant ever predicts a negative value.

**Recommendations**
1. **Adopt `sin/cos λ⊕` in the recommended model** (`FEATURE_SETS[:look_dir_season]`), and plan on training data that
   covers the full year so the season is always interpolated.
2. Keep linear output + MSE; revisit the log target only together with season features (its in-domain fractional
   advantage may persist without the seed sensitivity — untested).
3. Next physics target: the ecliptic dust bands (features sharp in latitude, e.g. ecliptic latitude of the line of sight
   relative to the band planes), now visible as the dominant residual.
4. A v2 packaged emulator with season features would need Earth's longitude as an input (one line in `ZodiEmulator`).
""",
]
