# Where does the ZodiPy-1.1.5 regeneration differ from the original simulated data?
#   julia --project=. zodipy_gen/compare.jl      → zodipy_gen/compare.png + printed table
using HDF5, Statistics, Printf, CairoMakie
const D = joinpath(@__DIR__, "..", "data")
old, jd = h5open(f -> (read(f["emission"]), read(f["times/julian_date"])), joinpath(D, "spherex_zodipy_5um_boresight_interpolated.h5"))
new, comps = h5open(joinpath(D, "zodipy115_5um_boresight.h5")) do f
    read(f["emission"]), Dict(n => read(f["emission_$n"]) for n in ("smooth_cloud", "dust_band_1", "dust_band_2", "dust_band_3",
                                                                       "circum_solar_ring", "earth_trailing_feature"))
end
nvec, β = h5open(f -> (read(f["pointing/nvec_unit_cartesian"]), read(f["pointing/ecliptic_latitude_deg"])), joinpath(D, "boresight_pointing.h5"))
S, E = h5open(f -> (read(f["spherex/positions"]), read(f["earth/positions"])), joinpath(D, "spherex_vectors_bore_interpolated.h5"))
size(nvec, 1) == 3 || (nvec = permutedims(nvec)); size(S, 1) == 3 || (S = permutedims(S); E = permutedims(E))
# solar elongation (Sun ≈ barycentre to < 0.01 AU): angle between the pointing and the direction to the Sun (−S)
ε = [acosd(clamp(-sum(nvec[:, k] .* S[:, k]) / sqrt(sum(abs2, S[:, k])), -1, 1)) for k in axes(nvec, 2)]
r = new ./ old; d = jd .- minimum(jd)
@printf("new/old: median %.5f  p1 %.4f  p99 %.4f  min %.4f  max %.4f\n", median(r), quantile(r, 0.01), quantile(r, 0.99), extrema(r)...)
@printf("corr(new, old) = %.6f\n", cor(new, old))
println("median component share of the new total: ", join(["$k $(round(100median(v ./ new), digits=2))%" for (k, v) in comps], ", "))
fig = Figure(size=(1500, 430), fontsize=14)
for (i, (x, lab)) in enumerate(((d, "days since the first exposure"), (β, "ecliptic latitude β (°)"), (ε, "solar elongation (°)")))
    ax = Axis(fig[1, i], xlabel=lab, ylabel=i == 1 ? "ZodiPy 1.1.5 ÷ original" : "")
    k = 1:7:length(r); scatter!(ax, x[k], r[k], markersize=1.5, color=(:deepskyblue, 0.3))
    hlines!(ax, [1.0], color=:white, linestyle=:dash)
end
Label(fig[0, :], "Regenerated (ZodiPy 1.1.5, x = 5 μm, observer = SPHEREx) vs the original simulated data — every 7th exposure", font=:bold)
save(joinpath(@__DIR__, "compare.png"), fig); println("saved zodipy_gen/compare.png")
