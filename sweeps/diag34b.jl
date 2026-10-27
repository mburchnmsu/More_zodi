# Shift-30 follow-up: per-seed test-loss trajectory (minimum and where, vs final) and test MSE per withheld window.
#     julia --project=. sweeps/diag34b.jl [shift]
ENV["ZODI_DATA"] = "z500"; ENV["ZODI_HELIO"] = "1"
using LinearAlgebra; BLAS.set_num_threads(2)
redirect_stdout(devnull) do
    include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
    for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "shift_helpers.jl"); include(joinpath(@__DIR__, f)); end
end
Δ = isempty(ARGS) ? 30 : parse(Int, ARGS[1])
for fam in ("z500h_bandplx_kelsall_shift$Δ", "z500h_bandplx2k_shift$Δ")
    rs = runs16(fam); te = rs[1].te_idx
    tt = t_rel[te]; o = sortperm(tt); cut = findall(diff(tt[o]) .> 3)          # split the withheld set into windows
    wins = [o[a:b] for (a, b) in zip([1; cut .+ 1], [cut; length(o)])]
    println("== $fam   windows (days): ", join((@sprintf("%.0f–%.0f", tt[w[1]], tt[w[end]]) for w in wins), ", "))
    for r in rs
        k = argmin(r.te_fine)
        @printf("  seed %d  test min %.2e at epoch %.0f, final %.2e | per-window MSE (e-8):", r.seed, r.te_fine[k], r.fine_epoch[k], r.te_fine[end])
        d = r.ypred[te] .- y[te]
        for w in wins; @printf(" %.1f", 1e8 * mean(abs2, d[w])); end
        println()
    end
end
