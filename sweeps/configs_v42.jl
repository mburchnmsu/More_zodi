# Round 42 (Nov 2, Discovery): best-epoch selection against the long-run overfitting (rounds 39–40). Round 39's setup
# (cos×exp warm 0.05, peak 2e-3, decay 3; 2000 epochs; parallax band layer; no weight decay), but one training window is
# held out as validation (val_tranges: window k = 8 of the 30-day split, t_rel ∈ [Δ + 240, Δ + 270), ~1/8 of the
# training exposures), and the weights of the epoch with the lowest validation loss are kept (keep_best).
# Shifts 0, 30, 40 × 5 seeds (compare with round 39 and round 40 on the same shifts). One job per shift:
#   sbatch --cpus-per-task=5 --time=1-12:00:00 pipeline/cluster/threaded.sbatch sweeps/configs_v42.jl --only <its 5 runs>
@assert ZODI_HELIO "configs_v42.jl is for heliocentric inputs"
include(joinpath(@__DIR__, "configs_v24.jl"))
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46, Δ in (0, 30, 40)
    CONFIGS["z500h_bandplx_cosexp2k_best_shift$(Δ)_s$s"] = (; R24..., epochs=2000, arch=:bandplx,
        features=:sunseason_learnband_plx, schedule=:cosexpw, lr_max=2e-3, sched_kw=(; decay=3.0, warm=0.05),
        val_tranges=[(Δ + 240.0, Δ + 270.0)], keep_best=true, split_name=split_name24(Δ), seed=s)
end
