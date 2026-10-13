# Round 7 (2026-10-09): #1 season features (sin/cos of Earth's ecliptic longitude) and #3 log target revisited.
# Names are chosen so EXISTING prefixes (final_base_s*, t_log_full_s*, sp_*) keep loading exactly what they load now.
const R7 = (; arch=:mlp, hidden=(64, 64, 32, 16), batchsize=512, epochs=100, schedule=:onecycle, lr_max=1e-3)
CONFIGS = Dict{String, NamedTuple}()
# --- #1 season features (baselines: sp_blk30_s42–46, sp_rand_s42–46, v_base_s42–46) ---
for s in 42:46
    CONFIGS["se_blk_s$s"]    = (; R7..., features=:look_dir_season, split_name="30 day split", seed=s)
    CONFIGS["v_season_s$s"]  = (; R7..., features=:look_dir_season, val_days=100.0, seed=s)
end
for s in 42:44
    CONFIGS["se_rand_s$s"]   = (; R7..., features=:look_dir_season, split_name="random split", seed=s)
end
# --- #3 log target with 10 seeds (existing: final_base_s42–46 linear, t_log_full_s42–46 log; add seeds 47–51) ---
for s in 47:51
    CONFIGS["x10_lin_full_s$s"] = (; R7..., seed=s)
    CONFIGS["x10_log_full_s$s"] = (; R7..., target=:log, seed=s)
end
for s in 42:46
    CONFIGS["blk_log_s$s"]      = (; R7..., target=:log, split_name="30 day split", seed=s)
    # mixed loss MSE(y) + α·MSE(log y); α = 0.25 ≈ equal weight at y ≈ 0.5, α = 1 log-leaning
    CONFIGS["t_mix025_full_s$s"] = (; R7..., target=:mixlog, mix_alpha=0.25, seed=s)
    CONFIGS["t_mix1_full_s$s"]   = (; R7..., target=:mixlog, mix_alpha=1.0, seed=s)
end
for s in 42:44
    CONFIGS["blk_mix025_s$s"] = (; R7..., target=:mixlog, mix_alpha=0.25, split_name="30 day split", seed=s)
    CONFIGS["blk_mix1_s$s"]   = (; R7..., target=:mixlog, mix_alpha=1.0, split_name="30 day split", seed=s)
end
