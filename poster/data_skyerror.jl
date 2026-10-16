# Poster data, part 4: all-sky map of the out-of-sample error (round 16, 10152026 notebook). Every exposure is predicted
# by the 5-seed ensembles of the shifted 30-day splits that held it out, interior windows only (training data on both
# sides). Each exposure is spread over ~SPHEREx's field (footprint_stat, radius 1.75°) on a 1° ecliptic grid.
#   julia --project=. poster/data_skyerror.jl  → poster/fig_skyerror.jld2
ENV["ZODI_DATA"] = "z115"
using LinearAlgebra; BLAS.set_num_threads(2)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "configs_v16.jl", "shift_helpers.jl")
    include(joinpath(@__DIR__, "..", "sweeps", f))
end
using JLD2

oi = oos_prediction(which=:interior); ok = .!isnan.(oi.err_pct)
G = footprint_stat(oi.err_pct, x -> median(abs.(x)))                  # 360 × 180, 1° cells (lon 0..360, lat −90..90)
a = abs.(oi.err_pct[ok]); b = abs.(ecliptic_latitude_deg[ok])
interior_medians = [median(abs.(e[is_interior(Δ, te)])) for Δ in SHIFTS16 for (te, e) in (relerr(runs16(Δ)),) if any(is_interior(Δ, te))]
jldsave(joinpath(@__DIR__, "fig_skyerror.jld2"); G, res=1.0, radius=1.75, n_exposures=sum(ok),
        median_pct=median(a), eclip_median_pct=median(a[b .< 2]), pole_median_pct=median(a[b .>= 60]),
        interior_median_range=extrema(interior_medians), nshifts=length(SHIFTS16))
@printf("%d exposures; median %.4f%%; |β|<2° %.4f%%; |β|≥60° %.4f%%; interior medians per shift %.4f–%.4f%%; cells filled %d\n",
        sum(ok), median(a), median(a[b .< 2]), median(a[b .>= 60]), extrema(interior_medians)..., sum(.!isnan.(G)))
