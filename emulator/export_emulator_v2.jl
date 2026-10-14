# Export emulator v2: the recommended Sun-frame + season inputs, trained on the CORRECTED data (ZodiPy 1.1.5),
# 5-seed ensemble sweeps/results_z115/z115_sunseason_r90_s42..46 (whole mission except a random 10%).
#   julia --project=.. export_emulator_v2.jl
ENV["ZODI_DATA"] = "z115"
using LinearAlgebra; BLAS.set_num_threads(2)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl", "extra_splits.jl"); include(joinpath(@__DIR__, "..", "sweeps", f)); end
using Serialization, JLD2, Dates, SHA
runs = [deserialize(joinpath(RESULTS_DIR, "z115_sunseason_r90_s$s.jls")) for s in 42:46]
r1 = runs[1]
expected = ["n·S", "n·z", "n·E", "n·vS", "n·vE", "n·x⊕", "n·y⊕", "sinλE", "cosλE"]
@assert r1.feature_names == expected
@assert all(r.feature_names == expected && r.μ == r1.μ && r.σ == r1.σ && r.tr_idx == r1.tr_idx for r in runs)
cols = [findfirst(==(nm), dot_names_all) for nm in expected]
lo = vec(minimum(Fd_raw[r1.tr_idx, cols], dims=1)); hi = vec(maximum(Fd_raw[r1.tr_idx, cols], dims=1))
ens = vec(mean(reduce(hcat, [r.ypred for r in runs]), dims=2)); te = r1.te_idx
fe = abs.(ens[te] .- y[te]) ./ y[te]
meta = Dict{String, Any}(
    "version"       => "v2",
    "recipe"        => "Sun-frame + season inputs, 64-64-32-16 gelu MLP, batch 512, Adam one-cycle peak 1e-3, 100 epochs, linear output/MSE",
    "seeds"         => [r.seed for r in runs],
    "training_split"=> "random 90/10 of the 140-day mission (all days)",
    "training_epoch_JD_range" => collect(extrema(times[r1.tr_idx])),
    "target"        => "Kelsall (1998) 5 μm zodiacal emission, ZodiPy 1.1.5 (dirbe), observer = SPHEREx heliocentric — corrected data",
    "target_file_sha256" => open(io -> bytes2hex(sha256(io)), emission_file),
    "frame"         => "barycentric ecliptic, AU",
    "heldout10_median_frac_err" => median(fe), "heldout10_p95_frac_err" => quantile(fe, 0.95),
    "extrapolation_note" => "trained on 140 days: ≤0.1% median up to ~90 days outside the mission, ≤0.84% within 18 months (10142026 notebook)",
    "created"       => string(now()),
    "source_runs"   => ["sweeps/results_z115/z115_sunseason_r90_s$s.jls" for s in 42:46])
out = joinpath(@__DIR__, "zodi_emulator_v2.jld2")
jldsave(out; states=[Flux.state(r.model) for r in runs], hidden=collect(r1.hidden), feature_names=expected,
        mu=r1.μ, sigma=r1.σ, lo, hi, meta)
@printf("wrote %s (%.0f KB); held-out 10%%: median %.4f%%, p95 %.3f%%\n", out, filesize(out) / 1024, 100median(fe), 100quantile(fe, 0.95))
