# Round 28 (Oct 21): heliocentric inputs (ENV["ZODI_HELIO"] = "1") on the 500-day data, 5 seeds, 500 epochs:
#   z500h_noJ_shift30 — completes the heliocentric sky map (shift 0 = round 27; shifts 0 + 30 test every pointing once)
#   z500h_nJ_shift0   — the mentor's Jupiter null experiment: heliocentric + n·J; on Kelsall data n·J should add nothing
@assert ZODI_HELIO "configs_v28.jl needs ENV[\"ZODI_HELIO\"] = \"1\""
include(joinpath(@__DIR__, "configs_v24.jl"))
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46
    CONFIGS["z500h_noJ_shift30_s$s"] = (; R24..., features=:sunframe_season, split_name=split_name24(30), seed=s)
    CONFIGS["z500h_nJ_shift0_s$s"]   = (; R24..., features=:sunseason_J,     split_name=split_name24(0),  seed=s)
end
