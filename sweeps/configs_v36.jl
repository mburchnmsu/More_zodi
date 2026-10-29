# Round 36 (Oct 28): the round-35 cos×exp schedule (with warm-up, peak 2e-3) on the remaining 4 shifts (10, 20, 40, 50)
# × 5 seeds, parallax band layer, 500 epochs. With round 35 (shifts 0, 30) this gives the full 6-shift sky map, to compare
# with one-cycle at 500 epochs (rounds 31–32) and at 2000 epochs (round 34). Same run names as round 35.
@assert ZODI_HELIO "configs_v36.jl is for heliocentric inputs"
include(joinpath(@__DIR__, "configs_v24.jl"))
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46, Δ in (10, 20, 40, 50)
    CONFIGS["z500h_bandplx_cosexp_shift$(Δ)_s$s"] = (; R24..., arch=:bandplx, features=:sunseason_learnband_plx,
                                                    schedule=:cosexpw, lr_max=2e-3, sched_kw=(; decay=3.0, warm=0.05),
                                                    split_name=split_name24(Δ), seed=s)
end
