# Round 32: full heliocentric 500-day sky map with the learnable parallax dust-band layer (6 shifts × 5 seeds) next to the
# same model without the band layer (round 29) and their difference. 3.5° patches.   julia --project=. sweeps/plot_r32.jl
#   → figures/10232026_skymap_bandplx.png
using CairoMakie, JLD2, Statistics, Printf
const R = joinpath(@__DIR__, "..")
S0 = JLD2.load(joinpath(R, "sweeps", "results_z500_helio", "r24_summary.jld2"))     # round 29, no band layer
S1 = JLD2.load(joinpath(R, "sweeps", "results_z500_helio", "r32_summary.jld2"))     # round 32, parallax band layer
set_theme!(merge(Theme(fontsize=17), theme_black()))
include(joinpath(@__DIR__, "plot_sky_common.jl"))
st(S) = (S["stats"].med, S["stats"].p95, S["stats"].ecl, S["stats"].pole)
fig = Figure(size=(2600, 640)); hm = nothing
for (c, (ttl, S)) in enumerate((("no band layer (round 29)", S0), ("learnable parallax band layer (round 32)", S1)))
    ax = Axis(fig[1, c], aspect=DataAspect(), title=ttl, titlesize=21); hidedecorations!(ax); hidespines!(ax)
    xs, ys, img = moll_raster(S["G"])
    global hm = heatmap!(ax, xs, ys, img, colormap=:viridis, colorrange=(0.0, 0.08), nan_color=(:grey35, 1.0),
                         highclip=Makie.to_colormap(:viridis)[end])
    graticule!(ax)
    Label(fig[2, c], @sprintf("median %.4f%%  ·  p95 %.3f%%\nwithin 2° of the ecliptic %.4f%%  ·  above 60° %.4f%%", st(S)...),
          fontsize=16, tellwidth=false)
end
Colorbar(fig[1, 3], hm, label="median |error| (%)", height=Relative(0.8))
ax = Axis(fig[1, 4], aspect=DataAspect(), title="difference (band layer − none)", titlesize=21); hidedecorations!(ax); hidespines!(ax)
xs, ys, img = moll_raster(S1["G"] .- S0["G"])
hd = heatmap!(ax, xs, ys, img, colormap=Reverse(:RdBu_9), colorrange=(-0.03, 0.03), nan_color=(:grey35, 1.0)); graticule!(ax)
Label(fig[2, 4], "blue = band layer better", fontsize=16, tellwidth=false)
Colorbar(fig[1, 5], hd, label="Δ median |error| (%)", height=Relative(0.8))
Label(fig[0, 1:4], "Out-of-sample error on the sky, 500 days heliocentric, all 6 month-on/month-off shifts (3.5° patches)", font=:bold, fontsize=22)
save(joinpath(R, "figures", "10232026_skymap_bandplx.png"), fig, px_per_unit=2)
println("ok")
