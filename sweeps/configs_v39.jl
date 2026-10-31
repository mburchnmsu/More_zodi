# Round 39 (Oct 30, first NMSU Discovery round): the cos×exp schedule (with warm-up, peak 2e-3, decay 3) at 2000 epochs,
# parallax band layer, all 6 shifts × 5 seeds. Compare with cos×exp 1000 (rounds 37–38) and one-cycle 2000 (round 34).
# On the cluster: one job per shift, e.g.
#   sbatch --cpus-per-task=5 --time=2-00:00:00 pipeline/cluster/threaded.sbatch sweeps/configs_v39.jl --only <the shift's 5 runs>
# ZODI_DATA=z500 (ZODI_HELIO defaults to 1)
@assert ZODI_HELIO "configs_v39.jl is for heliocentric inputs"
include(joinpath(@__DIR__, "configs_v24.jl"))
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46, Δ in SHIFTS24
    CONFIGS["z500h_bandplx_cosexp2k_shift$(Δ)_s$s"] = (; R24..., epochs=2000, arch=:bandplx, features=:sunseason_learnband_plx,
                                                      schedule=:cosexpw, lr_max=2e-3, sched_kw=(; decay=3.0, warm=0.05),
                                                      split_name=split_name24(Δ), seed=s)
end
