using LinearAlgebra; BLAS.set_num_threads(1)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
include(joinpath(@__DIR__, "mb_train.jl"))
include(joinpath(@__DIR__, "extra_features.jl"))
for tgt in (:linear, :log, :softplus, :relmse)
    r = train_mb(FEATURE_SETS[:look_dir]; target=tgt, epochs=2, batchsize=512, lr_max=1e-3, schedule=:onecycle,
                 hidden=(64, 64, 32, 16), seed=42, val_days=100.0, verbose=false)
    # independent check: recompute test MSE from predict_y on fresh features
    cols = [findfirst(==(nm), dot_names_all) for nm in r.feature_names]
    X = Float32.(((Fd_raw[:, cols] .- r.μ') ./ r.σ')')
    yp = Float64.(predict_y(r, X))
    @assert isapprox(mean(abs2, yp[r.te_idx] .- y[r.te_idx]), r.te_hist[end]; rtol=1e-3)
    @assert yp ≈ r.ypred
    @printf("%-9s val %.3e  test %.3e  min pred %.3f  (predict_y consistent)\n", tgt, r.va_hist[end], r.te_hist[end], minimum(r.ypred))
end
