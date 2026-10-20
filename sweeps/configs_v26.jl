# Round 26 (mentor's validation test 2, Oct 20): the poster model (140-day data z115, 64-64-32-16, one-cycle LR 1e-3,
# 750 epochs, 6 shifted month splits × 5 seeds, as round 21) WITHOUT the Earth dot products: inputs n·S, n·z, n·vS,
# sin λ⊕, cos λ⊕ (n·E, n·vE, n·x⊕, n·y⊕ removed; clock kept; no n·J). Compare its sky map with round 21's. Not for the poster.
include(joinpath(@__DIR__, "configs_v16.jl"))                  # registers the shifted splits (and its own CONFIGS)
@assert ZODI_DATA == "z115"
const R26 = (; arch=:mlp, hidden=(64, 64, 32, 16), batchsize=512, epochs=750, schedule=:onecycle, lr_max=1e-3,
             evals_per_epoch=10, eval_sub=50_000, keep_snaps=false, features=:sunseason_noEarth)
run26(Δ, s) = "z115_noEarth_shift$(Δ)_s$s"
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46, Δ in SHIFTS16
    CONFIGS[run26(Δ, s)] = (; R26..., split_name=shift_split_name(Δ), seed=s)
end
