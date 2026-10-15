# Round 16 (2026-10-15, mentor request): does the 30-day-block result depend on WHICH months are held out?
# Slide the alternating 30-day train/test pattern by Δ = 10, 20, 30, 40, 50 days (Δ = 0 is the existing
# "30 day split" = z115_sunseason_blk_*; Δ = 30 swaps train and test months). Poster model: Sun frame + sin/cos λ⊕,
# same recipe as rounds 10–11. Corrected target (ENV["ZODI_DATA"] = "z115" → sweeps/results_z115/).
# Δ = 0 and Δ = 30 together test every exposure exactly once → an out-of-sample all-sky error map.
include(joinpath(@__DIR__, "extra_splits.jl"))
@assert ZODI_DATA == "z115" "configs_v16.jl is for the corrected data: set ENV[\"ZODI_DATA\"] = \"z115\" first"
const R16 = (; arch=:mlp, hidden=(64, 64, 32, 16), batchsize=512, epochs=100, schedule=:onecycle, lr_max=1e-3)   # = R11
const SHIFTS16 = [0, 10, 20, 30, 40, 50]
"""Alternating 30-day windows, pattern shifted by Δ days: window k = ⌊(t − Δ)/30⌋, even → train, odd → test."""
function shifted_30day_split(Δ)
    blk = floor.(Int, (t_rel .- Δ) ./ 30.0)
    (findall(iseven, blk), findall(isodd, blk))
end
shift_split_name(Δ) = Δ == 0 ? "30 day split" : "30 day split, shifted $(Δ) d"
for Δ in SHIFTS16[2:end]; splits[shift_split_name(Δ)] = shifted_30day_split(Δ); end
@assert shifted_30day_split(0) == splits["30 day split"]          # Δ = 0 reproduces the existing split exactly
shift_run(Δ, s) = Δ == 0 ? "z115_sunseason_blk_s$s" : "z115_sunseason_shift$(Δ)_s$s"
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46, Δ in SHIFTS16[2:end]
    CONFIGS[shift_run(Δ, s)] = (; R16..., features=:sunframe_season, split_name=shift_split_name(Δ), seed=s)
end
