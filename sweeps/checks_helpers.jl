# Round 6 helpers (Earth-centric control + Jupiter null controls) for the 10082026 notebook.
# Requires zodi_setup.jl, mb_train.jl, extra_features.jl, nb_verify_fns.jl, summary_helpers.jl.

# ---------------------------------------------------------------- run groups
const BLK_BASE = ["sp_blk30_s42", "sp_blk30_s43", "sp_blk30_s44"]          # n·J baseline on the block split, seeds 42–44
const A_CHRONO = [("baseline  {n·S, n·E, …}", "v_base_s"), ("Earth-centric  {n·E, n·δ, …}", "v_ec_s")]
const A_BLOCK  = [("baseline  {n·S, n·E, …}", BLK_BASE), ("Earth-centric  {n·E, n·δ, …}", "blk_ec_s")]
const B_CHRONO = [("n·J  (Jupiter)", "v_base_s"), ("n·Jrot45  (fake planet, same motion)", "v_Jrot45_s"),
                  ("n·Jrot90  (fake planet, same motion)", "v_Jrot90_s"), ("n·Jscr  (Jupiter, time-scrambled)", "v_Jscr_s"),
                  ("no Jupiter feature", "v_noJ_s")]
const B_BLOCK  = [("n·J  (Jupiter)", BLK_BASE), ("n·Jrot45  (fake planet, same motion)", "blk_Jrot45_s"),
                  ("n·Jrot90  (fake planet, same motion)", "blk_Jrot90_s"), ("n·Jscr  (Jupiter, time-scrambled)", "blk_Jscr_s"),
                  ("no Jupiter feature", "blk_noJ_s")]
grp_runs(spec) = spec isa String ? load_prefix(spec) : load_run.(spec)

"""Validation/test summary for a list of (label, runs-spec) groups."""
function compare_table(groups)
    df = DataFrame(variant=String[], seeds=Int[], val_ens=String[], test_seed_median=String[], test_seed_range=String[],
                   test_ens=String[], test_ens_median_frac_pct=Float64[], late_test_bias=String[])
    for (lbl, spec) in groups
        rs = grp_runs(spec); r1 = rs[1]; e = ensemble_pred(rs); te = [r.te_hist[end] for r in rs]
        chrono = startswith(r1.split_name, "80/20")
        late = r1.te_idx[t_rel[r1.te_idx] .> maximum(t_rel[r1.te_idx]) - 10]
        push!(df, (lbl, length(rs), isempty(r1.val_idx) ? "—" : sci(mse_on(e, r1.val_idx)), sci(median(te)),
                   sci(minimum(te)) * " – " * sci(maximum(te)), sci(mse_on(e, r1.te_idx)),
                   round(100median(abs.(e[r1.te_idx] .- y[r1.te_idx]) ./ y[r1.te_idx]), digits=3),
                   chrono ? @sprintf("%+.4f", mean(e[late] .- y[late])) : "—"))
    end
    df
end

"""Permutation importance: ensemble MSE on `idx` after shuffling feature `nm` (in standardized units), ÷ unshuffled MSE."""
function perm_importance(rs, idx; nrep=3)
    r1 = rs[1]; cols = [findfirst(==(nm), dot_names_all) for nm in r1.feature_names]
    Xs = [Float32.(((Fd_raw[idx, cols] .- r.μ') ./ r.σ')') for r in rs]
    ens(Xv) = vec(mean(reduce(hcat, [Float64.(predict_y(r, X)) for (r, X) in zip(rs, Xv)]), dims=2))
    base = mean(abs2, ens(Xs) .- y[idx])
    df = DataFrame(feature=String[], mse_ratio_when_shuffled=Float64[])
    rng = Xoshiro(11)
    for (j, nm) in enumerate(r1.feature_names)
        ratios = map(1:nrep) do _
            p = randperm(rng, length(idx))
            Xp = [(Xc = copy(X); Xc[j, :] .= X[j, p]; Xc) for X in Xs]
            mean(abs2, ens(Xp) .- y[idx]) / base
        end
        push!(df, (nm, round(mean(ratios), digits=3)))
    end
    sort!(df, :mse_ratio_when_shuffled, rev=true)
end

"""Linear model on a feature set (train-only standardization): standardized coefficients and test MSE."""
function linear_coefs(feats; split="80/20 Chronological")
    tr, te = splits[split]
    cols = [findfirst(==(nm), dot_names_all) for nm in feats]
    F = Fd_raw[:, cols]; μ = [median(F[tr, j]) for j in axes(F, 2)]; σ = [iqr(F[tr, j]) / 1.34896 for j in axes(F, 2)]
    D = (F .- μ') ./ σ'; A = hcat(ones(N), D); c = A[tr, :] \ y[tr]
    _, Q = quadratic_terms(feats, D); Aq = hcat(ones(N), D, Q); cq = Aq[tr, :] \ y[tr]
    (; table=DataFrame(feature=feats, coefficient_MJy_sr_per_sigma=round.(c[2:end], sigdigits=3)),
       mse_lin=mean(abs2, (A * c)[te] .- y[te]), mse_quad=mean(abs2, (Aq * cq)[te] .- y[te]))
end

"""Physics diagnostics of the Jupiter-like features (what they add beyond the fixed frame, and whether it is a clock)."""
function jupiter_feature_table()
    Xf = hcat(ones(N), nvec_unit_cartesian'); tc = t_rel .- mean(t_rel)
    Xt = hcat(nvec_unit_cartesian' .* tc, nvec_unit_cartesian' .* tc .^ 2)
    tr, te = splits["80/20 Chronological"]
    df = DataFrame(feature=String[], corr_with_nJ=Float64[], moving_part_pct=Float64[], time_drift_R2=Float64[],
                   test_out_of_train_range_pct=Float64[])
    for nm in ("n·J", "n·Jrot45", "n·Jrot90", "n·Jrot180", "n·Jscr")
        f = Fd_raw[:, findfirst(==(nm), dot_names_all)]; m = f .- Xf * (Xf \ f)
        R2 = 1 - sum(abs2, m .- Xt * (Xt \ m)) / sum(abs2, m .- mean(m))
        lo, hi = extrema(f[tr]); v = f[te]
        push!(df, (nm, round(cor(f, Fd_raw[:, findfirst(==("n·J"), dot_names_all)]), digits=4),
                   round(100sqrt(mean(abs2, m)) / std(f), digits=1), round(R2, digits=3), round(100mean((v .< lo) .| (v .> hi)), digits=1)))
    end
    df
end

"""Test-MSE comparison figure: chrono (left) and block (right); ● seed median with range, ★ ensemble."""
function compare_fig(chrono_groups, block_groups; title="")
    fig = Figure(size=(1250, 520), fontsize=13)
    for (c, (groups, sub)) in enumerate(((chrono_groups, "chronological 80/20 (fit 0–100, test 111–140)"),
                                         (block_groups, "30-day alternating blocks (interpolation)")))
        ax = Axis(fig[1, c], ylabel=c == 1 ? "test MSE (MJy/sr)²" : "", yscale=log10, title=sub,
                  xticks=(1:length(groups), [first(split(g[1], "  ")) for g in groups]), xticklabelrotation=π/7)
        for (k, (lbl, spec)) in enumerate(groups)
            rs = grp_runs(spec); te = [r.te_hist[end] for r in rs]
            rangebars!(ax, [k], [minimum(te)], [maximum(te)], color=:deepskyblue, whiskerwidth=10)
            scatter!(ax, [k], [median(te)], color=:deepskyblue, markersize=12)
            scatter!(ax, [k + 0.15], [mse_on(ensemble_pred(rs), rs[1].te_idx)], color=:gold, marker=:star5, markersize=17)
        end
    end
    Label(fig[0, :], title * "   (● seed median, bars = seed range, ★ ensemble)", fontsize=15, font=:bold); fig
end

"""Parallax sanity: how much does the trained ensemble's prediction change if the observer moves from SPHEREx to
Earth's centre (δ → 0 in every δ-dependent feature)? Compared with the physics expectation |δ|·|dlnI/dlnr|."""
function parallax_check(rs; sub=1:20:N)
    r1 = rs[1]; cols = [findfirst(==(nm), dot_names_all) for nm in r1.feature_names]
    F  = Fd_raw[sub, cols]; F0 = copy(F)
    for (j, nm) in enumerate(r1.feature_names)
        nm == "n·δ" && (F0[:, j] .= 0.0)                                         # observer at Earth's centre
        nm == "n·S" && (F0[:, j] .= Fd_raw[sub, findfirst(==("n·E"), dot_names_all)])
    end
    pr(Fm) = vec(mean(reduce(hcat, [Float64.(predict_y(r, Float32.(((Fm .- r.μ') ./ r.σ')'))) for r in rs]), dims=2))
    p, p0 = pr(F), pr(F0); fd = abs.(p0 .- p) ./ p
    δ̄ = mean(sqrt.(sum(δ_vec .^ 2, dims=1)))
    (; median_frac=median(fd), p99_frac=quantile(fd, 0.99), physics_estimate=2δ̄, delta_AU=δ̄)
end
