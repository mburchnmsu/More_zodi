# Round 19 (2026-10-16): does longer training and/or a lower learning rate smooth the 80/20 loss curves?
# Poster model (Sun frame + sin/cos λ⊕) on the 80/20 chronological split, 300 epochs, one-cycle with peak LR 1e-3
# (current) or 3e-4; in-epoch logging (10 points per epoch) for epoch-averaged curves. 5 seeds each.
@assert ZODI_DATA == "z115" "configs_v19.jl is for the corrected data: set ENV[\"ZODI_DATA\"] = \"z115\" first"
const R19 = (; arch=:mlp, hidden=(64, 64, 32, 16), batchsize=512, epochs=300, schedule=:onecycle,
             evals_per_epoch=10, eval_sub=50_000)
const LRS19 = [("lr1e3", 1e-3), ("lr3e4", 3e-4)]
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46, (tag, lr) in LRS19
    CONFIGS["z115_ch300_$(tag)_s$s"] = (; R19..., lr_max=lr, features=:sunframe_season, split_name="80/20 Chronological", seed=s)
end
