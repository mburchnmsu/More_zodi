# The 2-D residual map of sweeps/earth2d.jl / cloud2d.jl, on the REAL sky: tall-table patches at 4.9–5.1 μm (grid 2, 192 level-6
# patches; |b| > 15° only), each exposure's residual minus its patch's own median over time (so a fixed sky drops out), in % of
# our model. Earth-motion frame: longitude from Earth's direction of motion (0 = ahead, 90 = Sun, 180 = behind), from the Sun's
# longitude at the exposure time; binned in 6° cells. Ecliptic frame: per patch, mean residual when seen behind Earth minus when
# seen ahead (the trailing-cloud asymmetry), each map pixel filled from the nearest patch (≤ 12°).
#     julia --project=. realdata/realsky2d.jl [tag [LEVEL G bmin]]   → figures/<tag>_realsky2d_moll_L<L>_grid<G>.png
using DelimitedFiles, Statistics, Printf, CairoMakie
include(joinpath(@__DIR__, "..", "sweeps", "plot_sky_common.jl"))
tag = length(ARGS) >= 1 ? ARGS[1] : "realsky2d"
LEVEL, G = length(ARGS) >= 3 ? parse.(Int, ARGS[2:3]) : (6, 2); bmin = length(ARGS) >= 4 ? parse(Float64, ARGS[4]) : 15.0
D = joinpath(@__DIR__, "..", "data", "spherex_real")
O, ho = readdlm(joinpath(D, "ttbin_L$(LEVEL)_grid$(G)_offsets.csv"), ',', header=true); ho = vec(ho)
col(n) = findfirst(==(n), ho)
"""Sun's ecliptic longitude (°) at MJD (low-precision solar formula, ~0.01°)."""
function sunlon(mjd)
    d = mjd - 51544.5; g = deg2rad(mod(357.528 + 0.9856003d, 360))
    mod(280.460 + 0.9856474d + 1.915sin(g) + 0.020sin(2g), 360)
end

# per exposure: Earth-motion longitude φE, ecliptic latitude, residuals (minus the patch median) in % of ours
φE = Float64[]; βx = Float64[]; Rours = Float64[]; Rsph = Float64[]; Dsph = Float64[]
P = NamedTuple[]                                                       # per patch: λ, β, behind − ahead
for i in axes(O, 1)
    abs(O[i, col("b")]) > bmin || continue
    f = joinpath(D, "ttbin_L$(LEVEL)_$(O[i, 1])_ours.csv"); isfile(f) || continue
    T, h = readdlm(f, ',', header=true); h = vec(h); c(n) = Float64.(T[:, findfirst(==(n), h)])
    t, fl, zs, ou = c("t_mid_mjd"), c("flux_median"), c("zodi_spherex"), c("ours_lam")
    ok = isfinite.(fl) .& isfinite.(ou) .& isfinite.(zs); sum(ok) >= 4 || continue
    t, fl, zs, ou = t[ok], fl[ok], zs[ok], ou[ok]
    λp, βp = Float64(O[i, col("λ")]), Float64(O[i, col("β")])
    φ = mod.(λp .- (sunlon.(t) .- 90), 360)                            # Earth's velocity points to (Sun longitude − 90°)
    r1 = fl .- ou; r2 = fl .- zs; r3 = zs .- ou
    e1 = 100 .* (r1 .- median(r1)) ./ ou; e2 = 100 .* (r2 .- median(r2)) ./ ou; e3 = 100 .* (r3 .- median(r3)) ./ ou
    append!(φE, φ); append!(βx, fill(βp, length(t))); append!(Rours, e1); append!(Rsph, e2); append!(Dsph, e3)
    bh = 90 .<= φ .< 270
    ba(e) = any(bh) && any(.!bh) ? mean(e[bh]) - mean(e[.!bh]) : NaN
    push!(P, (λ=λp, β=βp, n=length(t), nb=sum(bh), d1=ba(e1), d2=ba(e2), d3=ba(e3)))
end
@printf("%d patches with |b| > %g°, %d exposures; %d patches seen both ahead and behind\n", length(P), bmin, length(φE),
        count(p -> isfinite(p.d1), P))
for (lbl, e, key) in (("measured − ours", Rours, :d1), ("measured − SPHEREx zodi model", Rsph, :d2), ("SPHEREx zodi model − ours", Dsph, :d3))
    for (bl, kb) in (("|β| < 30°", abs.(βx) .< 30), ("all", trues(length(βx))))
        bh = kb .& (150 .<= φE .< 210); ah = kb .& ((φE .>= 330) .| (φE .< 30))
        @printf("%-30s %-9s behind (φ 150–210°) %+.3f%% ± %.3f (n %d), ahead (φ 330–30°) %+.3f%% ± %.3f (n %d)\n", lbl, bl,
                mean(e[bh]), std(e[bh]) / sqrt(sum(bh)), sum(bh), mean(e[ah]), std(e[ah]) / sqrt(sum(ah)), sum(ah))
    end
    d = [getfield(p, key) for p in P]; d = d[isfinite.(d)]
    @printf("   per patch behind − ahead: median %+.3f%%, mean %+.3f%% ± %.3f, rms %.3f%%\n", median(d), mean(d), std(d) / sqrt(length(d)), sqrt(mean(abs2, d)))
end

const W = 6.0
nφ, nb = round(Int, 360 / W), round(Int, 180 / W)
function grid(v, lon; lon0=0.0, minn=5)
    S = zeros(nφ, nb); C = zeros(Int, nφ, nb)
    for i in eachindex(v)
        a = clamp(floor(Int, mod(lon[i] - lon0, 360) / W) + 1, 1, nφ); b = clamp(floor(Int, (βx[i] + 90) / W) + 1, 1, nb)
        S[a, b] += v[i]; C[a, b] += 1
    end
    ifelse.(C .>= minn, S ./ max.(C, 1), NaN)
end
"""Ecliptic-frame grid (1.5° cells, centred on λ = 0): each cell takes the value of the nearest patch within rmax degrees."""
function nearest_grid(key; rmax=12.0, w=1.5)
    n1, n2 = round(Int, 360 / w), round(Int, 180 / w); Gm = fill(NaN, n1, n2)
    ok = [isfinite(getfield(p, key)) for p in P]; Q = P[ok]
    u = [(cosd(p.β)cosd(p.λ), cosd(p.β)sind(p.λ), sind(p.β)) for p in Q]
    for a in 1:n1, b in 1:n2
        l = (a - 0.5)w; bb = (b - 0.5)w - 90; x = (cosd(bb)cosd(l), cosd(bb)sind(l), sind(bb))
        best, k = -2.0, 0
        for (j, q) in enumerate(u); d = x[1]q[1] + x[2]q[2] + x[3]q[3]; d > best && ((best, k) = (d, j)); end
        acosd(clamp(best, -1, 1)) <= rmax && (Gm[a, b] = getfield(Q[k], key))
    end
    Gm
end
function frame_labels!(ax, lon0, names)
    for (l, txt) in names
        d = mod(l - lon0 + 180, 360) - 180
        for dd in (abs(d) > 170 ? (-168.0, 168.0) : (d,))
            x, y0 = moll_fwd(dd, 0)
            text!(ax, x, y0 + 0.05; text=txt, color=:yellow, fontsize=19, font=:bold, align=(:center, :bottom))
        end
    end
end

set_theme!(merge(Theme(fontsize=17), theme_black()))
cols = (("measured − our model", Rours, :d1), ("measured − SPHEREx zodi model", Rsph, :d2), ("SPHEREx zodi model − our model", Dsph, :d3))
lim = round(quantile(abs.(Rours), 0.95), digits=1)
fig = Figure(size=(900 * 3 + 250, 1150)); hm = nothing
cmap = Reverse(:RdBu_9)
for (c, (pttl, e, key)) in enumerate(cols)
    ax = Axis(fig[1, c], aspect=DataAspect(), title="$pttl, minus each patch's median\nEarth-motion frame (centre = behind Earth, 180°)", titlesize=18)
    hidedecorations!(ax); hidespines!(ax)
    xs, ys, img = moll_raster(grid(e, φE; lon0=180.0))
    global hm = heatmap!(ax, xs, ys, img, colormap=cmap, colorrange=(-lim, lim), nan_color=(:grey35, 1.0),
                         lowclip=Makie.to_colormap(cmap)[1], highclip=Makie.to_colormap(cmap)[end])
    graticule!(ax); frame_labels!(ax, 180.0, ((0, "ahead"), (90, "Sun"), (180, "behind"), (270, "anti-Sun")))
    Label(fig[2, c], @sprintf("%d exposures · median |value| %.2f%%", length(e), median(abs.(e))), fontsize=15, tellwidth=false)
    ax2 = Axis(fig[3, c], aspect=DataAspect(), title="$pttl: seen behind Earth − seen ahead, per patch\nEcliptic frame (centre = ecliptic longitude 0°)", titlesize=18)
    hidedecorations!(ax2); hidespines!(ax2)
    xs, ys, img = moll_raster(nearest_grid(key))
    heatmap!(ax2, xs, ys, img, colormap=cmap, colorrange=(-lim, lim), nan_color=(:grey35, 1.0),
             lowclip=Makie.to_colormap(cmap)[1], highclip=Makie.to_colormap(cmap)[end])
    graticule!(ax2)
    d = [getfield(p, key) for p in P]; d = d[isfinite.(d)]
    Label(fig[4, c], @sprintf("%d patches · median behind − ahead %+.2f%%", length(d), median(d)), fontsize=15, tellwidth=false)
end
Colorbar(fig[1:3, 4], hm, label="% of our model (red = brighter than the model)", height=Relative(0.7))
Label(fig[0, 1:3], "Real sky, tall table 4.9–5.1 μm, $(length(P)) patches with |b| > $(round(Int, bmin))°: time residuals in 2-D; grey = not covered",
      font=:bold, fontsize=21)
save(joinpath(@__DIR__, "..", "figures", "$(tag)_realsky2d_moll_L$(LEVEL)_grid$(G).png"), fig, px_per_unit=1.5)
println("ok")
