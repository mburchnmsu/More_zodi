# Round 5 (2026-10-07): what is n·J doing? Validation protocol as round 2
# (fit days 0–100, validate 100–111.4, test 111.4–139.7), 64-64-32-16, one-cycle 1e-3, 100 epochs, 5 seeds.
# Compare with v_base_* (n·J) and v_noJ_* (no Jupiter feature) from round 2.
const R5 = (; arch=:mlp, hidden=(64, 64, 32, 16), batchsize=512, epochs=100,
              schedule=:onecycle, lr_max=1e-3, val_days=100.0)
CONFIGS = Dict{String, NamedTuple}()
for (tag, fs) in (("Jfix", :look_dir_Jfix), ("Junit", :look_dir_Junit), ("Jperp", :look_dir_Jperp)), s in 42:46
    CONFIGS["v_$(tag)_s$s"] = (; R5..., features=fs, seed=s)
end
