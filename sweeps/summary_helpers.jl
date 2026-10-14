# ==============================================================================
# Helpers for the 10072026 summary notebook: load saved sweep results and turn
# them into tables (DataFrames) and figures. Requires zodi_setup.jl, mb_train.jl,
# extra_features.jl and nb_verify_fns.jl to be included first.
# ==============================================================================
using Serialization, DataFrames, Healpix

const RES = isdefined(Main, :RESULTS_DIR) ? RESULTS_DIR : joinpath(@__DIR__, "results")   # results_z115 for ZODI_DATA="z115"
load_run(name) = deserialize(joinpath(RES, name * ".jls"))
load_prefix(prefix) = [deserialize(joinpath(RES, f)) for f in sort(readdir(RES))
                       if startswith(f, prefix) && endswith(f, ".jls")]
ensemble_pred(rs) = vec(mean(reduce(hcat, [r.ypred for r in rs]), dims=2))
mse_on(pred, idx) = mean(abs2, pred[idx] .- y[idx])
sci(x) = isnan(x) ? "—" : @sprintf("%.2e", x)
archstr(r) = r.arch === :mlp ? join(r.hidden, "-") : "res w$(r.width)×$(r.blocks)"

# ---------------------------------------------------------------- 3. features
"""Fraction of 80/20 TEST exposures whose feature value lies outside the TRAINING range."""
function feature_shift_table(; split="80/20 Chronological")
    tr, te = splits[split]
    rows = DataFrame(feature=String[], frac_test_outside=Float64[], excursion_train_iqr=Float64[], kind=String[])
    for i in axes(Fd_raw, 2)
        nm = dot_names_all[i]; nm == "n·δ̂" && continue
        iqr(Fd_raw[tr, i]) > 1e-12 || continue                       # constant features are dropped anyway
        lo, hi = extrema(Fd_raw[tr, i]); v = Fd_raw[te, i]
        push!(rows, (nm, mean((v .< lo) .| (v .> hi)), max(maximum(v) - hi, lo - minimum(v), 0) / iqr(Fd_raw[tr, i]),
                     startswith(nm, "n·") ? "look-direction" : "orbit-only"))
    end
    sort!(rows, :frac_test_outside, rev=true)
end

function fullbatch_fig()
    FB = joinpath(RES, "fullbatch")
    tr36, te36, _, _ = deserialize(joinpath(FB, "fb_all36_32-16_hist.jls"))
    runs = [("n·* only (32-16)", "fb_n_32-16", :orangered), ("n·* + S·S (32-16)", "fb_nSS_32-16", :limegreen),
            ("n·* only (64-64-32-16)", "fb_n_64-64-32-16", :deepskyblue), ("n·* + S·S (64-64-32-16)", "fb_nSS_64-64-32-16", :gold)]
    fig = Figure(size=(1000, 560), fontsize=13)
    ax = Axis(fig[1, 1], xlabel="epoch (full batch)", ylabel="MSE (MJy/sr)²", yscale=log10,
              title="Day 1 — full-batch training, 80/20 chronological. solid = test, dashed = train")
    lines!(ax, 0:length(te36)-1, te36, color=:gray60, linewidth=2, label="all 36 features (32-16)")
    lines!(ax, 0:length(tr36)-1, tr36, color=:gray60, linestyle=:dash)
    for (lbl, f, c) in runs
        r = deserialize(joinpath(FB, f * ".jls"))
        lines!(ax, 0:length(r.te_hist)-1, r.te_hist, color=c, linewidth=2, label=lbl)
        lines!(ax, 0:length(r.tr_hist)-1, r.tr_hist, color=c, linestyle=:dash)
    end
    hlines!(ax, [mean(abs2, y[splits["80/20 Chronological"][2]] .- mean(y[splits["80/20 Chronological"][1]]))],
            color=:white, linestyle=:dot, label="null (predict train mean)")
    axislegend(ax, position=:rt, labelsize=11); fig
end

# ---------------------------------------------------------------- 4. schedules
const SCHED_GROUPS = [("one-cycle 1e-3", ["p1_onecycle_1e-3", "p1s_onecycle_1e-3_s43", "p1s_onecycle_1e-3_s44"]),
                      ("linear 1e-3",    ["p1_linear_1e-3", "p1s_linear_1e-3_s43", "p1s_linear_1e-3_s44"]),
                      ("cos×exp 3e-3",   ["p1_cosexp_3e-3", "p1s_cosexp_3e-3_s43", "p1s_cosexp_3e-3_s44"]),
                      ("cos×exp 1e-2",   ["p1_cosexp_1e-2", "p1s_cosexp_1e-2_s43", "p1s_cosexp_1e-2_s44"]),
                      ("one-cycle 3e-3", ["p1_onecycle_3e-3"]), ("cos×exp 1e-3", ["p1_cosexp_1e-3"]),
                      ("one-cycle 1e-2", ["p1_onecycle_1e-2"])]
function schedule_table()
    df = DataFrame(schedule=String[], seeds=Int[], test_seed_42=String[], test_seed_43=String[], test_seed_44=String[],
                   test_mean=String[], train_mean=String[])
    for (lbl, names) in SCHED_GROUPS
        rs = load_run.(names); te = [r.te_hist[end] for r in rs]
        pad = vcat(sci.(te), fill("—", 3 - length(te)))
        push!(df, (lbl, length(rs), pad..., sci(mean(te)), sci(mean(r.tr_hist[end] for r in rs))))
    end
    df
end
function schedule_fig()
    fig = Figure(size=(1100, 520), fontsize=13)
    ax  = Axis(fig[1, 1], xlabel="epoch", ylabel="MSE (MJy/sr)²", yscale=log10,
               title="Mini-batch (512), 64-64-32-16, seed 42. solid = test, dashed = train")
    axl = Axis(fig[1, 2], xlabel="training progress", ylabel="learning rate", yscale=log10, title="schedules")
    for (k, (lbl, names)) in enumerate(SCHED_GROUPS)
        r = load_run(names[1]); c = Makie.wong_colors()[mod1(k, 7)]
        lines!(ax, 0:length(r.te_hist)-1, r.te_hist, color=c, linewidth=2, label=lbl)
        lines!(ax, 0:length(r.tr_hist)-1, r.tr_hist, color=c, linestyle=:dash, linewidth=1)
        lines!(axl, range(0, 1, length=length(r.lr_curve)), r.lr_curve, color=c, linewidth=2)
    end
    hlines!(ax, [9.276e-4], color=:white, linestyle=:dot, label="full-batch best (2000 ep, ~2 h)")
    axislegend(ax, position=:rt, labelsize=10); colsize!(fig.layout, 2, Relative(0.3)); fig
end

# ---------------------------------------------------------------- 5. architecture
const ARCH_GROUPS = [("mlp 32-16",            "p2_mlp_32-16_s"),
                     ("mlp 64-64-32-16",      ["p1_onecycle_1e-3", "p1s_onecycle_1e-3_s43", "p1s_onecycle_1e-3_s44",
                                               "p3_mlp_64-64-32-16_s45", "p3_mlp_64-64-32-16_s46",
                                               "p3_mlp_64-64-32-16_s47", "p3_mlp_64-64-32-16_s48"]),
                     ("mlp 128-128-64-32",    "p2_mlp_128-128-64-32_s"),
                     ("mlp 128×4-64-32",      "p2_mlp_128x4-64-32_s"),
                     ("mlp 256-256-128-64",   "p2_mlp_256-256-128-64_s"),
                     ("ResMLP w64×3",         "p2_res_w64_b3_s"),
                     ("ResMLP w128×4",        "p2_res_w128_b4_s"),
                     ("ResMLP w256×4",        "p2_res_w256_b4_s")]
arch_runs(spec) = spec isa String ? load_prefix(spec) : load_run.(spec)
function arch_table()
    df = DataFrame(architecture=String[], params=Int[], seeds=Int[], test_mean=String[], test_min=String[],
                   test_max=String[], test_ensemble=String[], train_mean=String[], minutes_per_run=Float64[])
    for (lbl, spec) in ARCH_GROUPS
        rs = arch_runs(spec); te = [r.te_hist[end] for r in rs]; r1 = rs[1]
        push!(df, (lbl, r1.n_params, length(rs), sci(mean(te)), sci(minimum(te)), sci(maximum(te)),
                   length(rs) > 1 ? sci(mse_on(ensemble_pred(rs), r1.te_idx)) : "—",
                   sci(mean(r.tr_hist[end] for r in rs)), round(mean(r.t_epoch[end] for r in rs) / 60, digits=1)))
    end
    df
end
function arch_fig()
    fig = Figure(size=(950, 520), fontsize=13)
    ax  = Axis(fig[1, 1], xlabel="parameters", ylabel="final test MSE (MJy/sr)²", xscale=log10, yscale=log10,
               title="Architecture scan (one-cycle 1e-3, 100 ep). bars = seed range, ● = seed mean, ★ = seed ensemble")
    for (lbl, spec) in ARCH_GROUPS
        rs = arch_runs(spec); te = [r.te_hist[end] for r in rs]; p = rs[1].n_params
        c = occursin("Res", lbl) ? :orangered : :deepskyblue
        rangebars!(ax, [p], [minimum(te)], [maximum(te)], color=c, whiskerwidth=8)
        scatter!(ax, [p], [mean(te)], color=c, markersize=12)
        length(rs) > 1 && scatter!(ax, [p], [mse_on(ensemble_pred(rs), rs[1].te_idx)], color=:gold, marker=:star5, markersize=16)
        text!(ax, p, mean(te), text="  " * lbl, fontsize=10, align=(:left, :center))
    end
    xlims!(ax, 5e2, 3e6); hlines!(ax, [9.276e-4], color=:white, linestyle=:dot); fig
end

# ---------------------------------------------------------------- 6. validation / round 2
const R2_GROUPS = [("baseline n·*", "v_base_s"), ("+ n·δ̂", "v_dhat_s"), ("− n·J", "v_noJ_s"),
                   ("weight decay 1e-6", "v_wd1e-6_s"), ("weight decay 1e-5", "v_wd1e-5_s")]
function round2_table()
    df = DataFrame(config=String[], features=Int[], seeds=Int[], val_seed_mean=String[], val_ensemble=String[],
                   test_seed_mean=String[], test_ensemble=String[], late_test_bias=Float64[])
    for (lbl, pre) in R2_GROUPS
        rs = load_prefix(pre); r1 = rs[1]; e = ensemble_pred(rs)
        late = r1.te_idx[t_rel[r1.te_idx] .> maximum(t_rel[r1.te_idx]) - 10]
        push!(df, (lbl, length(r1.feature_names), length(rs), sci(mean(r.va_hist[end] for r in rs)), sci(mse_on(e, r1.val_idx)),
                   sci(mean(r.te_hist[end] for r in rs)), sci(mse_on(e, r1.te_idx)), round(mean(e[late] .- y[late]), digits=4)))
    end
    df
end
function val_vs_test_fig()
    fig = Figure(size=(820, 500), fontsize=13)
    ax  = Axis(fig[1, 1], xlabel="validation MSE, days 100–111 (ensemble)", ylabel="test MSE, days 111–140 (ensemble)",
               xscale=log10, yscale=log10, title="Does the validation period rank models like the test period?")
    for (lbl, pre) in R2_GROUPS
        rs = load_prefix(pre); r1 = rs[1]; e = ensemble_pred(rs)
        scatter!(ax, [mse_on(e, r1.val_idx)], [mse_on(e, r1.te_idx)], markersize=14)
        text!(ax, mse_on(e, r1.val_idx), mse_on(e, r1.te_idx), text="  " * lbl, fontsize=11, align=(:left, :center))
    end
    fig
end

# ---------------------------------------------------------------- 7. generalization ladder
const LADDER = [("rand", "random 50/50"), ("wk7", "7-day alternating"), ("blk30", "30-day alternating"),
                ("mid", "50/50 mid-mission hole"), ("c85", "chrono 85/15"), ("c80", "chrono 80/20"),
                ("c75", "chrono 75/25"), ("c50", "chrono 50/50"), ("c25", "chrono 25/75")]
ladder_runs(tag) = tag == "c80" ? load_prefix("final_base_s") : load_prefix("sp_$(tag)_s")
function gap_days(tr, te)
    tt = sort(t_rel[tr])
    map(t_rel[te]) do t
        k = searchsortedfirst(tt, t)
        min(k <= length(tt) ? abs(tt[k] - t) : Inf, k > 1 ? abs(t - tt[k-1]) : Inf)
    end
end
function ladder_data()
    map(LADDER) do (tag, nice)
        rs = ladder_runs(tag); r1 = rs[1]; tr, te = r1.tr_idx, r1.te_idx
        cols = [findfirst(==(nm), dot_names_all) for nm in r1.feature_names]
        D = (Fd_raw[:, cols] .- r1.μ') ./ r1.σ'; _, Q = quadratic_terms(r1.feature_names, D)
        fitm(A) = mean(abs2, y[te] .- (A * (A[tr, :] \ y[tr]))[te])
        te_s = [r.te_hist[end] for r in rs]; e = ensemble_pred(rs)
        (; tag, nice, n=length(rs), gap=gap_days(tr, te), te, ens=e,
           null=mean(abs2, y[te] .- mean(y[tr])), lin=fitm(hcat(ones(N), D)), quad=fitm(hcat(ones(N), D, Q)),
           nn_mean=mean(te_s), nn_min=minimum(te_s), nn_max=maximum(te_s), nn_ens=mse_on(e, te))
    end
end
function ladder_table(L)
    DataFrame(split=[l.nice for l in L], seeds=[l.n for l in L],
              median_gap_days=[round(median(l.gap), digits=2) for l in L], max_gap_days=[round(maximum(l.gap), digits=1) for l in L],
              null=sci.([l.null for l in L]), linear=sci.([l.lin for l in L]), lin_quad=sci.([l.quad for l in L]),
              NN_seed_mean=sci.([l.nn_mean for l in L]), NN_ensemble=sci.([l.nn_ens for l in L]),
              rms_pct=[round(100sqrt(l.nn_ens) / median(y[l.te]), digits=2) for l in L],
              median_abs_frac_pct=[round(100median(abs.(l.ens[l.te] .- y[l.te]) ./ y[l.te]), digits=3) for l in L])
end
function ladder_fig(L)
    fig = Figure(size=(1200, 580), fontsize=13); xs = 1:length(L)
    ax = Axis(fig[1, 1], ylabel="test MSE (MJy/sr)²", yscale=log10, xticks=(xs, [l.nice for l in L]),
              xticklabelrotation=π/6, title="Generalization ladder — same recipe on every split (lower is better)")
    scatter!(ax, xs .- 0.24, [l.null for l in L], marker=:hline, markersize=22, color=:gray70, label="null (train mean)")
    scatter!(ax, xs .- 0.12, [l.lin for l in L], marker=:rect, markersize=11, color=:gold, label="linear")
    scatter!(ax, xs, [l.quad for l in L], marker=:diamond, markersize=12, color=:orange, label="linear + quadratic")
    rangebars!(ax, xs .+ 0.12, [l.nn_min for l in L], [l.nn_max for l in L], color=:deepskyblue, whiskerwidth=8)
    scatter!(ax, xs .+ 0.12, [l.nn_mean for l in L], color=:deepskyblue, markersize=11, label="NN single seeds")
    scatter!(ax, xs .+ 0.24, [l.nn_ens for l in L], marker=:star5, color=:limegreen, markersize=17, label="NN ensemble")
    axislegend(ax, position=:lt, labelsize=11); fig
end
function gap_fig(L)
    fig = Figure(size=(900, 520), fontsize=13)
    ax = Axis(fig[1, 1], xlabel="days from the nearest training exposure", ylabel="ensemble MSE in bin (MJy/sr)²",
              xscale=log10, yscale=log10, title="Accuracy vs distance (in time) from the training data — all splits")
    edges = [0; 10 .^ range(-3, log10(120), length=22)]
    for (i, l) in enumerate(L)
        se = (l.ens[l.te] .- y[l.te]) .^ 2; mids = Float64[]; vals = Float64[]
        for b in 1:length(edges)-1
            m = (l.gap .>= edges[b]) .& (l.gap .< edges[b+1]); count(m) >= 200 || continue
            push!(mids, max(sqrt(edges[b] * edges[b+1]), 5e-4)); push!(vals, mean(se[m]))
        end
        isempty(mids) || scatterlines!(ax, mids, vals, color=Makie.wong_colors()[mod1(i, 7)], label=l.nice, markersize=6)
    end
    axislegend(ax, position=:lt, labelsize=10); fig
end

# ---------------------------------------------------------------- 8. output / target transforms
const TARGETS = [("linear output, MSE (baseline)", :linear), ("log target", :log),
                 ("softplus output", :softplus), ("relative-error loss", :relmse)]
target_val_runs(t)  = t === :linear ? load_run.(["v_base_s42", "v_base_s43", "v_base_s44"]) : load_prefix("t_$(t)_val_s")
target_full_runs(t) = t === :linear ? load_prefix("final_base_s") : load_prefix("t_$(t)_full_s")
"""Ensemble of a run group, packaged like a single run (for the verification functions)."""
function as_ensemble(rs, label)
    e = ensemble_pred(rs); r1 = rs[1]
    merge(r1, (; label, ypred=e, tr_hist=[mse_on(e, r1.tr_idx)], te_hist=[mse_on(e, r1.te_idx)],
               va_hist=[isempty(r1.val_idx) ? NaN : mse_on(e, r1.val_idx)]))
end
function target_table()
    df = DataFrame(output=String[], val_seed_mean=String[], val_ensemble=String[], test_seed_mean=String[],
                   test_seed_range=String[], test_ensemble=String[], test_median_abs_frac_pct=Float64[], min_prediction=Float64[])
    for (lbl, t) in TARGETS
        rv = target_val_runs(t); rf = target_full_runs(t); r1 = rf[1]; e = ensemble_pred(rf)
        tes = [r.te_hist[end] for r in rf]
        push!(df, (lbl, sci(mean(r.va_hist[end] for r in rv)), sci(mse_on(ensemble_pred(rv), rv[1].val_idx)),
                   sci(mean(tes)), sci(minimum(tes)) * " – " * sci(maximum(tes)), sci(mse_on(e, r1.te_idx)),
                   round(100median(abs.(e[r1.te_idx] .- y[r1.te_idx]) ./ y[r1.te_idx]), digits=3), round(minimum(e), digits=3)))
    end
    df
end
function target_allsky_table()
    df = DataFrame(output=String[], in_domain_rms=Float64[], in_domain_median_frac_pct=Float64[],
                   out_domain_median_frac_pct=Float64[], near_sun_median_frac_pct=Float64[], negative_predictions=Int[])
    for (lbl, t) in TARGETS
        A = allsky_eval(target_full_runs(t); title=lbl)
        sun = A.elong .< 60
        push!(df, (lbl, round(A.metrics.rms_MJy_sr[1], digits=4), round(A.metrics.median_abs_frac_pct[1], digits=3),
                   round(A.metrics.median_abs_frac_pct[2], digits=2), round(100median(abs.(A.res[sun]) ./ A.yt[sun]), digits=1),
                   A.metrics.negative_predictions[3]))
    end
    df
end

# ---------------------------------------------------------------- 10. all-sky (Rung 3)
"""Evaluate an ensemble on the full HEALPix sky at epoch TINDX. Returns metrics, per-pixel arrays and a figure."""
function allsky_eval(members; TINDX=13170, title="")
    m1 = members[1]
    sky = h5open(allsky_file) do f
        (; emission=read(f["emission"]), pixels=read(f["pixels"]) .+ 1,
           lon=read(f["ecliptic_longitude_deg"]), lat=read(f["ecliptic_latitude_deg"]),
           comps=Dict("smooth cloud" => read(f["emission_smooth_cloud"]), "dust band 1" => read(f["emission_dust_band_1"]),
                      "dust band 2" => read(f["emission_dust_band_2"]), "dust band 3" => read(f["emission_dust_band_3"]),
                      "circumsolar ring" => read(f["emission_circum_solar_ring"]),
                      "Earth-trailing" => read(f["emission_earth_trailing_feature"])))
    end
    np = length(sky.pixels)
    nv = vcat((cosd.(sky.lat) .* cosd.(sky.lon))', (cosd.(sky.lat) .* sind.(sky.lon))', sind.(sky.lat)')
    nms, Fs = dot_features(make_vectors(nv, fill(TINDX, np)))
    Fs = hcat(Fs, extra_columns(nv, fill(TINDX, np))); append!(nms, EXTRA_NAMES)   # same extras as training
    @assert nms == dot_names_all
    cols = [findfirst(==(nm), dot_names_all) for nm in m1.feature_names]
    P = reduce(hcat, [Float64.(predict_y(r, Float32.(((Fs[:, cols] .- r.μ') ./ r.σ')'))) for r in members])
    yp, ys, yt = vec(mean(P, dims=2)), vec(std(P, dims=2)), sky.emission; res = yp .- yt
    indom = trues(np)
    for c in cols; lo, hi = extrema(Fd_raw[m1.tr_idx, c]); indom .&= lo .<= Fs[:, c] .<= hi; end
    Shat = spherex_positions[:, TINDX] ./ sqrt(sum(abs2, spherex_positions[:, TINDX]))
    elong = acosd.(clamp.(-(nv' * Shat), -1, 1))
    rmsv(v) = sqrt(mean(abs2, v))
    metrics = DataFrame(region=["in-domain", "out-of-domain", "whole sky"],
        sky_pct=[100mean(indom), 100mean(.!indom), 100.0],
        rms_MJy_sr=[rmsv(res[indom]), rmsv(res[.!indom]), rmsv(res)],
        median_abs_frac_pct=[100median(abs.(res[m]) ./ yt[m]) for m in (indom, .!indom, trues(np))],
        median_ensemble_std=[median(ys[m]) for m in (indom, .!indom, trues(np))],
        negative_predictions=[count(<(0), yp[m]) for m in (indom, .!indom, trues(np))])
    comps = DataFrame(component=String[], corr_with_residual_in_domain=Float64[])
    for (nm, c) in sort(collect(sky.comps), by=first); push!(comps, (nm, round(cor(res[indom], c[indom]), digits=3))); end
    # Mollweide maps
    hres = Healpix.Resolution(Healpix.npix2nside(np))
    function img(vals; nx=1200, ny=600)
        m = fill(NaN, np); m[sky.pixels] .= vals
        xs = range(-2√2, 2√2, length=nx); yy = range(-√2, √2, length=ny); I = fill(NaN, nx, ny)
        for (j, yv) in enumerate(yy), (i, xv) in enumerate(xs)
            θ = asin(clamp(yv / √2, -1, 1)); lon = -rad2deg(π * xv / (2√2 * cos(θ))); abs(lon) > 180 && continue
            I[i, j] = m[Healpix.ang2pixRing(hres, deg2rad(90 - asind(clamp((2θ + sin(2θ)) / π, -1, 1))), deg2rad(mod(lon, 360)))]
        end
        xs, yy, I
    end
    bkr = ColorSchemes.diverging_bkr_55_10_c35_n256
    fig = Figure(size=(1400, 1150), fontsize=13)
    function panel!(pos, vals, t, cmap, cr, lab)
        ax = Axis(fig[pos...], title=t, aspect=DataAspect()); hidedecorations!(ax); hidespines!(ax)
        hm = heatmap!(ax, img(vals)..., colormap=cmap, colorrange=cr, nan_color=(:grey30, 1.0),
                      lowclip=cgrad(cmap)[0.0], highclip=cgrad(cmap)[1.0])
        Colorbar(fig[pos[1], pos[2] + 1], hm, label=lab, height=Relative(0.8))
    end
    crt = (log10(minimum(yt)), log10(quantile(yt, 0.995))); rl = quantile(abs.(res[indom]), 0.99)
    panel!((1, 1), log10.(yt), "Kelsall truth, log₁₀ MJy/sr (epoch $TINDX)", :inferno, crt, "log₁₀ MJy/sr")
    panel!((1, 3), log10.(max.(yp, 1e-3)), "Ensemble prediction, log₁₀ MJy/sr", :inferno, crt, "log₁₀ MJy/sr")
    panel!((2, 1), ifelse.(indom, res, NaN), "Residual (pred − true), IN-DOMAIN only", bkr, (-rl, rl), "MJy/sr")
    panel!((2, 3), res ./ yt, "Fractional residual, whole sky (clipped ±50%)", bkr, (-0.5, 0.5), "(pred − true)/true")
    panel!((3, 1), log10.(max.(ys, 1e-5)), "Ensemble spread (std across seeds), log₁₀", :viridis, (-3.5, 0.5), "log₁₀ MJy/sr")
    panel!((3, 3), Float64.(indom), "In-domain mask (all features inside training range)", :grays, (0, 1), "in domain")
    Label(fig[0, :], "Rung 3 — all-sky test. " * title, fontsize=17, font=:bold)
    (; metrics, comps, fig, yp, ys, yt, res, indom, elong)
end
