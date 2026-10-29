# The geometry behind the real-data light curves (data/spherex_real/geometry.h5 from realdata/geometry.py):
#   figures/<tag>_geometry_3panel.png — top-down view of Earth's orbit and the lines of sight; side view through the
#                                       tilted dust cloud; where along the line of sight the 5 μm light comes from
#   figures/<tag>_geometry_2panel.png — the top-down view and the line-of-sight panel only
#     julia --project=. realdata/plot_geometry.jl [tag]
using HDF5, CairoMakie, Statistics, Printf, Dates
const R = joinpath(@__DIR__, ".."); tag = isempty(ARGS) ? "geom" : ARGS[1]
f = h5open(joinpath(R, "data", "spherex_real", "geometry.h5")); G = Dict(k => read(f[k]) for k in keys(f)); close(f)
rows(a) = size(a, 2) == 3 ? a : permutedims(a)          # h5py (n, 3) arrays arrive as (3, n) in Julia
nep, ecl = G["nep"], G["ecl045"]
date(m) = Date(DateTime(1858, 11, 17) + Millisecond(round(Int, m * 86_400_000)))
S = G["S"]; ΩN = 77.7; inc = 2.03
E_n, E_e, E_d = rows(nep["earth"]), rows(ecl["earth"]), rows(G["day_earth"])
P_n = size(nep["prof"], 1) == length(nep["mjd"]) ? nep["prof"] : permutedims(nep["prof"])
P_e = size(ecl["prof"], 1) == length(ecl["mjd"]) ? ecl["prof"] : permutedims(ecl["prof"])
cut = G["cut_density"]; cut = size(cut, 1) == length(G["cut_s"]) ? cut : permutedims(cut)
kmax, kmin = argmax(nep["zodipy_fixed"]), argmin(nep["zodipy_fixed"])
halfd(p) = S[searchsortedfirst(cumsum(p) ./ sum(p), 0.5)]

set_theme!(merge(Theme(fontsize=17), theme_black()))
zr = extrema(nep["zodipy_fixed"])                     # colour scale: the pole only (the ecliptic point is ~2x brighter)

function topdown!(pos)
    ax = Axis(pos, aspect=DataAspect(), xlabel="x (AU, toward the vernal equinox)", ylabel="y (AU)",
              title="Seen from above: Earth's orbit and where SPHEREx looked")
    xd, yd = E_d[:, 1], E_d[:, 2]; h = G["day_height"]
    lines!(ax, xd, yd, color=(:grey60, 0.6), linewidth=1)
    lines!(ax, 0.9xd, 0.9yd, color=h, colormap=Reverse(:RdBu_9), colorrange=(-0.04, 0.04), linewidth=9)   # inner ring: height
    lines!(ax, [-1.25, 1.25] .* cosd(ΩN), [-1.25, 1.25] .* sind(ΩN), color=(:grey70, 0.8), linestyle=:dash)
    text!(ax, 1.27cosd(ΩN), 1.27sind(ΩN), text="line of nodes", color=:grey70, fontsize=13, align=(:center, :bottom))
    scatter!(ax, [0], [0], color=:yellow, markersize=26); text!(ax, 0.06, -0.12, text="Sun", color=:yellow, fontsize=14)
    # months
    for m in 1:12
        k = findfirst(x -> date(x) == Date(2026, m, 1), G["day_mjd"]); k === nothing && continue
        text!(ax, 1.17 * xd[k], 1.17 * yd[k], text=Dates.monthabbr(m), color=:grey80, fontsize=13, align=(:center, :center))
    end
    kp = argmin(vec(sum(abs2, E_d, dims=2))); ka = argmax(vec(sum(abs2, E_d, dims=2)))
    for (k, l) in ((kp, "closest to Sun"), (ka, "farthest"))
        text!(ax, 0.72xd[k], 0.72yd[k], text=l, color=:grey80, fontsize=12, align=(:center, :center))
    end
    # pole frames: looking straight up, out of the page
    sc = scatter!(ax, E_n[:, 1], E_n[:, 2], color=nep["zodipy_fixed"], colormap=:inferno, colorrange=zr, markersize=9,
                  strokecolor=:white, strokewidth=0.4)
    # ecliptic-point frames: arrows along the line of sight (in the ecliptic plane)
    d = ecl["dhat"]
    arrows2d!(ax, E_e[:, 1], E_e[:, 2], fill(0.55d[1], size(E_e, 1)), fill(0.55d[2], size(E_e, 1)), color=:cyan, shaftwidth=2, tipwidth=10, tiplength=10)
    scatter!(ax, E_e[:, 1], E_e[:, 2], color=:cyan, marker=:diamond,
             markersize=16, strokecolor=:cyan, strokewidth=1.5)
    text!(ax, -1.45, -1.48, fontsize=12, color=:grey85, align=(:left, :bottom),
          text="dots: pole frames (line of sight straight up, out of the page)\ndiamonds + arrows: ecliptic point at longitude 45°\ninner ring: red = Earth above the dust's midplane, blue = below (±0.035 AU)")
    limits!(ax, -1.5, 1.5, -1.5, 1.5)
    ax, sc
end

function sideview!(pos)
    sx, sz = G["cut_s"], G["cut_z"]
    ax = Axis(pos, xlabel="distance from the Sun along ecliptic longitude $(round(Int, ΩN - 90 + 360))° (AU)", ylabel="height above the ecliptic (AU)",
              title="Side view through the dust cloud (roughly to scale)")
    hm = heatmap!(ax, sx, sz, log10.(cut ./ maximum(cut[abs.(sx) .> 0.9, :])), colormap=:magma, colorrange=(-2.0, 0.3))
    lines!(ax, [sx[1], sx[end]], [0, 0], color=(:white, 0.7), linestyle=:dash)
    t = tand(inc); lines!(ax, [sx[1], sx[end]], -t .* [sx[1], sx[end]], color=:cyan, linewidth=2)
    text!(ax, 2.15, 0.02, text="ecliptic (Earth's orbit)", color=:white, fontsize=13, align=(:right, :bottom))
    text!(ax, 2.15, -2.15t - 0.02, text="dust midplane (tilted 2°)", color=:cyan, fontsize=13, align=(:right, :top))
    scatter!(ax, [0], [0], color=:yellow, markersize=20)
    for (s, l, al) in ((1.0, "~Sep 8: Earth $(round(t, digits=3)) AU above the\nmidplane → less dust overhead → fainter", (:left, :center)),
                       (-1.0, "~Mar 9: Earth below the midplane\n→ more dust overhead → brighter", (:right, :center)))
        arrows2d!(ax, [s], [0.0], [0.0], [0.45], color=:white, shaftwidth=2, tipwidth=10, tiplength=10)
        scatter!(ax, [s], [0.0], color=:deepskyblue, markersize=16, strokecolor=:white, strokewidth=1)
        text!(ax, s + (al[1] == :left ? 0.08 : -0.08), 0.3, text=l, color=:white, fontsize=12, align=al)
    end
    text!(ax, 1.0, 0.47, text="to the pole", color=:white, fontsize=12, align=(:center, :bottom))
    limits!(ax, sx[1], sx[end], sz[1], sz[end])
    ax, hm
end

function lightfrom!(pos)
    ax = Axis(pos, xlabel="distance from Earth along the line of sight (AU)", ylabel="brightness per AU of path (MJy/sr per AU)",
              title="Where the 5 μm light comes from", yscale=log10)
    for (k, c, l) in ((kmax, :orange, "pole, brightest ($(date(nep["mjd"][kmax])))"), (kmin, :gold, "pole, faintest ($(date(nep["mjd"][kmin])))"))
        lines!(ax, S, P_n[k, :], color=c, linewidth=3, label=l)
    end
    seen = Set{String}()
    for (k, c) in zip(eachindex(ecl["mjd"]), Iterators.cycle((:cyan,)))
        dstr = Dates.format(date(ecl["mjd"][k]), "yyyy-mm"); dstr in seen && continue; push!(seen, dstr)
        lines!(ax, S, P_e[k, :], color=(:cyan, 0.55 + 0.15length(seen)), linewidth=2, linestyle=(:dash, :dot, :dashdot)[length(seen)],
               label="ecliptic 45°, $dstr")
    end
    hn = halfd(P_n[kmax, :]); he = median(halfd(P_e[k, :]) for k in axes(P_e, 1))
    vlines!(ax, [hn], color=(:orange, 0.6), linestyle=:dot); vlines!(ax, [he], color=(:cyan, 0.6), linestyle=:dot)
    text!(ax, hn + 0.02, 2e-3, text=@sprintf("half of the pole's light\nfrom within %.2f AU", hn), color=:orange, fontsize=12)
    text!(ax, he + 0.02, 2e-4, text=@sprintf("half of the ecliptic\npoint's light within %.2f AU", he), color=:cyan, fontsize=12)
    limits!(ax, 0, 2.5, 1e-5, nothing)
    axislegend(ax, position=:rt, labelsize=13)
    ax
end

note = "Kelsall smooth dust cloud (the model behind ZodiPy; the main component). Integrated along each line of sight it gives 95% of ZodiPy at the pole and 91% on the ecliptic (the rest: dust bands)."

fig = Figure(size=(2300, 1500))
ax1, sc = topdown!(fig[1, 1]); Colorbar(fig[1, 2], sc, label="ZodiPy at the pole, 4.93 μm (MJy/sr)")
ax3 = lightfrom!(fig[1, 3])
ax2, hm = sideview!(fig[2, 1:3]); Colorbar(fig[2, 4], hm, label="log₁₀ dust density (relative to near Earth)")
rowsize!(fig.layout, 2, Relative(0.36))
Label(fig[0, 1:3], "Why the zodiacal light at the north ecliptic pole rises and falls over the year", font=:bold, fontsize=22)
Label(fig[3, 1:3], note, fontsize=13, color=:grey75)
save(joinpath(R, "figures", "$(tag)_geometry_3panel.png"), fig, px_per_unit=1.5)

fig = Figure(size=(2300, 1050))
ax1, sc = topdown!(fig[1, 1]); Colorbar(fig[1, 2], sc, label="ZodiPy at the pole, 4.93 μm (MJy/sr)")
lightfrom!(fig[1, 3])
Label(fig[0, 1:3], "Where Earth was, where SPHEREx looked, and where the light comes from", font=:bold, fontsize=22)
Label(fig[2, 1:3], note, fontsize=13, color=:grey75)
save(joinpath(R, "figures", "$(tag)_geometry_2panel.png"), fig, px_per_unit=1.5)
println("ok")
