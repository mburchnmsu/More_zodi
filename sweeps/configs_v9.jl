# Round 9 (2026-10-13): dust-band features on top of the season model, 5 seeds (42–46).
#   arms : season (reference) | +sharp band profiles (3) | +parallax band profiles (9) | +both (12)
#   tests: 30-day blocks (blk), the three 12° sky patches (p1 ecliptic, p2 mid-latitude, p3 near pole), 80/20 chronological (ch)
# Existing references reused: se_blk_s42–46 (season, blk), patch{i}_season_s42–44 (season, patches; s45–46 added here).
include(joinpath(@__DIR__, "extra_splits.jl"))
const R9 = (; arch=:mlp, hidden=(64, 64, 32, 16), batchsize=512, epochs=100, schedule=:onecycle, lr_max=1e-3)
const ARMS9  = [("season", :look_dir_season), ("sharp", :season_bandsharp), ("plx", :season_bandplx), ("both", :season_bandboth),
                ("novS", :season_novS)]     # novS: added after the pipeline test (spacecraft-velocity dependence)
const TESTS9 = [("blk", "30 day split"), ("p1", "patch ecliptic"), ("p2", "patch mid-latitude"),
                ("p3", "patch near north pole"), ("ch", "80/20 Chronological")]
# run name for (arm, test, seed) — the season reference keeps its earlier names where they exist
function name9(arm, test, s)
    arm == "season" && test == "blk" && return "se_blk_s$s"
    arm == "season" && test in ("p1", "p2", "p3") && return "patch$(test[2])_season_s$s"
    "b9_$(arm)_$(test)_s$s"
end
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46, (arm, fs) in ARMS9, (test, sp) in TESTS9
    CONFIGS[name9(arm, test, s)] = (; R9..., features=fs, split_name=sp, seed=s)
end
