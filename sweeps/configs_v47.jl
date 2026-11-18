# Round 47 (Nov 17, user): with vs without Earth, done properly. The Week 13 "without Earth" model (rounds 37–38) still
# had the Earth-limb direction (n·δ̂ = linear function of n·S, n·E). Here both models use only Earth-based geometry
# (FEATURE_SETS[:earthonly_learnband_plx], see sweeps/extra_features.jl); "with" adds n·δ̂ and n·M̂ and nothing else.
# Best model otherwise (parallax band layer, cos×exp 1000 epochs), all 6 shifts × 2 seeds so every month is withheld once
# (sweeps/earth2d.jl maps).   ZODI_DATA=z500 (ZODI_HELIO defaults to 1)
@assert ZODI_HELIO "configs_v47.jl is for heliocentric inputs"
include(joinpath(@__DIR__, "configs_v24.jl"))
CONFIGS = Dict{String, NamedTuple}()
for s in 42:43, Δ in SHIFTS24, (tag, feats) in (("eonly", :earthonly_learnband_plx), ("eonlyc", :earthonly_learnband_plx_earthc))
    CONFIGS["z500h_bandplx_$(tag)_cosexp1k_shift$(Δ)_s$s"] = (; R24..., epochs=1000, arch=:bandplx, features=feats,
                                                            schedule=:cosexpw, lr_max=2e-3, sched_kw=(; decay=3.0, warm=0.05),
                                                            split_name=split_name24(Δ), seed=s)
end
