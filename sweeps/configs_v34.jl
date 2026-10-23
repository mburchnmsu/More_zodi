# Round 34 (weekend Oct 23–26): the parallax dust-band layer (round 31–32 model) trained for 2000 epochs instead of 500,
# all 6 month-on/month-off shifts × 5 seeds, heliocentric 500-day data, 5 μm, band parameters started at Kelsall's values.
# The one-cycle schedule is stretched over the 2000 epochs (a fresh run, not a continuation). Runs are trained in name
# order, so the poster split (shift 0) finishes first.   ZODI_DATA=z500 (ZODI_HELIO defaults to 1)
@assert ZODI_HELIO "configs_v34.jl is for heliocentric inputs"
include(joinpath(@__DIR__, "configs_v24.jl"))
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46, Δ in SHIFTS24
    CONFIGS["z500h_bandplx2k_shift$(Δ)_s$s"] = (; R24..., epochs=2000, arch=:bandplx, features=:sunseason_learnband_plx,
                                                split_name=split_name24(Δ), seed=s)
end
