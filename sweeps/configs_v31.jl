# Rounds 31–33 (Oct 22–23), heliocentric 500-day data, 5 seeds, 500 epochs, band parameters started at Kelsall's values.
#   ENV["R31_STAGE"] = "plx"   — round 31: the PARALLAX band layer (arch :bandplx) on the poster split (shift 0), to compare
#                                with round 30's no-parallax layer (z500h_band_kelsall_shift0)
#   ENV["R31_STAGE"] = "map"   — round 32: the winning band layer on the 5 remaining shifts (10–50) → full sky map;
#                                ENV["R31_WINNER"] = "band" | "bandplx"
#   ENV["R31_STAGE"] = "earth" — round 33: the mentor's Earth-centric null test: poster inputs + n·δ̂ + n·M̂, shift 0
@assert ZODI_HELIO "configs_v31.jl is for heliocentric inputs"
include(joinpath(@__DIR__, "configs_v24.jl"))
const STAGE31 = get(ENV, "R31_STAGE", "plx")
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46
    if STAGE31 == "plx"
        CONFIGS["z500h_bandplx_kelsall_shift0_s$s"] = (; R24..., arch=:bandplx, features=:sunseason_learnband_plx,
                                                       split_name=split_name24(0), seed=s)
    elseif STAGE31 == "map"
        w = get(ENV, "R31_WINNER", "band")
        for Δ in (10, 20, 30, 40, 50)
            CONFIGS["z500h_$(w)_kelsall_shift$(Δ)_s$s"] = w == "bandplx" ?
                (; R24..., arch=:bandplx, features=:sunseason_learnband_plx, split_name=split_name24(Δ), seed=s) :
                (; R24..., arch=:bandmlp, features=:sunseason_learnband, split_name=split_name24(Δ), seed=s)
        end
    elseif STAGE31 == "earth"
        CONFIGS["z500h_earthc_shift0_s$s"] = (; R24..., features=:sunseason_earthcentric, split_name=split_name24(0), seed=s)
    end
end
