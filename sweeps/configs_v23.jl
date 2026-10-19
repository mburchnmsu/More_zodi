# Round 23 (2026-10-19, overnight follow-up to round 22): the round-22 winner on the stripe — poster model + the 3 sharp
# dust-band profiles (:sunseason_bandsharp), 64-64-32-16, 300 epochs — on the other 5 shifted month splits (Δ = 10…50;
# Δ = 0 is z115_r22_bands), to redraw the out-of-sample sky map. (Wider + bands was best overall in round 22 but takes
# ~1.8× longer per run: it would not have finished by morning.)
include(joinpath(@__DIR__, "configs_v16.jl"))                  # registers the shifted splits (and its own CONFIGS)
@assert ZODI_DATA == "z115"
const R23 = (; arch=:mlp, hidden=(64, 64, 32, 16), batchsize=512, epochs=300, schedule=:onecycle, lr_max=1e-3,
             evals_per_epoch=10, eval_sub=50_000, keep_snaps=false, features=:sunseason_bandsharp)
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46, Δ in SHIFTS16[2:end]
    CONFIGS["z115_r23_bands_shift$(Δ)_s$s"] = (; R23..., split_name=shift_split_name(Δ), seed=s)
end
