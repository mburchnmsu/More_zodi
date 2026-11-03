# Smoke test for best-epoch selection (round 42) and a regression check of the old path. ~5–10 min.
#   julia --project=. sweeps/smoke_best.jl
# 1. 2 epochs of a round-40 config must give exactly the cluster smoke test's number (job 691126): 2.3985878215171397e-4.
# 2. 3 epochs of a round-42 config: validation window inside the training windows, best epoch restored, te_best = test MSE
#    of the returned predictions.
ENV["ZODI_DATA"] = get(ENV, "ZODI_DATA", "z500")
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl"); include(joinpath(@__DIR__, f)); end
run(kw; epochs) = train_mb(FEATURE_SETS[kw.features]; label="smoke", verbose=false, progress_every=1,
                           Base.structdiff(kw, NamedTuple{(:features,)})..., epochs)
include(joinpath(@__DIR__, "configs_v40.jl"))
r = run(CONFIGS["z500h_bandplx_cosexp2k_aw1e-2_shift30_s42"]; epochs=2)
println("1. old path: test MSE ", r.te_hist[end], "  identical to cluster smoke: ", r.te_hist[end] == 0.00023985878215171397)
include(joinpath(@__DIR__, "configs_v42.jl"))
kw = CONFIGS["z500h_bandplx_cosexp2k_best_shift30_s42"]
r = run(kw; epochs=3)
tv = t_rel[r.val_idx]; Δ = 30
println("2. val: ", length(r.val_idx), " exposures, t_rel ", extrema(tv), "; train ", length(r.tr_idx), ", test ", length(r.te_idx))
println("   val ∩ train = ", length(intersect(r.val_idx, r.tr_idx)), ", val ∩ test = ", length(intersect(r.val_idx, r.te_idx)),
        ", val inside training windows: ", all(iseven, floor.(Int, (tv .- Δ) ./ 30)))
println("   va_hist ", r.va_hist[2:end], "  best_epoch ", r.best_epoch, " (argmin ", argmin(r.va_hist[2:end]), ")")
println("   te_best ", r.te_best, "  = MSE of returned ypred on test: ",
        isapprox(r.te_best, mean(abs2, Float32.(r.ypred[r.te_idx]) .- Float32.(y[r.te_idx])); rtol=1e-4),
        "  te_hist at best ", r.te_hist[r.best_epoch + 1])
println("ok")
