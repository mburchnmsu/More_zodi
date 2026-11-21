# Week 15 task 4, full sky: plots of the per-exposure medians of the zodi-cleaned difference images (realdata/tt_diffmed.py
# on Colibrí, array 713, all 64,854 partitions; condensed by realdata/tt_diffmed_summary.py, job 765).
#     julia --project=. realdata/diffmed_fullsky.jl   (needs data/tt_diffmed_sum/*.csv fetched from Colibrí)
#   → figures/11212026_fullsky_diffmed_time.png  empirical zodi (ZODI + median d) and ZODI against time, and their difference
#   → figures/11212026_fullsky_diffmed_maps.png  per-partition sky maps (ecliptic): time spread of median d, empirical / ZODI
# Partition ids are 4·4^k + ipix with the pixel at HEALPix order k − 3 (nested; orders 6–9), see tt_diffmed_summary.py.
using DelimitedFiles, Statistics, Printf, CairoMakie, Healpix
include(joinpath(@__DIR__, "..", "sweeps", "plot_sky_common.jl"))
const R = normpath(joinpath(@__DIR__, ".."))
D = joinpath(R, "data", "tt_diffmed_sum")
function rd(f)
    T, h = readdlm(joinpath(D, f), ',', header=true); h = vec(String.(h))
    n -> T[:, findfirst(==(n), h)]
end
E = rd("tt_diffmed_exposures.csv"); P = rd("tt_diffmed_parts.csv")
t = Float64.(E("t_beg")); zemp, zodi, d = Float64.(E("z_emp")), Float64.(E("zodi")), Float64.(E("wmean_d"))
lam, npart = Float64.(E("lam")), Int.(E("n_part"))
@printf("%d exposures, MJD %.1f–%.1f; median d %+.5f MJy/sr, spread (1.4826 MAD) %.5f; |d| > 0.01: %.2f%%\n",
        length(t), minimum(t), maximum(t), median(d), 1.4826median(abs.(d .- median(d))), 100mean(abs.(d) .> 0.01))
@printf("empirical / ZODI: 1/50/99%% = %.4f %.4f %.4f\n", quantile(zemp ./ zodi, [0.01, 0.5, 0.99])...)

set_theme!(merge(Theme(fontsize=18), theme_black()))
# daily medians of d, to see slow drifts under the per-exposure scatter
day = floor.(Int, t); ud = sort(unique(day))
dmed = [median(d[day .== u]) for u in ud]
fig = Figure(size=(1500, 950))
ax1 = Axis(fig[1, 1], ylabel="MJy/sr", title="per exposure: ZODI column (grey) and empirical zodi = ZODI + median(d) (orange), 4.9–5.1 μm")
scatter!(ax1, t, zodi, color=(:grey70, 0.3), markersize=2); scatter!(ax1, t, zemp, color=(:orange, 0.3), markersize=2)
ax2 = Axis(fig[2, 1], xlabel="MJD", ylabel="median(d)  (MJy/sr)", title="empirical − ZODI per exposure (dots) and daily median (line)")
scatter!(ax2, t, d, color=(:deepskyblue, 0.25), markersize=2); lines!(ax2, ud .+ 0.5, dmed, color=:white, linewidth=1.5)
ylims!(ax1, quantile(zodi, 0.001) - 0.05, quantile(zemp, 0.999) + 0.05)
hlines!(ax2, [0], color=(:white, 0.4)); ylims!(ax2, -0.03, 0.03); linkxaxes!(ax1, ax2); hidexdecorations!(ax1, grid=false)
save(joinpath(R, "figures", "11212026_fullsky_diffmed_time.png"), fig, px_per_unit=1.5)
println("-> figures/11212026_fullsky_diffmed_time.png")

# sky maps: rasterize the multi-order partitions onto a 0.5° ecliptic grid
ord, ipx = Int.(P("order")), Int.(P("ipix"))
maximum(ord) > 9 && (ord .-= 3)   # tables made before the order fix carry k, not k − 3
vals = Dict(:mad => Float64.(P("mad_d")), :ratio => Float64.(P("ratio")), :nexp => Float64.(P("n_exp")))
look = Dict((ord[i], ipx[i]) => i for i in eachindex(ord))
res9 = Resolution(512); ε = deg2rad(23.4392911)
function ecl2eq(l, b)   # ecliptic (deg) → (colatitude, longitude) in equatorial, radians
    x, y, z = cosd(b)cosd(l), cosd(b)sind(l), sind(b)
    y2, z2 = y * cos(ε) - z * sin(ε), y * sin(ε) + z * cos(ε)
    (acos(clamp(z2, -1, 1)), mod(atan(y2, x), 2π))
end
res = 0.5; nl, nb = round(Int, 360 / res), round(Int, 180 / res)
idx = zeros(Int, nl, nb)
for i in 1:nl, j in 1:nb
    θ, φ = ecl2eq((i - 0.5) * res, -90 + (j - 0.5) * res)
    p = ang2pixNest(res9, θ, φ) - 1
    for o in 9:-1:6; k = get(look, (o, p >> (2 * (9 - o))), 0); k > 0 && (idx[i, j] = k; break); end
end
grid(v) = [k == 0 ? NaN : v[k] for k in idx]
panels = [("time spread of median(d) per partition (MJy/sr, 1.4826 × IQR/2)", grid(vals[:mad]), (0, 0.01), :viridis),
          ("empirical / ZODI, median over time", grid(vals[:ratio]), (0.98, 1.02), Reverse(:RdBu_9)),
          ("exposures per partition", grid(vals[:nexp]), (0, quantile(vals[:nexp], 0.98)), :viridis)]
fig = Figure(size=(1500, 1250))
for (r, (ttl, G, cr, cm)) in enumerate(panels)
    ax = Axis(fig[r, 1], aspect=DataAspect(), title=ttl * "   (ecliptic, centre λ = 0°)"); hidedecorations!(ax); hidespines!(ax)
    xs, ys, img = moll_raster(G)
    hm = heatmap!(ax, xs, ys, img, colormap=cm, colorrange=cr, nan_color=:grey30)
    graticule!(ax); Colorbar(fig[r, 2], hm)
end
save(joinpath(R, "figures", "11212026_fullsky_diffmed_maps.png"), fig, px_per_unit=1.2)
println("-> figures/11212026_fullsky_diffmed_maps.png")
@printf("partition time spread of median d: 50/90/99%% = %.4f %.4f %.4f MJy/sr; empty grid cells %.2f%%\n",
        quantile(vals[:mad], [0.5, 0.9, 0.99])..., 100mean(idx .== 0))
