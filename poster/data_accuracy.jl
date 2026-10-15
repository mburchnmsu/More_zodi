# Poster data, part 1: emulator v2 on the exposures it never saw in training (random 10% of the mission,
# te_idx of z115_sunseason_r90_*), via the packaged module.   julia --project=. poster/data_accuracy.jl → poster/fig_accuracy.jld2
ENV["ZODI_DATA"] = "z115"
using LinearAlgebra; BLAS.set_num_threads(2)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl", "extra_splits.jl"); include(joinpath(@__DIR__, "..", "sweeps", f)); end
include(joinpath(@__DIR__, "..", "emulator", "ZodiEmulator.jl")); using .ZodiEmulator
using Serialization, JLD2

em = load_emulator(joinpath(@__DIR__, "..", "emulator", "zodi_emulator_v2.jld2"))
te = deserialize(joinpath(RESULTS_DIR, "z115_sunseason_r90_s42.jls")).te_idx
o = predict_zodi(em, nvec_unit_cartesian[:, te]; S=spherex_positions[:, te], E=earth_positions[:, te], vS=v_spherex[:, te], vE=v_earth[:, te])
fe = 100 .* (o.mean .- y[te]) ./ y[te]                   # signed % error
jldsave(joinpath(@__DIR__, "fig_accuracy.jld2"); ytrue=y[te], ypred=o.mean, err_pct=fe, lat=ecliptic_latitude_deg[te],
        lon=ecliptic_longitude_deg[te], days=times[te] .- minimum(times))
@printf("held-out %d exposures: median |err| %.4f%%, p95 %.3f%%, max %.3f%%, within 0.1%%: %.1f%%\n", length(te),
        median(abs.(fe)), quantile(abs.(fe), 0.95), maximum(abs.(fe)), 100mean(abs.(fe) .< 0.1))
