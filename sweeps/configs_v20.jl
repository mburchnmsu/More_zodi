# Round 20 (2026-10-17): the round-16 month-to-month splits (30-day windows, shifted by 0, 10, ..., 50 days) retrained
# for 300 epochs (round 16: 100), to redraw the out-of-sample sky-error map. Poster model (Sun frame + sin/cos λ⊕),
# peak LR 1e-3, 5 seeds; in-epoch loss logging (10 points per epoch) without weight snapshots.
include(joinpath(@__DIR__, "configs_v16.jl"))                  # registers the shifted splits (and its own CONFIGS)
@assert ZODI_DATA == "z115"
const R20 = (; arch=:mlp, hidden=(64, 64, 32, 16), batchsize=512, epochs=300, schedule=:onecycle, lr_max=1e-3,
             evals_per_epoch=10, eval_sub=50_000, keep_snaps=false)
run20(Δ, s) = "z115_m300_shift$(Δ)_s$s"
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46, Δ in SHIFTS16
    CONFIGS[run20(Δ, s)] = (; R20..., features=:sunframe_season, split_name=shift_split_name(Δ), seed=s)
end
