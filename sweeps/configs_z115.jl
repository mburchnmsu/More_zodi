# Round 10 (2026-10-13): the CORRECTED target (ZodiPy 1.1.5 regeneration, data/zodipy115_*.h5).
# Run with ENV["ZODI_DATA"] = "z115" → results in sweeps/results_z115/ (the original results are never touched).
#   arms : base n·* (:look_dir) | season (:look_dir_season) | season − n·vS | season − n·J
#   tests: 30-day blocks, held-out ecliptic patch, 80/20 chronological (sanity: same tests as before, corrected data)
#          + random 90/10 (whole mission → used for the extrapolation-in-time test on the synthetic future set)
include(joinpath(@__DIR__, "extra_splits.jl"))
@assert ZODI_DATA == "z115" "configs_z115.jl is for the corrected data: set ENV[\"ZODI_DATA\"] = \"z115\" first"
const R10 = (; arch=:mlp, hidden=(64, 64, 32, 16), batchsize=512, epochs=100, schedule=:onecycle, lr_max=1e-3)  # = R9
const ARMS10  = [("base", :look_dir), ("season", :look_dir_season), ("novS", :season_novS), ("noJ", :season_noJ)]
const TESTS10 = [("blk", "30 day split"), ("p1", "patch ecliptic"), ("ch", "80/20 Chronological"), ("r90", "random 90/10")]
# which (arm, test) pairs to run: every arm on the extrapolation training set; the sanity tests for base & season (+novS)
const PAIRS10 = [("base", "blk"), ("season", "blk"), ("novS", "blk"),
                 ("base", "ch"),  ("season", "ch"),  ("novS", "ch"),
                 ("season", "p1"),
                 ("base", "r90"), ("season", "r90"), ("novS", "r90"), ("noJ", "r90")]
name10(arm, test, s) = "z115_$(arm)_$(test)_s$s"
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46, (arm, test) in PAIRS10
    CONFIGS[name10(arm, test, s)] = (; R10..., features=Dict(ARMS10)[arm], split_name=Dict(TESTS10)[test], seed=s)
end
