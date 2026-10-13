# Round 2 (2026-10-07): validation protocol + feature / regularization experiments.
# All: 64-64-32-16 MLP, batch 512, one-cycle peak 1e-3, 100 epochs, 5 seeds.
# VALIDATION: fit on days 0–100, select on days 100–111.4 (val), report days 111.4–139.7 (test).
const R2 = (; arch=:mlp, hidden=(64, 64, 32, 16), batchsize=512, epochs=100,
              schedule=:onecycle, lr_max=1e-3, val_days=100.0)
const SEEDS = (42, 43, 44, 45, 46)

CONFIGS = Dict{String, NamedTuple}()
for s in SEEDS
    CONFIGS["v_base_s$s"]  = (; R2..., seed=s)                                  # reference
    CONFIGS["v_dhat_s$s"]  = (; R2..., seed=s, features=:look_dir_dhat)         # #2a: + n·δ̂
    CONFIGS["v_noJ_s$s"]   = (; R2..., seed=s, features=:look_dir_noJ)          # #3b: drop n·J
    CONFIGS["v_wd1e-6_s$s"] = (; R2..., seed=s, weight_decay=1e-6)              # #3a: weight decay
    CONFIGS["v_wd1e-5_s$s"] = (; R2..., seed=s, weight_decay=1e-5)
end
# #2b: 30-day alternating blocks (test periods sit BETWEEN training periods) — diagnostic,
# no validation carve-out (val_days only makes sense for the chronological split)
for s in (42, 43, 44)
    CONFIGS["blk_base_s$s"] = (; R2..., val_days=nothing, split_name="30 day split", seed=s)
end
# Final models: refit on ALL training days (0–111.4, no validation carve-out).
# final_dhat = validation winner; final_base = baseline for an apples-to-apples all-sky comparison.
for s in SEEDS
    CONFIGS["final_dhat_s$s"] = (; R2..., val_days=nothing, seed=s, features=:look_dir_dhat)
    CONFIGS["final_base_s$s"] = (; R2..., val_days=nothing, seed=s)
end
