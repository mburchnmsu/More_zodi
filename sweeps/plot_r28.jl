# Rounds 27–28: the heliocentric 500-day sky map (no n·J; shifts 0 + 30) next to the barycentric + n·J one (round 24, 6
# shifts) and the 140-day poster model. 3.5° patches, same colour scale.   julia --project=. sweeps/plot_r28.jl
#   → figures/10212026_skymap_helio.png
using CairoMakie, JLD2, Statistics, Printf
const R = joinpath(@__DIR__, "..")
S140 = JLD2.load(joinpath(R, "poster", "fig_skyerror.jld2"))
S5b  = JLD2.load(joinpath(R, "sweeps", "results_z500", "r24_summary.jld2"))
S5h  = JLD2.load(joinpath(R, "sweeps", "results_z500_helio", "r24_summary.jld2"))
set_theme!(merge(Theme(fontsize=17), theme_black()))
include(joinpath(@__DIR__, "plot_sky_common.jl"))
st(S) = (S["stats"].med, S["stats"].p95, S["stats"].ecl, S["stats"].pole)
cols = [("140 days (poster model)", S140["G"], (S140["median_pct"], S140["p95_pct"], S140["eclip_median_pct"], S140["pole_median_pct"])),
        ("500 days, barycentric + n·J", S5b["G"], st(S5b)),
        ("500 days, heliocentric (no n·J)", S5h["G"], st(S5h))]
fig = Figure(size=(2600, 640)); hm = nothing
for (c, (ttl, G, (md, p95, ecl, pole))) in enumerate(cols)
    ax = Axis(fig[1, c], aspect=DataAspect(), title=ttl, titlesize=21); hidedecorations!(ax); hidespines!(ax)
    xs, ys, img = moll_raster(G)
    global hm = heatmap!(ax, xs, ys, img, colormap=:viridis, colorrange=(0.0, 0.08), nan_color=(:grey35, 1.0),
                         highclip=Makie.to_colormap(:viridis)[end])
    graticule!(ax)
    Label(fig[2, c], @sprintf("median %.4f%%  ·  p95 %.3f%%\nwithin 2° of the ecliptic %.4f%%  ·  above 60° %.4f%%", md, p95, ecl, pole),
          fontsize=16, tellwidth=false)
end
Colorbar(fig[1, 4], hm, label="median |error| (%)", height=Relative(0.8))
Label(fig[0, 1:3], "Out-of-sample error on the sky (month-on/month-off splits, 3.5° patches) — heliocentric map: shifts 0 + 30", font=:bold, fontsize=22)
save(joinpath(R, "figures", "10212026_skymap_helio.png"), fig, px_per_unit=2)
println("ok")
