# Round 29 (Oct 21–22): the full heliocentric 500-day sky map — the remaining shifts 10, 20, 40, 50 of the heliocentric,
# no-n·J model (shifts 0 and 30 = rounds 27–28), 5 seeds, 500 epochs. Heliocentric is the default for z500 since Oct 21.
@assert ZODI_HELIO "configs_v29.jl is for heliocentric inputs (default for ZODI_DATA = \"z500\")"
include(joinpath(@__DIR__, "configs_v24.jl"))
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46, Δ in (10, 40, 20, 50)
    CONFIGS["z500h_noJ_shift$(Δ)_s$s"] = (; R24..., features=:sunframe_season, split_name=split_name24(Δ), seed=s)
end
