# Smoke test for the AdamW option (round 40): 2 epochs of a round-40 config, checks that the band layer is not decayed
# and that training runs. ~5 min.   ZODI_DATA=z500 julia --project=. sweeps/smoke_adamw.jl
ENV["ZODI_DATA"] = get(ENV, "ZODI_DATA", "z500")
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl"); include(joinpath(@__DIR__, f)); end
include(joinpath(@__DIR__, "configs_v40.jl"))
kw = CONFIGS["z500h_bandplx_cosexp2k_aw1e-2_shift30_s42"]
r = train_mb(FEATURE_SETS[kw.features]; label="smoke", verbose=false, progress_every=1,
             Base.structdiff(kw, NamedTuple{(:features,)})..., epochs=2)
println("adamw = ", r.adamw, "   test MSE after 2 epochs ", r.te_hist[end])
println("band layer: i = ", r.model.layers[1].i, "  rraw = ", r.model.layers[1].rraw)
println("ok")
