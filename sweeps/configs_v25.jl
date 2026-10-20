# Round 25 (2026-10-20): control for round 24 — the 500-day data, poster model WITHOUT n·J (:sunframe_season), poster
# split (shift 0), 5 seeds, 500 epochs (otherwise identical to round 24). Separates "more data" from "+ Jupiter".
include(joinpath(@__DIR__, "configs_v24.jl"))                  # registers the z500 shifted splits (and its own CONFIGS)
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46
    CONFIGS["z500_noJ_shift0_s$s"] = (; R24..., features=:sunframe_season, split_name=split_name24(0), seed=s)
end
