# Round 4 (2026-10-07): output / target transforms, 80/20 chronological, n·* features.
#   :log      — train on log(y) (fractional-error loss, always-positive output)
#   :softplus — linear target, softplus on the output (always positive)
#   :relmse   — linear target, loss mean(((ŷ−y)/y)²)
# The :linear reference already exists (v_base_* with validation, final_base_* full).
const R4 = (; arch=:mlp, hidden=(64, 64, 32, 16), batchsize=512, epochs=100, schedule=:onecycle, lr_max=1e-3)
CONFIGS = Dict{String, NamedTuple}()
for tgt in (:log, :softplus, :relmse)
    for s in (42, 43, 44)               # selection runs: fit 0–100, validate 100–111.4
        CONFIGS["t_$(tgt)_val_s$s"]  = (; R4..., target=tgt, val_days=100.0, seed=s)
    end
    for s in (42, 43, 44, 45, 46)       # final runs: fit all training days, test + all-sky
        CONFIGS["t_$(tgt)_full_s$s"] = (; R4..., target=tgt, seed=s)
    end
end
