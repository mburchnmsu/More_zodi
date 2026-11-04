# Round 43 (Nov 3, the mentor): the Earth-centric terms n·δ̂ (Earth-limb direction) and n·M̂ (Moon direction) added to
# the best model (parallax band layer, cos×exp at 1000 epochs, rounds 37–38), all 6 shifts × 5 seeds, so the 2-D
# residual maps with and without the Earth-centric inputs can be compared.   ZODI_DATA=z500 (ZODI_HELIO defaults to 1)
@assert ZODI_HELIO "configs_v43.jl is for heliocentric inputs"
include(joinpath(@__DIR__, "configs_v24.jl"))
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46, Δ in SHIFTS24
    CONFIGS["z500h_bandplx_earthc_cosexp1k_shift$(Δ)_s$s"] = (; R24..., epochs=1000, arch=:bandplx,
                                                             features=:sunseason_learnband_plx_earthc,
                                                             schedule=:cosexpw, lr_max=2e-3, sched_kw=(; decay=3.0, warm=0.05),
                                                             split_name=split_name24(Δ), seed=s)
end
