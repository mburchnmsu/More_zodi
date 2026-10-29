# Round 37 (Oct 29): cheap test before cos×exp at 2000 epochs. The round-35/36 cos×exp schedule (with warm-up, peak 2e-3,
# decay 3) stretched over 1000 epochs, parallax band layer, shifts 0 and 30 × 5 seeds. Question: does cos×exp reach the
# one-cycle 2000-epoch accuracy (round 34) in half the epochs, and does shift 30 overfit the same way? Runs are trained in
# name order, so shift 0 finishes first.   ZODI_DATA=z500 (ZODI_HELIO defaults to 1)
@assert ZODI_HELIO "configs_v37.jl is for heliocentric inputs"
include(joinpath(@__DIR__, "configs_v24.jl"))
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46, Δ in (0, 30)
    CONFIGS["z500h_bandplx_cosexp1k_shift$(Δ)_s$s"] = (; R24..., epochs=1000, arch=:bandplx, features=:sunseason_learnband_plx,
                                                      schedule=:cosexpw, lr_max=2e-3, sched_kw=(; decay=3.0, warm=0.05),
                                                      split_name=split_name24(Δ), seed=s)
end
