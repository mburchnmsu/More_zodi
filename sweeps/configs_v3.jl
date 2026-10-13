# Round 3 (2026-10-07): the recommended recipe on EVERY split → the generalization table.
# n·* features, 64-64-32-16 MLP, batch 512, one-cycle peak 1e-3, 100 epochs, all training days.
const R3 = (; arch=:mlp, hidden=(64, 64, 32, 16), batchsize=512, epochs=100,
              schedule=:onecycle, lr_max=1e-3)
CONFIGS = Dict{String, NamedTuple}()
SPLIT_TAGS = Dict(                    # short file-name tag => split name in `splits`
    "rand"   => "random split",
    "wk7"    => "7-day alternating",
    "blk30"  => "30 day split",
    "mid"    => "50/50 mid-mission",
    "c25"    => "25/75 Chronological",
    "c50"    => "50/50 Chronological",
    "c75"    => "75/25 Chronological",
    "c85"    => "85/15 Chronological",
)
for (tag, sp) in SPLIT_TAGS
    seeds = tag in ("c25", "c50", "c75", "c85") ? (42, 43, 44) : (42, 43, 44, 45, 46)
    for s in seeds
        CONFIGS["sp_$(tag)_s$s"] = (; R3..., split_name=sp, seed=s)
    end
end
