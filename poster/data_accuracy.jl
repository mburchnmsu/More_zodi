# Poster data, part 1: accuracy of the poster's model (Sun frame + season inputs = emulator v2 inputs, 5-network
# ensemble) on pointings it never saw in training →  poster/fig_accuracy.jld2
#   * main test ("blk"): trained on mission days 0–30, 60–90, 120–140; tested on the two withheld 30-day blocks
#     (days 30–60 and 90–120)  — z115_sunseason_blk_s42..46
#   * easy test ("r90"): a random 10% of pointings withheld — the packaged emulator v2 (zodi_emulator_v2.jld2,
#     trained on z115_sunseason_r90_s42..46), evaluated through the module
#   julia --project=. poster/data_accuracy.jl
ENV["ZODI_DATA"] = "z115"
using LinearAlgebra; BLAS.set_num_threads(2)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl", "extra_splits.jl", "summary_helpers.jl"); include(joinpath(@__DIR__, "..", "sweeps", f)); end
include(joinpath(@__DIR__, "..", "emulator", "ZodiEmulator.jl")); using .ZodiEmulator
using Serialization, JLD2

days = times .- minimum(times)                                  # mission day of each exposure
# random 10% (packaged emulator v2)
em = load_emulator(joinpath(@__DIR__, "..", "emulator", "zodi_emulator_v2.jld2"))
te = deserialize(joinpath(RESULTS_DIR, "z115_sunseason_r90_s42.jls")).te_idx
o = predict_zodi(em, nvec_unit_cartesian[:, te]; S=spherex_positions[:, te], E=earth_positions[:, te], vS=v_spherex[:, te], vE=v_earth[:, te])
fr = 100 .* (o.mean .- y[te]) ./ y[te]
# whole 30-day blocks withheld
# poster v6 (Oct 18): the 750-epoch runs of the same split (round 21); v1–v5 used z115_sunseason_blk (100 epochs)
const BLK = get(ENV, "POSTER_BLK", "z115_m750_shift0")
rs = [deserialize(joinpath(RESULTS_DIR, "$(BLK)_s$s.jls")) for s in 42:46]
@assert all(r.feature_names == em.features for r in rs)
tb = rs[1].te_idx; eb = ensemble_pred(rs)
fb = 100 .* (eb[tb] .- y[tb]) ./ y[tb]
istest = falses(N); istest[tb] .= true
dgrid = 0:0.25:ceil(maximum(days))                              # train/test status along the mission, for the timeline
status = [any(istest[(days .>= a) .& (days .< a + 0.25)]) for a in dgrid[1:end-1]]
jldsave(joinpath(@__DIR__, "fig_accuracy.jld2"); ytrue=y[tb], ypred=eb[tb], err_pct=fb, days_test=days[tb],
        err_pct_random=fr, dgrid=collect(dgrid), test_status=status, mission_days=maximum(days))
for (lbl, e) in (("30-day blocks", fb), ("random 10%", fr))
    @printf("%-14s %6d pointings: median |err| %.4f%%, p95 %.3f%%, within 0.1%%: %.1f%%\n", lbl, length(e),
            median(abs.(e)), quantile(abs.(e), 0.95), 100mean(abs.(e) .< 0.1))
end
