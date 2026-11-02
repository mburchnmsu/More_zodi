# Round 41 (Nov 2, Discovery): AdamW λ = 1e-4 on the other 3 shifts (10, 20, 50), so the best decay setting from round
# 40 has a full 6-shift sky map. Same setup as configs_v40.jl (cos×exp warm 0.05, peak 2e-3, decay 3; 2000 epochs;
# parallax band layer). One job per shift:
#   sbatch --cpus-per-task=5 --time=1-12:00:00 pipeline/cluster/threaded.sbatch sweeps/configs_v41.jl --only <its 5 runs>
@assert ZODI_HELIO "configs_v41.jl is for heliocentric inputs"
include(joinpath(@__DIR__, "configs_v24.jl"))
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46, Δ in (10, 20, 50)
    CONFIGS["z500h_bandplx_cosexp2k_aw1e-4_shift$(Δ)_s$s"] = (; R24..., epochs=2000, arch=:bandplx,
        features=:sunseason_learnband_plx, schedule=:cosexpw, lr_max=2e-3, sched_kw=(; decay=3.0, warm=0.05),
        adamw=1e-4, split_name=split_name24(Δ), seed=s)
end
