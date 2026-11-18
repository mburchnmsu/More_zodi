# Round 47b (Nov 17): round 44's positive control (fake Earthshine + moonlight injected into the target, see
# sweeps/extra_features.jl ZODI_INJECT) for the round-47 Earth-only models, without and with n·δ̂, n·M̂. A model that truly
# lacks the Earth-limb direction should NOT learn the injected Earthshine (round 44: the old base learned 98% of it).
#     ZODI_INJECT=1e-2 sbatch ... sweeps/configs_v47b.jl
@assert ZODI_HELIO "configs_v47b.jl is for heliocentric inputs"
@assert INJECT_A > 0 "configs_v47b.jl needs ENV[\"ZODI_INJECT\"] (the injected amplitude)"
include(joinpath(@__DIR__, "configs_v24.jl"))
CONFIGS = Dict{String, NamedTuple}()
for s in 42:44, (tag, feats) in (("eonly", :earthonly_learnband_plx), ("eonlyc", :earthonly_learnband_plx_earthc))
    CONFIGS["z500h_inj$(INJECT_A)_bandplx_$(tag)_cosexp1k_shift0_s$s"] = (; R24..., epochs=1000, arch=:bandplx, features=feats,
                                                                       schedule=:cosexpw, lr_max=2e-3, sched_kw=(; decay=3.0, warm=0.05),
                                                                       split_name=split_name24(0), seed=s)
end
