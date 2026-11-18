# One clean difference-imaging figure for two patches (Nov 17): the south ecliptic pole (129) and a patch on the ecliptic
# (71), 64 level-9 sub-pixels (6.9′) each. Differences from realdata/tt_diffimg.jl, to avoid a patchy look:
#   * all values brought to 5.0 μm with Kelsall's colour (× z(5 μm)/z(λ)), so exposures at different wavelengths can be pooled
#   * exposures pooled in time windows (2 d at the pole, 5 d on the ecliptic) so one map covers the whole patch; only
#     windows covering ≥ 58 of the 64 cells are shown (missing cells grey)
#   * each cell drawn as the region nearest its centre (≈ the HEALPix pixel), so cells tile with no gaps
# Rows per patch: difference image (window − the cell's median over the mission), and the residual after our model's own
# change (scaled by the per-patch fit a). Values = medians over the window's exposures.
#     julia --project=. realdata/tt_diffimg_fig.jl   → figures/11172026_diffimg_2patch.png
include(joinpath(@__DIR__, "tt_match_mjy.jl"))
using CairoMakie
sub = Int.(c("subpix")); tmid = Float64.(c("t_mid_mjd"))
col5 = z5 ./ zl
F5, O5 = fm .* col5, ol .* col5                      # measured (star-masked) and our model at 5.0 μm
rms(x) = sqrt(mean(abs2, x))
function patchmaps(P, W; nshow=4, mincov=58)
    k = findall((patch .== P) .& (clean .>= 0.5) .& isfinite.(fm))
    subs = sort(unique(sub[k]))
    mF = Dict(s => median(F5[k[sub[k] .== s]]) for s in subs); mO = Dict(s => median(O5[k[sub[k] .== s]]) for s in subs)
    D = [F5[i] - mF[sub[i]] for i in k]; DO = [O5[i] - mO[sub[i]] for i in k]
    a = DO \ D; R = D .- a .* DO
    o = sortperm(tmid[k]); grp = zeros(Int, length(k)); g = 1; t0 = tmid[k[o[1]]]
    for j in eachindex(o); tmid[k[o[j]]] - t0 > W && (g += 1; t0 = tmid[k[o[j]]]); grp[o[j]] = g; end
    ok = [u for u in 1:g if length(unique(sub[k[grp .== u]])) >= mincov]
    sel = ok[unique(round.(Int, range(1, length(ok), length=min(nshow, length(ok)))))]
    ra0 = mean(ra[k]); de0 = mean(dec[k])
    cen = Dict(s => (60 * (mod(ra[k[findfirst(==(s), sub[k])]] - ra0 + 180, 360) - 180) * cosd(de0),
                     60 * (dec[k[findfirst(==(s), sub[k])]] - de0)) for s in subs)
    maps = map(sel) do u
        m = findall(grp .== u)
        dv = Dict(s => median(D[m[sub[k[m]] .== s]]) for s in unique(sub[k[m]]))
        rv = Dict(s => median(R[m[sub[k[m]] .== s]]) for s in unique(sub[k[m]]))
        (t0=minimum(tmid[k[m]]), t1=maximum(tmid[k[m]]), n=length(m), dv, rv)
    end
    β = asind(sind(de0) * cosd(23.4393) - cosd(de0) * sind(23.4393) * sind(ra0))
    (; P, W, a, β, b=mean(gb[k]), subs, cen, maps, rmsD=rms(D), rmsR=rms(R), medF=median(F5[k]))
end
"""Raster of the cells (nearest centre, masked beyond 5′ of every centre)."""
function raster(pm, vals)
    xs = range(-34, 34, length=341); ys = range(-34, 34, length=341)
    C = [pm.cen[s] for s in pm.subs]
    Z = fill(NaN, length(xs), length(ys)); inside = falses(length(xs), length(ys))
    for (i, x) in enumerate(xs), (j, y) in enumerate(ys)
        d = [hypot(x - c[1], y - c[2]) for c in C]; q = argmin(d)
        d[q] <= 5.0 || continue
        inside[i, j] = true; Z[i, j] = get(vals, pm.subs[q], NaN)
    end
    xs, ys, Z, inside
end
pms = [patchmaps(129, 2.0), patchmaps(71, 5.0)]
for pm in pms
    @printf("patch %d (β %.0f°, b %.0f°): measured median %.3f MJy/sr at 5.0 μm; rms of difference %.4f → residual %.4f (a = %.3f)\n",
            pm.P, pm.β, pm.b, pm.medF, pm.rmsD, pm.rmsR, pm.a)
end
set_theme!(merge(Theme(fontsize=17), theme_black()))
ncol = maximum(length(pm.maps) for pm in pms)
fig = Figure()
for (p, pm) in enumerate(pms)
    limD = quantile(abs.(filter(isfinite, reduce(vcat, [collect(values(m.dv)) for m in pm.maps]))), 0.98)
    limR = quantile(abs.(filter(isfinite, reduce(vcat, [collect(values(m.rv)) for m in pm.maps]))), 0.98)
    local hD, hR
    for (j, m) in enumerate(pm.maps), (r, vals, lim) in ((1, m.dv, limD), (2, m.rv, limR))
        row = 2(p - 1) + r
        ax = Axis(fig[row, j], aspect=DataAspect(), xreversed=true, backgroundcolor=:black, width=270, height=270,
                  title=r == 1 ? @sprintf("MJD %.0f–%.0f (%d exp.)", m.t0, m.t1, m.n) : "", titlesize=15)
        hidedecorations!(ax); hidespines!(ax)
        xs, ys, Z, inside = raster(pm, vals)
        G = [inside[i, j2] && isnan(Z[i, j2]) ? 1.0 : NaN for i in axes(Z, 1), j2 in axes(Z, 2)]
        heatmap!(ax, xs, ys, G, colormap=[:grey35, :grey35], colorrange=(0, 2))
        hz = heatmap!(ax, xs, ys, Z, colormap=Reverse(:RdBu_9), colorrange=(-lim, lim), nan_color=:transparent)
        r == 1 ? (hD = hz) : (hR = hz)
        j == 1 && lines!(ax, [28, 21.1], [-31, -31], color=:white, linewidth=3)   # 6.9′ scale bar
    end
    Colorbar(fig[2p - 1, ncol + 1], hD, label="minus median (MJy/sr)", height=Relative(0.85))
    Colorbar(fig[2p, ncol + 1], hR, label=@sprintf("after our model × %.2f", pm.a), height=Relative(0.85))
    Label(fig[2p - 1, 0], @sprintf("patch %d\nβ %.0f°\ndifference", pm.P, pm.β), rotation=0, fontsize=16, tellheight=false)
    Label(fig[2p, 0], "residual", fontsize=16, tellheight=false)
end
Label(fig[-1, :], "Difference imaging at 5.0 μm: south ecliptic pole (top) and the ecliptic (bottom), 6.9′ cells (scale bar), star-masked", fontsize=19)
rowgap!(fig.layout, 8); resize_to_layout!(fig)
save(joinpath(ROOT, "figures", "11172026_diffimg_2patch.png"), fig, px_per_unit=1.5)
println("-> figures/11172026_diffimg_2patch.png")
