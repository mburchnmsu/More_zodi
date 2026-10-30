# Round 38 (Oct 29): round 37's cos×exp at 1000 epochs (with warm-up, peak 2e-3, decay 3), parallax band layer, on the
# remaining shifts 10, 20, 40, 50 × 5 seeds, so all 6 splits can be compared with one-cycle at 2000 epochs (round 34).
# Same run names as round 37.   ZODI_DATA=z500 (ZODI_HELIO defaults to 1)
@assert ZODI_HELIO "configs_v38.jl is for heliocentric inputs"
include(joinpath(@__DIR__, "configs_v24.jl"))
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46, Δ in (10, 20, 40, 50)
    CONFIGS["z500h_bandplx_cosexp1k_shift$(Δ)_s$s"] = (; R24..., epochs=1000, arch=:bandplx, features=:sunseason_learnband_plx,
                                                      schedule=:cosexpw, lr_max=2e-3, sched_kw=(; decay=3.0, warm=0.05),
                                                      split_name=split_name24(Δ), seed=s)
end
