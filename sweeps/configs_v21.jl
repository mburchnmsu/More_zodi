# Round 21 (2026-10-18): the month-to-month splits (30-day windows shifted by 0, 10, ..., 50 days) trained for 750 epochs
# (round 16: 100, round 20: 300), for the out-of-sample sky-error map. Poster model (Sun frame + sin/cos λ⊕), peak LR
# 1e-3 (one-cycle over the whole run), 5 seeds; in-epoch loss logging (10 points per epoch), no weight snapshots.
include(joinpath(@__DIR__, "configs_v16.jl"))                  # registers the shifted splits (and its own CONFIGS)
@assert ZODI_DATA == "z115"
const R21 = (; arch=:mlp, hidden=(64, 64, 32, 16), batchsize=512, epochs=750, schedule=:onecycle, lr_max=1e-3,
             evals_per_epoch=10, eval_sub=50_000, keep_snaps=false)
run21(Δ, s) = "z115_m750_shift$(Δ)_s$s"
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46, Δ in SHIFTS16
    CONFIGS[run21(Δ, s)] = (; R21..., features=:sunframe_season, split_name=shift_split_name(Δ), seed=s)
end
