# Round 27 (Oct 20–21): the 500-day model WITHOUT n·J but with HELIOcentric inputs (ENV["ZODI_HELIO"] = "1"), on the
# poster split (shift 0), 5 seeds, 500 epochs — otherwise identical to round 25 (barycentric, no n·J: 0.031% median) and
# round 24 (barycentric + n·J: 0.016%). If the Sun's wobble about the barycentre is why n·J helped, this should match round 24.
@assert ZODI_HELIO "configs_v27.jl needs ENV[\"ZODI_HELIO\"] = \"1\""
include(joinpath(@__DIR__, "configs_v24.jl"))                  # registers the z500 shifted splits (and its own CONFIGS)
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46
    CONFIGS["z500h_noJ_shift0_s$s"] = (; R24..., features=:sunframe_season, split_name=split_name24(0), seed=s)
end
