# Why is shift 30's 2000-epoch ensemble MSE worse than 500 epochs while its typical error is better?
# Per-seed test MSE, median/p99 relative error, and where the squared error sits (top pointings, by test window).
#     julia --project=. sweeps/diag34_shift30.jl [shift]
ENV["ZODI_DATA"] = "z500"; ENV["ZODI_HELIO"] = "1"
using LinearAlgebra; BLAS.set_num_threads(2)
redirect_stdout(devnull) do
    include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
    for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "shift_helpers.jl"); include(joinpath(@__DIR__, f)); end
end
Δ = isempty(ARGS) ? 30 : parse(Int, ARGS[1])
for fam in ("z500h_bandplx_kelsall_shift$Δ", "z500h_bandplx2k_shift$Δ")
    rs = runs16(fam); te = rs[1].te_idx
    println("== $fam")
    for r in rs
        d = r.ypred[te] .- y[te]; rel = abs.(100 .* d ./ y[te])
        @printf("  seed %d  test MSE %.3e  median %.4f%%  p99 %.3f%%  max %.2f%%  final train/test fine %.2e / %.2e\n",
                r.seed, mean(abs2, d), median(rel), quantile(rel, 0.99), maximum(rel), r.tr_fine[end], r.te_fine[end])
    end
    e = ensemble_pred(rs); d = e[te] .- y[te]; rel = abs.(100 .* d ./ y[te])
    @printf("  ensemble MSE %.3e  median %.4f%%  p99 %.3f%%  max %.2f%%\n", mean(abs2, d), median(rel), quantile(rel, 0.99), maximum(rel))
    o = sortperm(abs2.(d), rev=true); k = o[1:20]
    @printf("  top-20 pointings hold %.0f%% of the squared error; top-0.1%% hold %.0f%%\n",
            100 * sum(abs2, d[k]) / sum(abs2, d), 100 * sum(abs2, d[o[1:cld(length(o), 1000)]]) / sum(abs2, d))
    for j in o[1:8]
        i = te[j]
        @printf("    t=%8.2f d  λ=%6.1f°  β=%6.2f°  y=%.3f  pred=%.3f  (%.2f%%)\n", t_rel[i], ecliptic_longitude_deg[i],
                ecliptic_latitude_deg[i], y[i], e[i], 100 * d[j] / y[i])
    end
end
