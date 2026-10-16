# Round 17 (2026-10-16, mentor request): train + test loss curves for the 80/20 chronological split (fit days 0–111.7,
# test the last 20%) with the poster model (Sun frame + sin/cos λ⊕), same recipe as round 16.
# Corrected target (ENV["ZODI_DATA"] = "z115" → sweeps/results_z115/).
@assert ZODI_DATA == "z115" "configs_v17.jl is for the corrected data: set ENV[\"ZODI_DATA\"] = \"z115\" first"
const R17 = (; arch=:mlp, hidden=(64, 64, 32, 16), batchsize=512, epochs=100, schedule=:onecycle, lr_max=1e-3)   # = R16
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46
    CONFIGS["z115_sunseason_ch_s$s"] = (; R17..., features=:sunframe_season, split_name="80/20 Chronological", seed=s)
end
