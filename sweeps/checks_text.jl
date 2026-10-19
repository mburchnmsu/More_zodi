# Cell contents for 10082026.ipynb — Earth-centric control and clean Jupiter null controls (round 6).
CELLS = Pair{String,String}[

"markdown" => raw"""
# Remaining onboarding checks — Earth-centric control and a clean Jupiter null (Oct 8, 2026)

Two control experiments from the onboarding notebook, each validated several ways and checked against physical expectations.

* **A. Earth-centric control.** Re-express the observer's position as Earth + LEO offset (`S = E + δ`): replace `n·S` by
  `n·δ` (`n·E` is already a feature). Same information, different coordinates. **Prediction: a null** — the LEO
  offset (≈7000 km ≈ 4.7×10⁻⁵ AU) changes the zodiacal brightness by ~10⁻⁴, an MSE term ~10⁵× below the current error.
* **B. A clean Jupiter null.** Kelsall (1998) contains no Jupiter, yet on 10/07 removing `n·J` hurt extrapolation — the
  only thing `n·J` adds beyond the fixed sky frame is Jupiter's 12° drift over the mission, i.e. a slow *clock*. A clean
  null compares Jupiter against **time-matched controls**: fake planets with exactly Jupiter's motion seen from other
  directions (rotated 45° and 90° about the ecliptic pole), and Jupiter with its timing scrambled.
  **Predictions:** if `n·J` is only a clock, fake planets ≈ Jupiter, scrambled ≈ no Jupiter; on an *interpolation* split
  (no clock needed) all variants ≈ equal.

**Protocol.** 64-64-32-16 MLP, one-cycle LR (peak 1e-3), 100 epochs. *Chronological:* fit days 0–100, validate
100–111.4, test 111.4–139.7, 5 seeds. *Interpolation:* 30-day alternating blocks, 3 seeds. Runs were done in `sweeps/`
(`configs_v6.jl`); this notebook loads the saved results and runs top-to-bottom in a few minutes.

### Summary
| check | prediction | result |
|---|---|---|
| **A. Earth-centric** (`n·S → n·δ`) | null (parallax ~10⁻⁴) | **Null confirmed** on 3 tests: chrono ensemble MSE 2.70e-4 vs 2.67e-4, block 1.08e-5 vs 1.05e-5, linear/quadratic fits *identical*. But `n·δ` inherits the Earth-avoidance pointing rule → all-sky domain shrinks **32% → 5%**. |
| **B. Jupiter vs time-matched controls** | fake planets ≈ Jupiter; scrambled ≈ none; interpolation: no benefit | **Confirmed on robust metrics**: ensembles with time information 1.3–1.6% median error vs 2.6% without (scrambled 2.59% ≈ none 2.61%); on interpolation the benefit disappears (0.13–0.17%, time-free slightly better). Test MSE itself is too seed-noisy to rank them. |

**Bottom line:** in this data `n·J` helps only by carrying *time* (Jupiter's 12° drift), not Jupiter physics — Kelsall has no
Jupiter component. A fake planet moving the same way helps just as much; Jupiter with scrambled timing doesn't help at all.
""",

"code" => raw"""
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl", "nb_verify_fns.jl", "summary_helpers.jl", "checks_helpers.jl")
    include(joinpath(@__DIR__, "..", "sweeps", f))
end
println("\nfeature sets used today:")
for k in (:look_dir, :earth_centric, :look_dir_Jrot45, :look_dir_Jrot90, :look_dir_Jscr, :look_dir_noJ)
    println("  ", rpad(k, 17), join(FEATURE_SETS[k], ", "))
end
""",

"markdown" => raw"""
## A. Earth-centric control

### A1. Pre-flight physics: what is `δ`, and how big should its effect be?
""",

"code" => raw"""
dn = vec(sqrt.(sum(δ_vec .^ 2, dims=1)))
tr80, te80 = splits["80/20 Chronological"]
nd = Fd_raw[:, findfirst(==("n·δ"), dot_names_all)]
@printf("|δ| = %.2e – %.2e AU = %.0f – %.0f km  (Earth radius 6371 km + ~650–675 km altitude ✓)\n", extrema(dn)..., (extrema(dn) .* 1.496e8)...)
@printf("n·S vs n·E: correlation %.6f, max |difference| %.1e AU — n·S already ≈ n·E\n",
        cor(Fd_raw[:, findfirst(==("n·S"), dot_names_all)], Fd_raw[:, findfirst(==("n·E"), dot_names_all)]), maximum(abs.(nd)))
@printf("n·δ / |δ| in training spans %.2f – %.2f: the boresight is always ≥%.0f° from Earth's centre (Earth avoidance)\n",
        extrema(nd[tr80] ./ dn[tr80])..., acosd(-minimum(nd[tr80] ./ dn[tr80])))
println("→ because |δ| is nearly constant, n·δ ≈ |δ|·n·δ̂ (corr ", round(cor(nd, Fd_raw[:, findfirst(==("n·δ̂"), dot_names_all)]), digits=4),
        "): it mostly encodes the POINTING RULE, and only ~1e-4 of real parallax physics")
P = parallax_check(load_prefix("final_base_s"))
@printf("\nTrained baseline ensemble: moving the observer from SPHEREx to Earth's centre changes predictions by\nmedian %.1e, 99th percentile %.1e (fractional). Physics estimate |δ|·|dlnI/dlnr| ≈ %.0e.\n",
        P.median_frac, P.p99_frac, P.physics_estimate)
""",

"markdown" => raw"""
### A2. Does the Earth-centric switch change accuracy? (chronological and interpolation splits)
""",

"code" => raw"""
display(compare_table(A_CHRONO))
display(compare_table(A_BLOCK))
""",

"markdown" => raw"""
### A3. Linear models: is the `n·δ` coefficient ≈ 0? (onboarding's suggested check)
""",

"code" => raw"""
for fs in (:look_dir, :earth_centric)
    L = linear_coefs(FEATURE_SETS[fs])
    @printf("%-14s  linear test MSE %.3e | linear+quadratic test MSE %.3e\n", fs, L.mse_lin, L.mse_quad)
    display(L.table)
end
""",

"markdown" => raw"""
### A4. Does the trained network actually use `n·δ`? — permutation importance
Shuffle one feature across the held-out exposures and measure the ensemble's MSE ratio (1.00 = feature unused).
""",

"code" => raw"""
ec_chrono = load_prefix("v_ec_s")
println("Earth-centric ensemble, chronological TEST period:"); display(perm_importance(ec_chrono, ec_chrono[1].te_idx))
ec_blk = load_prefix("blk_ec_s")
println("Earth-centric ensemble, 30-day-block TEST blocks:"); display(perm_importance(ec_blk, ec_blk[1].te_idx))
""",

"markdown" => raw"""
### A5. All-sky consequence: `n·δ` inherits the Earth-avoidance pointing rule
""",

"code" => raw"""
A_base = allsky_eval(load_prefix("v_base_s"); title="baseline (fit days 0–100)")
A_ec   = allsky_eval(ec_chrono; title="Earth-centric (fit days 0–100)")
display(vcat(insertcols!(copy(A_base.metrics), 1, :model => "baseline"), insertcols!(copy(A_ec.metrics), 1, :model => "Earth-centric")))
A_ec.fig
""",

"markdown" => raw"""
## B. A clean Jupiter null

### B1. Pre-flight: what each Jupiter-like feature contains
`moving_part_pct` = how much of the feature is NOT a fixed-sky-axis combination (n·x, n·y, n·z); `time_drift_R2` =
how much of that moving part is a smooth function of time (a clock). The 180° fake planet is shown only to confirm
it is just −n·J (an in-plane vector rotated 180° about the pole is its negative), which is why 90° was used instead.
""",

"code" => raw"""
jupiter_feature_table()
""",

"markdown" => raw"""
### B2. Jupiter vs time-matched controls (chronological and interpolation splits)
""",

"code" => raw"""
display(compare_table(B_CHRONO))
display(compare_table(B_BLOCK))
""",

"code" => raw"""
compare_fig(B_CHRONO, B_BLOCK; title="B. Jupiter vs time-matched fake planets vs scrambled vs none")
""",

"markdown" => raw"""
**Reading the figure.** Test **MSE** is dominated by a few seeds with large errors: the seed ranges overlap almost completely,
so MSE alone cannot rank these variants (an early impression that the 90° fake planet was worse came from single bad
seeds). Two more robust read-outs of the 5-seed ensembles — the **median fractional error** and the **bias in the last
10 days** — separate the variants cleanly by whether the feature carries **time information**:
""",

"code" => raw"""
chr = compare_table(B_CHRONO); blk = compare_table(B_BLOCK)
has_time = ["yes (Jupiter's motion)", "yes (same motion)", "yes (same motion)", "no (scrambled)", "no (absent)"]
DataFrame(variant=chr.variant, time_information=has_time,
          chrono_median_frac_err_pct=chr.test_ens_median_frac_pct, chrono_late_bias=chr.late_test_bias,
          block_median_frac_err_pct=blk.test_ens_median_frac_pct)
""",

"markdown" => raw"""
### B4. Could it be Jupiter's dust (Trojan clouds leading/trailing Jupiter, Jupiter-family comet debris)?
Not in this experiment: the training target is the Kelsall (1998) model, whose components are listed below — none is tied
to Jupiter. And physically, dust at Jupiter's distance is very faint at 5 μm:
""",

"code" => raw"""
println("Kelsall components in the all-sky truth file: ",
        join(filter(k -> startswith(k, "emission_"), h5open(keys, allsky_file)), ", "))
# blackbody grain temperature T ≈ 278 K / √(r/AU); thermal emission at 5 μm ∝ 1/(exp(hc/λkT) − 1)
planck(λμm, T) = 1 / (exp(14388 / (λμm * T)) - 1)
T1, T5 = 278.0, 278.0 / sqrt(5.2)
@printf("grain temperature: %.0f K at 1 AU, %.0f K at 5.2 AU (peak emission near %.0f μm)\n", T1, T5, 2898 / T5)
@printf("5 μm thermal emission per grain at 5.2 AU relative to 1 AU: %.1e\n", planck(5, T5) / planck(5, T1))
@printf("scattered sunlight per grain falls as 1/r²: %.3f of the 1-AU value\n", 1 / 5.2^2)
println("→ at 5 μm, Jupiter-associated dust is many orders of magnitude fainter in thermal emission than the local cloud;\n" *
        "  if it is detectable at all it will be in scattered light at SPHEREx's shorter wavelengths — a real-data question.")
""",

"markdown" => raw"""
### B3. How much does each model lean on its Jupiter-like feature? — permutation importance (chronological test)
""",

"code" => raw"""
for (lbl, spec) in B_CHRONO[1:4]
    rs = grp_runs(spec); jf = filter(nm -> occursin("J", nm), rs[1].feature_names)[1]
    imp = perm_importance(rs, rs[1].te_idx)
    @printf("%-40s shuffle %-9s → MSE × %.3f   (most important feature: %s × %.2f)\n",
            lbl, jf, imp.mse_ratio_when_shuffled[findfirst(==(jf), imp.feature)], imp.feature[1], imp.mse_ratio_when_shuffled[1])
end
""",

"markdown" => raw"""
## Conclusions

**A. Earth-centric control — a validated null, with one caveat.**
* Same accuracy in every test (chronological, interpolation, linear, linear+quadratic). The linear fits are *identical*
  because `{n·S, n·E}` and `{n·δ, n·E}` span the same space (`n·δ = n·S − n·E`).
* The coefficient check shows *why* the reparametrization is still worth it: in the barycentric set `n·S` and `n·E`
  get huge cancelling coefficients (+1110 / −1110 MJy/sr per σ) — the onboarding's near-duplicate warning — while
  the Earth-centric set is well conditioned (`n·δ` = 0.013, `n·E` = −0.03).
* `n·δ`'s linear coefficient (0.013 per σ) is ~6000× larger than real parallax could produce (~2×10⁻⁶ per σ), and
  shuffling it raises the network's error ×1.1 (chrono) / ×3.8 (block, from a tiny baseline): the network uses `n·δ` as a
  *redundant proxy* for pointing geometry (in SPHEREx's orbit the direction to Earth is tied to the Sun direction),
  not for parallax. Removing that proxy costs nothing in accuracy (identical ensemble MSE).
* Because |δ| is constant, `n·δ` ≈ |δ|·`n·δ̂` encodes the Earth-avoidance rule, so the all-sky in-domain region
  collapses from 32% to 5%. For an all-sky **emulator**, keep the barycentric `n·*` set. For **real data**, where you
  only predict at directions SPHEREx actually observed, Earth-anchored features (`n·δ̂`, Moon) are fine and needed
  for Earthshine/stray light.

**B. Jupiter null — the benefit is time information, not Jupiter.**
* The only thing `n·J` adds beyond the fixed sky axes is Jupiter's 12° motion (3–4% of the feature, R² ≈ 0.6 as a
  smooth function of time). Fake planets with the same motion carry the same kind of clock; scrambling removes it
  (R² = 0.000).
* Ensembles **with** time information (Jupiter, 45°, 90° fake planets): median error 1.27–1.63%, late bias −0.008 to −0.018.
  **Without** (scrambled, none): 2.59–2.61%, −0.019 to −0.021. On the interpolation split the differences shrink to
  ≤0.04 percentage points, and if anything the time-free variants are slightly better (0.13–0.14% vs 0.16–0.17%) —
  a clock only helps when extrapolating. Exactly the time-information pattern; a Jupiter-dust effect would instead
  make *real* Jupiter beat the fake planets on both splits.
* Kelsall contains no Jupiter-related component, and dust at 5.2 AU (~120 K) is ~10⁻⁶× fainter per grain in 5 μm
  thermal emission than dust at 1 AU — so even on real 5 μm data a Jupiter-dust signal would be tiny.
* Permutation importance is **not** a reliable diagnostic here: `n·J` (corr 0.999 with `n·y`) looks "essential" only
  because it duplicates the `n·y` geometry.

**What this means going forward**
1. Treat any feature that drifts with time (planets, Earth's orbital position, `S·S`) as a *clock* first, physics second.
   A Jupiter test on real data needs time-matched controls (fake planets) — "with vs. without Jupiter" is not a null.
2. Better: give the model explicit, periodic season features (e.g. Earth's ecliptic longitude as sin/cos) and train on
   a full year, so time enters as physics instead of leaking in through incidental features.
3. Rank models by robust metrics (median error, bias, ensembles), not by single-seed MSE.
""",
]
