# Round 11 (2026-10-13, overnight): Sun-frame inputs for extrapolation in time. Corrected target only
# (ENV["ZODI_DATA"] = "z115" → sweeps/results_z115/). Same recipe as rounds 9–10.
#   arms : sunframe (n·S n·z n·E n·vS n·vE n·x⊕ n·y⊕) | + sin/cos λ⊕ | + cloud geometry (n·ĉ, Zc, Rc)
#   tests: random 90/10 (→ the synthetic future set) and 30-day blocks (in-mission interpolation must not get worse)
# References from round 10 (configs_z115.jl): z115_{base,season,novS,noJ}_{r90,blk}.
include(joinpath(@__DIR__, "extra_splits.jl"))
@assert ZODI_DATA == "z115" "configs_v11.jl is for the corrected data: set ENV[\"ZODI_DATA\"] = \"z115\" first"
const R11 = (; arch=:mlp, hidden=(64, 64, 32, 16), batchsize=512, epochs=100, schedule=:onecycle, lr_max=1e-3)
const ARMS11  = [("sun", :sunframe), ("sunseason", :sunframe_season), ("suncloud", :sunframe_cloud), ("suncloudZ", :sunframe_cloudZ)]
const TESTS11 = [("r90", "random 90/10"), ("blk", "30 day split")]
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46, (arm, fs) in ARMS11, (test, sp) in TESTS11
    CONFIGS["z115_$(arm)_$(test)_s$s"] = (; R11..., features=fs, split_name=sp, seed=s)
end
