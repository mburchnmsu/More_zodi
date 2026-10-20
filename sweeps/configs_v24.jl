# Round 24 (2026-10-19/20): the 500-day delivery (ZODI_DATA = "z500": corrected ZodiPy targets, 1,520,194 pointings).
# Poster model + n·J (Jupiter's position; kept for the real-data work), sin/cos λ⊕ kept, no dust bands.
# The month-on/month-off split shifted by Δ = 0, 10, …, 50 days (as round 21), 5 seeds, 500 epochs, one-cycle LR 1e-3,
# in-epoch loss logging. With 500 days each version has ~8 held-out months; Δ = 0 and Δ = 30 alone test every day once.
@assert ZODI_DATA == "z500" "configs_v24.jl is for the 500-day data: set ENV[\"ZODI_DATA\"] = \"z500\" first"
const SHIFTS24 = [0, 10, 20, 30, 40, 50]
"""Alternating 30-day windows shifted by Δ days: window k = ⌊(t − Δ)/30⌋, even → train, odd → test."""
function shifted_30day_split24(Δ)
    blk = floor.(Int, (t_rel .- Δ) ./ 30.0)
    (findall(iseven, blk), findall(isodd, blk))
end
split_name24(Δ) = "z500 30-day split, shifted $(Δ) d"
for Δ in SHIFTS24; splits[split_name24(Δ)] = shifted_30day_split24(Δ); end
run24(Δ, s) = "z500_nJ_shift$(Δ)_s$s"
const R24 = (; arch=:mlp, hidden=(64, 64, 32, 16), batchsize=512, epochs=500, schedule=:onecycle, lr_max=1e-3,
             evals_per_epoch=10, eval_sub=50_000, keep_snaps=false, features=:sunseason_J)
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46, Δ in SHIFTS24
    CONFIGS[run24(Δ, s)] = (; R24..., split_name=split_name24(Δ), seed=s)
end
