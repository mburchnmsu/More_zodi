# Poster data, part 4: all-sky map of the out-of-sample error. Every exposure is predicted by the 5-seed ensembles of
# the shifted 30-day splits that held it out, between-month (interior) windows only. Each exposure is spread over a
# disc on a 1° ecliptic grid (footprint_stat): radius 1.75° (3.5° patches ≈ SPHEREx's view) and 3.5° (the 7° blend).
# Poster v6 (Oct 18): the 750-epoch runs (round 21); v4–v5 used the 100-epoch runs (round 16).
#   julia --project=. poster/data_skyerror.jl  → poster/fig_skyerror.jld2
ENV["ZODI_DATA"] = "z115"
using LinearAlgebra; BLAS.set_num_threads(2)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "configs_v16.jl", "shift_helpers.jl", "r17_20_helpers.jl")
    include(joinpath(@__DIR__, "..", "sweeps", f))
end
using JLD2

const FAM = get(ENV, "POSTER_FAM", "z115_m750_shift")
fam(Δ) = "$(FAM)$Δ"
E = oos_interior(fam); ok = .!isnan.(E)
G = footprint_stat(E, x -> median(abs.(x)); radius=1.75)               # 360 × 180, 1° cells (lon 0..360, lat −90..90)
G7 = footprint_stat(E, x -> median(abs.(x)); radius=3.5)
a = abs.(E[ok]); b = abs.(ecliptic_latitude_deg[ok])
interior_medians = [median(abs.(e[is_interior(Δ, te)])) for Δ in SHIFTS16 for (te, e) in (relerr(runs16(fam(Δ))),) if any(is_interior(Δ, te))]
jldsave(joinpath(@__DIR__, "fig_skyerror.jld2"); G, G7, res=1.0, radius=1.75, radius7=3.5, n_exposures=sum(ok),
        median_pct=median(a), p95_pct=quantile(a, 0.95), eclip_median_pct=median(a[b .< 2]), pole_median_pct=median(a[b .>= 60]),
        interior_median_range=extrema(interior_medians), nshifts=length(SHIFTS16))
@printf("%d exposures; median %.4f%% (p95 %.3f%%); |β|<2° %.4f%%; |β|≥60° %.4f%%; interior medians per shift %.4f–%.4f%%\n",
        sum(ok), median(a), quantile(a, 0.95), median(a[b .< 2]), median(a[b .>= 60]), extrema(interior_medians)...)
