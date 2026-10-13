# Round 6 (2026-10-08): Earth-centric control and clean Jupiter null controls.
# chrono = validation protocol (fit 0–100, val 100–111.4, test 111.4–139.7), 5 seeds
# blk    = 30-day alternating blocks (interpolation: test periods between training periods), 3 seeds
# Existing references: v_base_* / v_noJ_* (chrono), sp_blk30_* (block, n·J baseline).
const R6 = (; arch=:mlp, hidden=(64, 64, 32, 16), batchsize=512, epochs=100, schedule=:onecycle, lr_max=1e-3)
CONFIGS = Dict{String, NamedTuple}()
for (tag, fs) in (("ec", :earth_centric), ("Jrot45", :look_dir_Jrot45), ("Jrot90", :look_dir_Jrot90), ("Jscr", :look_dir_Jscr))
    for s in 42:46
        CONFIGS["v_$(tag)_s$s"] = (; R6..., features=fs, val_days=100.0, seed=s)
    end
end
for (tag, fs) in (("ec", :earth_centric), ("Jrot45", :look_dir_Jrot45), ("Jrot90", :look_dir_Jrot90),
                  ("Jscr", :look_dir_Jscr), ("noJ", :look_dir_noJ))
    for s in 42:44
        CONFIGS["blk_$(tag)_s$s"] = (; R6..., features=fs, split_name="30 day split", seed=s)
    end
end
