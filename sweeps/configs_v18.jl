# Round 18 (2026-10-16, mentor follow-up on "jagged" loss curves): rerun the round-17 80/20 split and the round-16
# shift-20 / shift-30 splits with in-epoch logging (evals_per_epoch = 10, 50k-row fixed subsamples) and weight
# snapshots, for (a) loss curves averaged within each epoch and (b) the 5-network ensemble's own loss curve.
# Training is identical to the original runs (logging does not touch the RNGs) — checked in plot_smooth_loss.jl.
include(joinpath(@__DIR__, "configs_v16.jl"))                  # registers the shifted splits (and its own CONFIGS)
@assert ZODI_DATA == "z115"
const R18 = (; arch=:mlp, hidden=(64, 64, 32, 16), batchsize=512, epochs=100, schedule=:onecycle, lr_max=1e-3,
             evals_per_epoch=10, eval_sub=50_000)
const SPLITS18 = [("ch", "80/20 Chronological"), ("shift20", shift_split_name(20)), ("shift30", shift_split_name(30))]
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46, (tag, sp) in SPLITS18
    CONFIGS["z115_fine_$(tag)_s$s"] = (; R18..., features=:sunframe_season, split_name=sp, seed=s)
end
