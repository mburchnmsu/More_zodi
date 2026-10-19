# Poster data, part 6: what makes up the zodiacal light SPHEREx sees — the Kelsall components (ZodiPy, stored per
# pointing in the corrected data) as shares of the total 5 μm brightness, by ecliptic latitude and for looking ahead
# of / behind Earth.   julia --project=. poster/data_components.jl  → poster/fig_components.jld2
ENV["ZODI_DATA"] = "z115"
using LinearAlgebra; BLAS.set_num_threads(2)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
using JLD2
comp(n) = h5open(f -> read(f["emission_$n"]), emission_file)
parts = [("dust bands", comp("dust_band_1") .+ comp("dust_band_2") .+ comp("dust_band_3")),
         ("ring around the Sun", comp("circum_solar_ring")), ("cloud trailing Earth", comp("earth_trailing_feature"))]
smooth = comp("smooth_cloud")
@assert maximum(abs.((smooth .+ sum(last.(parts))) ./ y .- 1)) < 1e-6
β = abs.(Float64.(ecliptic_latitude_deg)); nvE = vec(sum(nvec_unit_cartesian .* v_earth_unit, dims=1))
rows = [("within 5° of the\nplane of the planets", β .< 5), ("5–30° above/below", 5 .<= β .< 30),
        ("30–60° above/below", 30 .<= β .< 60), ("toward the poles (>60°)", β .>= 60),
        ("looking ahead of Earth\n(within 15° of the plane)", (β .< 15) .& (nvE .> 0.5)),
        ("looking behind Earth\n(within 15° of the plane)", (β .< 15) .& (nvE .< -0.5))]
share = [100 * sum(c[k]) / sum(y[k]) for (_, k) in rows, (_, c) in parts]          # rows × parts, % of the total
smooth_share = [100 * sum(smooth[k]) / sum(y[k]) for (_, k) in rows]
jldsave(joinpath(@__DIR__, "fig_components.jld2"); row_labels=first.(rows), part_labels=first.(parts), share, smooth_share,
        n=[sum(k) for (_, k) in rows])
for (i, (lbl, k)) in enumerate(rows)
    @printf("%-45s n=%6d  smooth %.1f%%  %s\n", replace(lbl, "\n" => " "), sum(k), smooth_share[i],
            join([@sprintf("%s %.2f%%", p, share[i, j]) for (j, p) in enumerate(first.(parts))], ", "))
end
