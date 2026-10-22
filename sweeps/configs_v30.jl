# Round 30 (Oct 22): the learnable dust-band layer (sweeps/band_layer.jl, arch = :bandmlp) on the heliocentric 500-day data,
# poster split (shift 0), 5 seeds, 500 epochs — the same recipe as round 27 (heliocentric, no bands: 0.0157% median,
# ecliptic 0.044%) plus the band layer.
#   kelsall — band parameters started at Kelsall's values;
#   perturb — started WRONG (i + 1°, Ω + 30°, δζ × 1.5, v × 2): the recovery test (does training pull them back?)
@assert ZODI_HELIO "configs_v30.jl is for heliocentric inputs"
include(joinpath(@__DIR__, "configs_v24.jl"))
const PERTURBED_BANDS = (i=KELSALL_BANDS.i .+ 1.0, Ω=KELSALL_BANDS.Ω .+ 30.0, δζ=KELSALL_BANDS.δζ .* 1.5, v=KELSALL_BANDS.v .* 2)
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46, (tag, init) in (("kelsall", KELSALL_BANDS), ("perturb", PERTURBED_BANDS))
    CONFIGS["z500h_band_$(tag)_shift0_s$s"] = (; R24..., arch=:bandmlp, features=:sunseason_learnband, band_init=init,
                                               split_name=split_name24(0), seed=s)
end
