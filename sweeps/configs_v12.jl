# Round 12 (2026-10-14, overnight): train on a full simulated year, test on the following ~1.3 years.
# Data: ENV["ZODI_DATA"] = "z115year" (zodipy_gen/generate_year.py: real mission + 5 rotated survey copies, 600k rows)
# → results in sweeps/results_z115year/. Same recipe as rounds 9–11.
include(joinpath(@__DIR__, "extra_splits.jl"))
@assert ZODI_DATA == "z115year" "configs_v12.jl needs ENV[\"ZODI_DATA\"] = \"z115year\""
const R12 = (; arch=:mlp, hidden=(64, 64, 32, 16), batchsize=512, epochs=100, schedule=:onecycle, lr_max=1e-3)
const ARMS12 = [("base", :look_dir), ("season", :look_dir_season), ("noJ", :season_noJ), ("sun", :sunframe),
                ("sunseason", :sunframe_season), ("suncloud", :sunframe_cloud), ("suncloudZ", :sunframe_cloudZ)]
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46, (arm, fs) in ARMS12
    CONFIGS["y12_$(arm)_s$s"] = (; R12..., features=fs, split_name="year 1 → later", seed=s)
end
