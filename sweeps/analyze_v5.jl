# Round 5: what does n·J contribute? Validation protocol (fit 0–100, val 100–111.4, test 111.4–139.7), 5 seeds.
using LinearAlgebra; BLAS.set_num_threads(2)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl", "nb_verify_fns.jl", "summary_helpers.jl"); include(joinpath(@__DIR__, f)); end
groups = [("n·J (baseline)", "v_base_s"), ("n·Ĵ moving unit vector", "v_Junit_s"), ("n·Ĵfix fixed axis (≈ n·y)", "v_Jfix_s"),
          ("n·Ĵ⊥fix control axis (≈ −n·x)", "v_Jperp_s"), ("no Jupiter feature", "v_noJ_s")]
df = DataFrame(variant=String[], seeds=Int[], val_seed_mean=String[], val_ens=String[], test_seed_median=String[],
               test_seed_range=String[], test_ens=String[], late_bias=Float64[], bad_seeds=Int[])
for (lbl, pre) in groups
    rs = load_prefix(pre); r1 = rs[1]; e = ensemble_pred(rs); te = [r.te_hist[end] for r in rs]
    late = r1.te_idx[t_rel[r1.te_idx] .> maximum(t_rel[r1.te_idx]) - 10]
    push!(df, (lbl, length(rs), sci(mean(r.va_hist[end] for r in rs)), sci(mse_on(e, r1.val_idx)), sci(median(te)),
               sci(minimum(te)) * " – " * sci(maximum(te)), sci(mse_on(e, r1.te_idx)), round(mean(e[late] .- y[late]), digits=4),
               count(>(2e-3), te)))
end
show(stdout, MIME("text/plain"), df); println()
# how much "time" does each candidate feature carry? correlation of the feature with t_rel at fixed look direction is
# not well defined, so use: residual variance of the feature after regressing on n·x, n·y, n·z (what the axis adds
# beyond the fixed inertial frame) and that residual's correlation with time
X = hcat(ones(N), nvec_unit_cartesian')
for nm in ("n·J", "n·Ĵ", "n·Ĵfix", "n·Ĵ⊥fix")
    f = Fd_raw[:, findfirst(==(nm), dot_names_all)]
    r = f .- X * (X \ f)
    @printf("%-8s: part NOT explained by (n·x, n·y, n·z): rms %.2e (feature rms %.2e); corr(that part × sign, time) = %+.2f\n",
            nm, sqrt(mean(abs2, r)), sqrt(mean(abs2, f)), cor(abs.(r), t_rel))
end
println("\nround 5 analysis done")
