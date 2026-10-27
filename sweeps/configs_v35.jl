# Round 35 (queued after round 34): learning-rate schedule test, cos×exp with warm-up (:cosexpw) vs one-cycle.
# Parallax band layer, 500 epochs, shifts 0 (poster split) and 30 (the split that overfit at 2000 epochs) × 5 seeds.
# Compare with rounds 31–32 (same model, one-cycle peak 1e-3): z500h_bandplx_kelsall_shift{0,30}_s*.
# Peak 2e-3: the cos×exp curve averages 0.24·peak over training (decay 3), one-cycle 1e-3 averages ~0.5e-3, so the two
# schedules take the same average step size and differ only in shape (cos×exp spends longer at small learning rates).
@assert ZODI_HELIO "configs_v35.jl is for heliocentric inputs"
include(joinpath(@__DIR__, "configs_v24.jl"))
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46, Δ in (0, 30)
    CONFIGS["z500h_bandplx_cosexp_shift$(Δ)_s$s"] = (; R24..., arch=:bandplx, features=:sunseason_learnband_plx,
                                                    schedule=:cosexpw, lr_max=2e-3, sched_kw=(; decay=3.0, warm=0.05),
                                                    split_name=split_name24(Δ), seed=s)
end
