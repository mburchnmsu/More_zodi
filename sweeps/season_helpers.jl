# Round 7 helpers (season features; log target revisited) for the 10092026 notebook.
# Requires zodi_setup.jl, mb_train.jl, extra_features.jl, nb_verify_fns.jl, summary_helpers.jl, checks_helpers.jl.

# ---------------------------------------------------------------- #1 season features
const S_BLOCK  = [("baseline n·*", "sp_blk30_s"), ("n·* + sin/cos λ⊕", "se_blk_s")]
const S_RANDOM = [("baseline n·*", ["sp_rand_s42", "sp_rand_s43", "sp_rand_s44"]), ("n·* + sin/cos λ⊕", "se_rand_s")]
const S_CHRONO = [("baseline n·*", "v_base_s"), ("n·* + sin/cos λ⊕", "v_season_s")]

"""Spread of fractional errors near each ecliptic pole on the TEST rows of an ensemble."""
function pole_table(groups)
    df = DataFrame(model=String[], pole=String[], n=Int[], median_pct=Float64[], p05_pct=Float64[], p95_pct=Float64[],
                   rms_pct=Float64[])
    for (lbl, spec) in groups
        rs = grp_runs(spec); te = rs[1].te_idx; e = ensemble_pred(rs)
        fe = (e[te] .- y[te]) ./ y[te]; z = nvec_unit_cartesian[3, te]
        for (pn, s) in (("north", 1), ("south", -1)), (a, b) in ((0, 2), (2, 10))
            m = (acosd.(clamp.(s .* z, -1, 1)) .>= a) .& (acosd.(clamp.(s .* z, -1, 1)) .< b)
            count(m) > 30 || continue
            push!(df, (lbl, "$pn $(a)–$(b)°", count(m), round(100median(fe[m]), digits=3), round(100quantile(fe[m], 0.05), digits=2),
                       round(100quantile(fe[m], 0.95), digits=2), round(100sqrt(mean(abs2, fe[m])), digits=3)))
        end
    end
    df
end

"""North/south mirror asymmetry on the all-sky map: does the model reproduce Kelsall's (cloud-tilt) asymmetry?"""
function ns_asymmetry(A; nside_pix=nothing)
    sky = h5open(allsky_file) do f; (; lon=read(f["ecliptic_longitude_deg"]), lat=read(f["ecliptic_latitude_deg"]), pix=read(f["pixels"]) .+ 1) end
    hres = Healpix.Resolution(Healpix.npix2nside(length(sky.pix)))
    lookup = zeros(Int, length(sky.pix)); lookup[sky.pix] .= 1:length(sky.pix)
    mirror = [lookup[Healpix.ang2pixRing(hres, deg2rad(90 + sky.lat[i]), deg2rad(mod(sky.lon[i], 360)))] for i in eachindex(sky.lat)]
    pair = A.indom .& A.indom[mirror] .& (sky.lat .> 5)
    dN(v) = ((v .- v[mirror]) ./ ((v .+ v[mirror]) ./ 2))[pair]
    dm, dt = dN(A.yp), dN(A.yt)
    hi = sky.lat[pair] .>= 60
    (; pairs=count(pair), model_mean_pct=100mean(dm), truth_mean_pct=100mean(dt), pattern_corr=cor(dm, dt),
       amplitude_ratio=dt \ dm, highlat_model_pct=100median(abs.(dm[hi])), highlat_truth_pct=100median(abs.(dt[hi])))
end

"""Ecliptic-pole exposures through the mission: truth vs two ensembles (fit on `groups`' split)."""
function pole_series_fig(groups; title="")
    fig = Figure(size=(1250, 620), fontsize=13)
    for (c, (pn, s)) in enumerate((("north", 1), ("south", -1)))
        ax = Axis(fig[1, c], xlabel="days since first exposure", ylabel=c == 1 ? "MJy/sr" : "",
                  title="$pn ecliptic pole (within 5°)")
        idx = findall(acosd.(clamp.(s .* nvec_unit_cartesian[3, :], -1, 1)) .< 5)
        idx = idx[sortperm(t_rel[idx])][1:4:end]
        scatter!(ax, t_rel[idx], y[idx], markersize=3, color=(:white, 0.7), label="Kelsall truth")
        for (k, (lbl, spec)) in enumerate(groups)
            rs = grp_runs(spec); e = ensemble_pred(rs)
            scatter!(ax, t_rel[idx], e[idx], markersize=2, color=([:orangered, :limegreen][k], 0.6), label=lbl)
        end
        r1 = grp_runs(groups[1][2])[1]
        is_te = falses(N); is_te[r1.te_idx] .= true
        # shade test periods
        tt = sort(t_rel[r1.te_idx]); edges = [tt[1]]; for i in 2:length(tt); tt[i] - tt[i-1] > 1 && (push!(edges, tt[i-1]); push!(edges, tt[i])); end; push!(edges, tt[end])
        for i in 1:2:length(edges)-1; vspan!(ax, [edges[i]], [edges[i+1]], color=(:gray, 0.15)); end
        c == 1 && axislegend(ax, position=:lt, markersize=8)
    end
    Label(fig[0, :], title * "  (grey bands = test periods)", fontsize=15, font=:bold); fig
end

# ---------------------------------------------------------------- #3 log target revisited
lin10() = vcat(load_prefix("final_base_s"), load_prefix("x10_lin_full_s"))       # seeds 42–51
log10s() = vcat(load_prefix("t_log_full_s"), load_prefix("x10_log_full_s"))      # seeds 42–51
const T_CHRONO = [("linear (10 seeds)", :lin10), ("log target (10 seeds)", :log10),
                  ("mixed α=0.25 (5 seeds)", "t_mix025_full_s"), ("mixed α=1 (5 seeds)", "t_mix1_full_s")]
const T_BLOCK  = [("linear", "sp_blk30_s"), ("log target", "blk_log_s"),
                  ("mixed α=0.25", "blk_mix025_s"), ("mixed α=1", "blk_mix1_s")]
trun(spec) = spec === :lin10 ? lin10() : spec === :log10 ? log10s() : grp_runs(spec)

function target_compare(groups)
    df = DataFrame(output=String[], seeds=Int[], test_seed_median=String[], test_seed_IQR=String[], test_seed_max=String[],
                   test_ens=String[], ens_median_frac_pct=Float64[], ens_p95_frac_pct=Float64[], late_bias=String[])
    for (lbl, spec) in groups
        rs = trun(spec); r1 = rs[1]; e = ensemble_pred(rs); te = [r.te_hist[end] for r in rs]; fe = abs.(e[r1.te_idx] .- y[r1.te_idx]) ./ y[r1.te_idx]
        chrono = startswith(r1.split_name, "80/20"); late = r1.te_idx[t_rel[r1.te_idx] .> maximum(t_rel[r1.te_idx]) - 10]
        push!(df, (lbl, length(rs), sci(median(te)), sci(quantile(te, 0.25)) * " – " * sci(quantile(te, 0.75)), sci(maximum(te)),
                   sci(mse_on(e, r1.te_idx)), round(100median(fe), digits=3), round(100quantile(fe, 0.95), digits=2),
                   chrono ? @sprintf("%+.4f", mean(e[late] .- y[late])) : "—"))
    end
    df
end

"""Same-seed comparison: does the log target beat linear for each initialization?"""
function paired_seeds()
    L = Dict(r.seed => r.te_hist[end] for r in lin10()); G = Dict(r.seed => r.te_hist[end] for r in log10s())
    s = sort(collect(intersect(keys(L), keys(G))))
    df = DataFrame(seed=s, linear=sci.([L[k] for k in s]), log_target=sci.([G[k] for k in s]),
                   ratio_log_over_lin=round.([G[k] / L[k] for k in s], digits=2))
    (; df, log_wins=count(G[k] < L[k] for k in s), n=length(s), geo_mean_ratio=exp(mean(log(G[k] / L[k]) for k in s)))
end

function seed_strip_fig(chrono_groups, block_groups)
    fig = Figure(size=(1250, 500), fontsize=13)
    for (c, (groups, ttl)) in enumerate(((chrono_groups, "chronological 80/20 (fit days 0–111.4)"), (block_groups, "30-day blocks (interpolation)")))
        ax = Axis(fig[1, c], ylabel=c == 1 ? "test MSE (MJy/sr)²" : "", yscale=log10, title=ttl,
                  xticks=(1:length(groups), first.(groups)), xticklabelrotation=π/9)
        for (k, (lbl, spec)) in enumerate(groups)
            rs = trun(spec); te = [r.te_hist[end] for r in rs]
            scatter!(ax, k .+ 0.08 .* randn(Xoshiro(k), length(te)), te, color=(:deepskyblue, 0.8), markersize=10)
            scatter!(ax, [k + 0.3], [mse_on(ensemble_pred(rs), rs[1].te_idx)], color=:gold, marker=:star5, markersize=18)
        end
    end
    Label(fig[0, :], "Output choice: every seed (●) and the seed ensemble (★)", fontsize=15, font=:bold); fig
end
