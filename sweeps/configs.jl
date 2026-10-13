# Sweep configurations (keyword args for train_mb). All: n·* features, 80/20 chronological.
const BASE = (; arch=:mlp, hidden=(64, 64, 32, 16), batchsize=512, epochs=100)

CONFIGS = Dict{String, NamedTuple}(
    # ---- Phase 1: learning-rate schedule × peak LR, baseline 64-64-32-16 ----
    "p1_onecycle_1e-3" => (; BASE..., schedule=:onecycle, lr_max=1e-3),
    "p1_onecycle_3e-3" => (; BASE..., schedule=:onecycle, lr_max=3e-3),
    "p1_onecycle_1e-2" => (; BASE..., schedule=:onecycle, lr_max=1e-2),
    "p1_cosexp_1e-3"   => (; BASE..., schedule=:cosexp,   lr_max=1e-3),
    "p1_cosexp_3e-3"   => (; BASE..., schedule=:cosexp,   lr_max=3e-3),
    "p1_cosexp_1e-2"   => (; BASE..., schedule=:cosexp,   lr_max=1e-2),
    "p1_linear_1e-3"   => (; BASE..., schedule=:linear,   lr_max=1e-3),   # reference: old schedule, mini-batched
)

# ---- Phase 1b: seed repeats (test error is extrapolation-dominated → measure seed noise) ----
for (nm, kw) in [("onecycle_1e-3", (; schedule=:onecycle, lr_max=1e-3)),
                 ("cosexp_1e-2",   (; schedule=:cosexp,   lr_max=1e-2)),
                 ("cosexp_3e-3",   (; schedule=:cosexp,   lr_max=3e-3)),
                 ("linear_1e-3",   (; schedule=:linear,   lr_max=1e-3))], s in (43, 44)
    CONFIGS["p1s_$(nm)_s$s"] = (; BASE..., kw..., seed=s)
end

# ---- Phase 2: architecture scan, one-cycle lr_max=1e-3, 100 epochs, 2 seeds each ----
const P2 = (; batchsize=512, epochs=100, schedule=:onecycle, lr_max=1e-3)
for (nm, kw) in [("mlp_32-16",            (; arch=:mlp, hidden=(32, 16))),
                 ("mlp_128-128-64-32",    (; arch=:mlp, hidden=(128, 128, 64, 32))),
                 ("mlp_256-256-128-64",   (; arch=:mlp, hidden=(256, 256, 128, 64))),
                 ("mlp_128x4-64-32",      (; arch=:mlp, hidden=(128, 128, 128, 128, 64, 32))),
                 ("res_w64_b3",           (; arch=:resmlp, width=64,  blocks=3)),
                 ("res_w128_b4",          (; arch=:resmlp, width=128, blocks=4)),
                 ("res_w256_b4",          (; arch=:resmlp, width=256, blocks=4))], s in (42, 43)
    CONFIGS["p2_$(nm)_s$s"] = (; P2..., kw..., seed=s)
end

# ---- Phase 3: extra seeds of the cheap baseline for a seed-ensemble test ----
for s in (45, 46, 47, 48)
    CONFIGS["p3_mlp_64-64-32-16_s$s"] = (; P2..., arch=:mlp, hidden=(64, 64, 32, 16), seed=s)
end
for s in (44, 45)   # extra seeds of the small ResMLP → groups with p2_res_w64_b3
    CONFIGS["p2_res_w64_b3_s$s"] = (; P2..., arch=:resmlp, width=64, blocks=3, seed=s)
end
