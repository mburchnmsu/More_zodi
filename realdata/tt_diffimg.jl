# Week 14 card "difference imaging", one patch at a time (Nov 17). A grid-2 level-6 patch (~0.92°) holds 64 level-9
# sub-pixels (~6.9′); the training table (data/tt_train, via realdata/tt_match_mjy.jl) has every exposure of each, with the
# star-masked measured sky, SPHEREx's zodi and our emulator at that exposure's own wavelength.
#   difference image D = measured − the sub-pixel's median over time   (removes the fixed sky: stars, galaxies, offset)
#   model's change   Dm = model − its median over time, per sub-pixel
#   residual         R = D − a·Dm   (a = 1, and a fitted per patch: Kelsall's scale is ~18% low)
# Visits = exposures within 0.5 d. Prints the rms of each, makes a figure of the visits with the most sub-pixels covered.
#     julia --project=. realdata/tt_diffimg.jl [patch ...]   → figures/11172026_diffimg_p<patch>.png
include(joinpath(@__DIR__, "tt_match_mjy.jl"))
using CairoMakie
sub = Int.(c("subpix")); tmid = Float64.(c("t_mid_mjd"))
patches = isempty(ARGS) ? [129] : parse.(Int, ARGS)
rms(x) = sqrt(mean(abs2, x))
for P in patches
    k = findall((patch .== P) .& (clean .>= 0.5) .& isfinite.(fm))
    isempty(k) && (println("patch $P: no clean rows"); continue)
    subs = unique(sub[k]); med(v) = Dict(s => median(v[k[sub[k] .== s]]) for s in subs)
    mF, mZ, mO = med(fm), med(zcol), med(ol)
    D  = [fm[i] - mF[sub[i]] for i in k]
    DZ = [zcol[i] - mZ[sub[i]] for i in k]
    DO = [ol[i] - mO[sub[i]] for i in k]
    aO = (DO \ D); aZ = (DZ \ D)
    ra0, de0 = mean(ra[k]), mean(dec[k])
    gbk, = (mean(gb[k]),)
    βk = asind(sind(de0) * cosd(23.4393) - cosd(de0) * sind(23.4393) * sind(ra0))
    @printf("\npatch %d (RA %.1f°, Dec %.1f°, b %.1f°, ecliptic β %.1f°): %d rows, %d sub-pixels, %.0f days\n",
            P, ra0, de0, gbk, βk, length(k), length(subs), -(reverse(extrema(tmid[k]))...))
    @printf("  rms of the difference images D:                %.4f MJy/sr  (median measured %.4f)\n", rms(D), median(fm[k]))
    @printf("  rms after our model's change (a = 1):          %.4f\n", rms(D .- DO))
    @printf("  rms after our model's change × a (a = %.3f):   %.4f\n", aO, rms(D .- aO .* DO))
    @printf("  rms after SPHEREx zodi's change (a = 1):       %.4f\n", rms(D .- DZ))
    @printf("  rms after SPHEREx zodi's change × a (a = %.3f): %.4f\n", aZ, rms(D .- aZ .* DZ))
    # visits: exposures within 0.5 d; per visit and sub-pixel, the median over its exposures
    o = sortperm(tmid[k]); vis = zeros(Int, length(k)); v = 1
    for j in eachindex(o); j > 1 && tmid[k[o[j]]] - tmid[k[o[j-1]]] > 0.5 && (v += 1); vis[o[j]] = v; end
    R = D .- aO .* DO
    # spatial structure: per visit, the residual image's spread across sub-pixels vs the scatter within a sub-pixel
    vstats = [(v=u, n=length(unique(sub[k[vis .== u]])), t=median(tmid[k[vis .== u]]), d=median(D[vis .== u]), r=median(R[vis .== u]))
              for u in unique(vis)]
    big = filter(s -> s.n >= 16, vstats)
    @printf("  %d visits; %d cover ≥ 16 of the %d sub-pixels. Per visit, median D %+.4f…%+.4f, median residual %+.4f…%+.4f MJy/sr\n",
            length(vstats), length(big), length(subs), extrema(s.d for s in vstats)..., extrema(s.r for s in vstats)...)
    within = [rms(R[(vis .== s.v)] .- median(R[(vis .== s.v)])) for s in big]
    isempty(within) || @printf("  within a visit, residual spread across sub-pixels: median rms %.4f MJy/sr\n", median(within))
    # figure: up to 4 best-covered visits spread in time, D (top row) and R (bottom row), tangent-plane coordinates (arcmin)
    show = sort(sort(big, by=s -> -s.n)[1:min(end, 12)], by=s -> s.t)
    show = show[unique(round.(Int, range(1, length(show), length=min(4, length(show)))))]
    isempty(show) && continue
    x(i) = 60 * (mod(ra[i] - ra0 + 180, 360) - 180) * cosd(de0); y(i) = 60 * (dec[i] - de0)
    set_theme!(merge(Theme(fontsize=16), theme_black()))
    fig = Figure(size=(320 * length(show) + 120, 700))
    lim = max(quantile(abs.(D), 0.98), 1e-3); limr = max(quantile(abs.(R), 0.98), 1e-3)
    local s1, s2
    for (j, s) in enumerate(show)
        m = findall(vis .== s.v); mm = Dict{Int,Vector{Int}}(); for q in m; push!(get!(mm, sub[k[q]], Int[]), q); end
        pts = [Point2f(x(k[first(q)]), y(k[first(q)])) for q in values(mm)]
        dv = [median(D[q]) for q in values(mm)]; rv = [median(R[q]) for q in values(mm)]
        ax1 = Axis(fig[1, j], aspect=DataAspect(), title=@sprintf("MJD %.1f, %d cells", s.t, s.n), xreversed=true)
        s1 = scatter!(ax1, pts, color=dv, colormap=Reverse(:RdBu_9), colorrange=(-lim, lim), marker=:rect, markersize=34)
        ax2 = Axis(fig[2, j], aspect=DataAspect(), xreversed=true, xlabel="ΔRA cos Dec (′)")
        s2 = scatter!(ax2, pts, color=rv, colormap=Reverse(:RdBu_9), colorrange=(-limr, limr), marker=:rect, markersize=34)
        for ax in (ax1, ax2); limits!(ax, -32, 32, -32, 32); end
        j == 1 && (ax1.ylabel = "ΔDec (′)"; ax2.ylabel = "ΔDec (′)")
    end
    Colorbar(fig[1, length(show) + 1], s1, label="visit − median (MJy/sr)")
    Colorbar(fig[2, length(show) + 1], s2, label=@sprintf("after our model × %.2f (MJy/sr)", aO))
    Label(fig[0, :], @sprintf("Patch %d (β %.0f°): difference images (top) and residuals after our model's change (bottom), 6.9′ cells", P, βk), fontsize=18)
    save(joinpath(ROOT, "figures", "11172026_diffimg_p$(P).png"), fig, px_per_unit=1.5)
    println("  -> figures/11172026_diffimg_p$(P).png")
end
