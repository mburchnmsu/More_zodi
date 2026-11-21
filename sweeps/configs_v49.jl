# Round 49 (Week 15 card, Nov 20): can the model work without measuring the angle of direction? Plain MLP (both band
# layers need the x̂, ŷ components, which the card removes), cos×exp 1000 epochs, all 6 shifts × 2 seeds:
#   inv   :card_invariant  — n·z, n·S, S·z, S·S: the rotation-invariant reading of "ẑ, pointing vector, sphex" (recommended)
#   lit   :card_literal    — n·x, n·y, n·z, S·z: the literal reading (pointing vector components + SPHEREx's height)
#   ref   :sunframe_season — the poster inputs (all Earth/orbit information), same network and schedule, as the reference
# ZODI_DATA=z500 (ZODI_HELIO defaults to 1). Report: EARTH2D_SET=r49 julia --project=. sweeps/earth2d.jl
@assert ZODI_HELIO "configs_v49.jl is for heliocentric inputs"
include(joinpath(@__DIR__, "configs_v24.jl"))
CONFIGS = Dict{String, NamedTuple}()
for s in 42:43, Δ in SHIFTS24, (tag, feats) in (("inv", :card_invariant), ("lit", :card_literal), ("ref", :sunframe_season))
    CONFIGS["z500h_mlp_$(tag)_cosexp1k_shift$(Δ)_s$s"] = (; R24..., epochs=1000, arch=:mlp, features=feats,
                                                         schedule=:cosexpw, lr_max=2e-3, sched_kw=(; decay=3.0, warm=0.05),
                                                         split_name=split_name24(Δ), seed=s)
end
