# Round 42 report: best-epoch selection (validation window k = 8, keep_best; Discovery) vs cos×exp 2000 (round 39), shifts
# 0, 30, 40. Ensemble test MSE at the best epoch and at the last epoch (te_hist), best epochs, and test MSE per withheld
# window: the validation window leaves a 90-day hole (test window 7, validation 8, test 9) in the training data.
#     julia --project=. sweeps/report42.jl
ENV["ZODI_DATA"] = "z500"; ENV["ZODI_HELIO"] = "1"
using LinearAlgebra; BLAS.set_num_threads(2)
redirect_stdout(devnull) do
    include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
    for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "shift_helpers.jl"); include(joinpath(@__DIR__, f)); end
    include(joinpath(@__DIR__, "configs_v24.jl"))
end
const FAMS = (("z500h_bandplx_cosexp2k_shift", "cos×exp 2000 (r39)"), ("z500h_bandplx_cosexp2k_best_shift", "best epoch (r42)"))
done = [0, 30, 40]
@assert all(length(runs16("$(f)$Δ")) == 5 for (f, _) in FAMS, Δ in done)
win(Δ, idx) = floor.(Int, (t_rel[idx] .- Δ) ./ 30)
for Δ in done
    println("\n=== shift $Δ ===")
    for (f, lbl) in FAMS
        rs = runs16("$f$Δ"); te = rs[1].te_idx; e = ensemble_pred(rs); k = win(Δ, te)
        seeds = [mean(abs2, r.ypred[te] .- y[te]) for r in rs]
        @printf("%-20s ensemble %.2f  per seed %s\n", lbl, 1e8mean(abs2, e[te] .- y[te]), join((@sprintf("%.2f", 1e8x) for x in seeds), " "))
        if get(rs[1], :keep_best, false)
            @printf("%-20s best epochs %s; last-epoch test per seed %s; train %d (r39 had %d), val %d\n", "",
                    join((r.best_epoch for r in rs), " "), join((@sprintf("%.2f", 1e8r.te_hist[end]) for r in rs), " "),
                    length(rs[1].tr_idx), length(runs16("$(FAMS[1][1])$Δ")[1].tr_idx), length(rs[1].val_idx))
        end
        @printf("%-20s per test window: %s\n", "", join((@sprintf("k%d %.2f", w, 1e8mean(abs2, e[te[k .== w]] .- y[te[k .== w]]))
                                                       for w in sort(unique(k))), "  "))
    end
    empty!(_R16)
end
println("ok")
