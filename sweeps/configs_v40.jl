# Round 40 (Nov 1, Discovery): does weight decay stop the overfitting that cos×exp at 2000 epochs shows on shifts 30 and
# 40 (round 39), and keep its gains elsewhere? AdamW (mb_train kwarg `adamw` = λ: each step shrinks the MLP weights by
# lr·λ, so the decay follows the LR schedule; the band layer's physical parameters are not decayed). Otherwise identical
# to round 39: cos×exp (warm 0.05, peak 2e-3, decay 3), 2000 epochs, parallax band layer.
# λ = 1e-4, 1e-3, 1e-2 (total shrink over training ≈ exp(−λ·Σlr), Σlr ≈ 1500: ×0.86, ×0.22, ×3e-7 without gradients),
# shifts 0 (reference), 30, 40 × 5 seeds = 45 runs. On the cluster: one job per (λ, shift), e.g.
#   sbatch --cpus-per-task=5 --time=1-12:00:00 pipeline/cluster/threaded.sbatch sweeps/configs_v40.jl --only <its 5 runs>
@assert ZODI_HELIO "configs_v40.jl is for heliocentric inputs"
include(joinpath(@__DIR__, "configs_v24.jl"))
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46, Δ in (0, 30, 40), (λtag, λ) in (("aw1e-4", 1e-4), ("aw1e-3", 1e-3), ("aw1e-2", 1e-2))
    CONFIGS["z500h_bandplx_cosexp2k_$(λtag)_shift$(Δ)_s$s"] = (; R24..., epochs=2000, arch=:bandplx,
        features=:sunseason_learnband_plx, schedule=:cosexpw, lr_max=2e-3, sched_kw=(; decay=3.0, warm=0.05),
        adamw=λ, split_name=split_name24(Δ), seed=s)
end
