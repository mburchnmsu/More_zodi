# Round 44b (Nov 4): round 44's injection positive control (configs_v44.jl) for a third model, the best model WITHOUT
# n·S. n·S leaks the Earth-limb direction into the base model (n·δ̂ = (n·S − n·E)/|δ|), so this is the model that truly
# lacks it. Same split, seeds and schedule; one job per injected amplitude:
#     ZODI_INJECT=1e-2 sbatch ... pipeline/cluster/threaded.sbatch sweeps/configs_v44b.jl     (and 1e-3)
@assert ZODI_HELIO "configs_v44b.jl is for heliocentric inputs"
@assert INJECT_A > 0 "configs_v44b.jl needs ENV[\"ZODI_INJECT\"] (the injected amplitude)"
include(joinpath(@__DIR__, "configs_v24.jl"))
CONFIGS = Dict{String, NamedTuple}()
for s in 42:44
    CONFIGS["z500h_inj$(INJECT_A)_bandplx_noS_cosexp1k_shift0_s$s"] = (; R24..., epochs=1000, arch=:bandplx,
                                                                     features=:sunseason_learnband_plx_noS,
                                                                     schedule=:cosexpw, lr_max=2e-3, sched_kw=(; decay=3.0, warm=0.05),
                                                                     split_name=split_name24(0), seed=s)
end
