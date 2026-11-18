# Round 48 (Nov 17, user): does the model NEED Earth? Remove Earth's position from the inputs in two levels and measure
# how much worse the model gets (to compare later with adding Mars, the Moon, ...). Learnable bands without parallax
# (arch :bandmlp; the parallax layer needs the observer's position, i.e. Earth's), cos×exp 1000 epochs, all 6 shifts × 2
# seeds, so the three families differ only in their inputs (FEATURE_SETS, sweeps/extra_features.jl):
#   full      :sunseason_learnband  — all Earth/orbit inputs (reference)
#   sunonly   :learnband_sunonly    — level 1: the Sun angle n·S, ecliptic latitude, pointing; nothing on Earth's orbit
#   pointonly :learnband_pointonly  — level 2: pointing only
# ZODI_DATA=z500 (ZODI_HELIO defaults to 1). Report: EARTH2D_SET=r48 julia --project=. sweeps/earth2d.jl
@assert ZODI_HELIO "configs_v48.jl is for heliocentric inputs"
include(joinpath(@__DIR__, "configs_v24.jl"))
CONFIGS = Dict{String, NamedTuple}()
for s in 42:43, Δ in SHIFTS24, (tag, feats) in (("full", :sunseason_learnband), ("sunonly", :learnband_sunonly),
                                                ("pointonly", :learnband_pointonly))
    CONFIGS["z500h_band_$(tag)_cosexp1k_shift$(Δ)_s$s"] = (; R24..., epochs=1000, arch=:bandmlp, features=feats,
                                                           schedule=:cosexpw, lr_max=2e-3, sched_kw=(; decay=3.0, warm=0.05),
                                                           split_name=split_name24(Δ), seed=s)
end
