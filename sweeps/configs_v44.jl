# Round 44 (Nov 4): positive control for the Earth-centric inputs. The target gets fake Earthshine + moonlight
# (ENV["ZODI_INJECT"] = A, see sweeps/extra_features.jl); the best model (parallax band layer, cos×exp 1000) is trained
# WITH and WITHOUT n·δ̂, n·M̂ on shift 0 × 3 seeds. Run one job per A (the injection applies to the whole process):
#     ZODI_INJECT=1e-2 sbatch ... pipeline/cluster/threaded.sbatch sweeps/configs_v44.jl     (and 1e-3)
@assert ZODI_HELIO "configs_v44.jl is for heliocentric inputs"
@assert INJECT_A > 0 "configs_v44.jl needs ENV[\"ZODI_INJECT\"] (the injected amplitude)"
include(joinpath(@__DIR__, "configs_v24.jl"))
CONFIGS = Dict{String, NamedTuple}()
for s in 42:44, (tag, feats) in (("base", :sunseason_learnband_plx), ("earthc", :sunseason_learnband_plx_earthc))
    CONFIGS["z500h_inj$(INJECT_A)_bandplx_$(tag)_cosexp1k_shift0_s$s"] = (; R24..., epochs=1000, arch=:bandplx, features=feats,
                                                                       schedule=:cosexpw, lr_max=2e-3, sched_kw=(; decay=3.0, warm=0.05),
                                                                       split_name=split_name24(0), seed=s)
end
