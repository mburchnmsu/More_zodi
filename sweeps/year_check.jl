# Why does the 500-day model need n·J? Compare matching pointings one year apart: same time of year (Earth's ecliptic
# longitude λ⊕) and the same direction in the Earth-following frame (n·x⊕, n·y⊕, n·z). If the geometry repeats, the
# Kelsall emission (corrected z500 targets) should repeat too; any difference is what a "year clock" like n·J can explain.
#   julia --project=. sweeps/year_check.jl
using HDF5, Statistics, Printf
const D = joinpath(@__DIR__, "..", "data")
n, tjd = h5open(f -> (read(f["pointing/nvec_unit_cartesian"]), read(f["times/julian_date"])), joinpath(D, "boresight_pointing.h5"))
E, S, vE = h5open(f -> (read(f["earth/positions"]), read(f["spherex/positions"]), read(f["earth/velocities"])), joinpath(D, "spherex_vectors_bore_interpolated.h5"))
y, blob, ring = h5open(f -> (read(f["emission"]), read(f["emission_earth_trailing_feature"]), read(f["emission_circum_solar_ring"])),
                       joinpath(D, "zodipy115_500d_boresight.h5"))
yd = h5open(f -> read(f["emission"]), joinpath(D, "spherex_zodipy_5um_boresight_interpolated.h5"))   # delivered (barycentric)
N = length(tjd); day = tjd .- minimum(tjd)
λ = mod.(atand.(E[2, :], E[1, :]), 360)
nx = cosd.(λ) .* n[1, :] .+ sind.(λ) .* n[2, :]; ny = -sind.(λ) .* n[1, :] .+ cosd.(λ) .* n[2, :]; nz = n[3, :]
rE = vec(sqrt.(sum(abs2, E, dims=1))); rS = vec(sqrt.(sum(abs2, S, dims=1)))
# bin (λ in 0.25°, nx/ny/nz in 0.01) → year-1 index; then look up year-2 pointings in the same bin
key(i) = (round(Int, λ[i] / 0.25), round(Int, nx[i] / 0.01), round(Int, ny[i] / 0.01), round(Int, nz[i] / 0.01))
y1 = Dict{NTuple{4, Int}, Int}()
for i in findall(day .< 365.25 - 10); y1[key(i)] = i; end
pairs = Tuple{Int, Int}[]
for j in findall(day .>= 365.25); i = get(y1, key(j), 0); i > 0 && push!(pairs, (i, j)); end
I = first.(pairs); J = last.(pairs)
@printf("%d matching pairs (same λ⊕ within 0.25°, same Earth-frame direction within ~0.6°); year-1 days %.0f–%.0f, year-2 days %.0f–%.0f\n",
        length(pairs), extrema(day[I])..., extrema(day[J])...)
rel(a, b) = 100 .* (b .- a) ./ a
for (nm, v) in (("corrected ZodiPy target (z500)", y), ("delivered ZodiPy (barycentric)", yd), ("smooth cloud + bands (target − ring − blob)", y .- ring .- blob),
                ("ring", ring), ("trailing blob", blob))
    r = rel(v[I], v[J])
    @printf("%-44s year2 − year1: median %+.3f%%  mean %+.3f%%  |·| median %.3f%%  p95 %.3f%%\n", nm, median(r), mean(r), median(abs.(r)), quantile(abs.(r), 0.95))
end
@printf("Earth distance |E|: year2 − year1 median %+.2e AU (|·| p95 %.2e);  SPHEREx distance |S|: median %+.2e AU\n",
        median(rE[J] .- rE[I]), quantile(abs.(rE[J] .- rE[I]), 0.95), median(rS[J] .- rS[I]))
@printf("SPHEREx height above the ecliptic S_z: year1 median %+.2e AU, year2 median %+.2e AU\n", median(S[3, I]), median(S[3, J]))
# how much of the target difference does the mismatch in direction explain? (pairs are only matched to ~0.6°)
dn = acosd.(clamp.(vec(sum(n[:, I] .* n[:, J], dims=1)), -1, 1))
@printf("direction mismatch within pairs (inertial): median %.2f°\n", median(dn))
dλ = λ[J] .- λ[I]; r = rel(y[I], y[J])
for (lo, hi) in ((-0.25, -0.08), (-0.08, 0.08), (0.08, 0.25))
    k = lo .<= dλ .< hi
    @printf("   pairs with Δλ in [%+.2f, %+.2f)°: n=%6d, median target difference %+.3f%%\n", lo, hi, sum(k), median(r[k]))
end
