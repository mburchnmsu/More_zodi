# Round 45 (Nov 4, the mentor: 2-D residuals "with + without Earth cloud"): the best model (parallax band layer, cos×exp
# at 1000 epochs, rounds 37–38 = cloud ON) trained on the sky WITHOUT Kelsall's Earth-trailing cloud
# (ENV["ZODI_NOCLOUD"] = "1", see sweeps/extra_features.jl), all 6 shifts × 5 seeds:
#     ZODI_NOCLOUD=1 sbatch ... pipeline/cluster/threaded.sbatch sweeps/configs_v45.jl --only ...
@assert ZODI_HELIO "configs_v45.jl is for heliocentric inputs"
@assert NOCLOUD "configs_v45.jl needs ENV[\"ZODI_NOCLOUD\"] = \"1\""
@assert INJECT_A == 0 "configs_v45.jl: no injection"
include(joinpath(@__DIR__, "configs_v24.jl"))
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46, Δ in SHIFTS24
    CONFIGS["z500h_nocloud_bandplx_cosexp1k_shift$(Δ)_s$s"] = (; R24..., epochs=1000, arch=:bandplx, features=:sunseason_learnband_plx,
                                                              schedule=:cosexpw, lr_max=2e-3, sched_kw=(; decay=3.0, warm=0.05),
                                                              split_name=split_name24(Δ), seed=s)
end
