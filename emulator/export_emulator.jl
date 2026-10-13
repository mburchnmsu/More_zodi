# Export the final recommended model (5-seed ensemble, sweeps/results/final_base_s42..46) to a portable
# JLD2 file: plain weight arrays (Flux.state), normalization constants, feature training ranges, metadata.
#   julia --project=.. export_emulator.jl
using LinearAlgebra; BLAS.set_num_threads(2)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl"); include(joinpath(@__DIR__, "..", "sweeps", f)); end
using Serialization, JLD2, Dates
RES = joinpath(@__DIR__, "..", "sweeps", "results")
runs = [deserialize(joinpath(RES, "final_base_s$s.jls")) for s in 42:46]
r1 = runs[1]
expected = ["n·S", "n·z", "n·E", "n·vS", "n·vE", "n·J", "n·x", "n·y"]
@assert r1.feature_names == expected
@assert all(r.feature_names == expected && r.μ == r1.μ && r.σ == r1.σ && r.tr_idx == r1.tr_idx for r in runs)
cols = [findfirst(==(nm), dot_names_all) for nm in expected]
lo = vec(minimum(Fd_raw[r1.tr_idx, cols], dims=1)); hi = vec(maximum(Fd_raw[r1.tr_idx, cols], dims=1))
ens = vec(mean(reduce(hcat, [r.ypred for r in runs]), dims=2))
meta = Dict{String, Any}(
    "recipe"        => "n·* features, 64-64-32-16 gelu MLP, batch 512, Adam one-cycle peak 1e-3, 100 epochs, linear output/MSE",
    "seeds"         => [r.seed for r in runs],
    "training_days" => collect(extrema(t_rel[r1.tr_idx])),
    "training_epoch_JD_range" => collect(extrema(times[r1.tr_idx])),
    "target"        => "Kelsall (1998) 5 μm zodiacal emission via ZodiPy, MJy/sr",
    "frame"         => "barycentric ecliptic, AU",
    "test_mse_80_20_ensemble" => mean(abs2, ens[r1.te_idx] .- y[r1.te_idx]),
    "allsky_in_domain_median_frac_err" => 0.0054,
    "created"       => string(now()),
    "source_runs"   => ["sweeps/results/final_base_s$s.jls" for s in 42:46])
out = joinpath(@__DIR__, "zodi_emulator_v1.jld2")
jldsave(out; states=[Flux.state(r.model) for r in runs], hidden=collect(r1.hidden), feature_names=expected,
        mu=r1.μ, sigma=r1.σ, lo, hi, meta)
@printf("wrote %s (%.0f KB)\n", out, filesize(out) / 1024)
