# Mentor questions (Oct 16): (1) is the Earth-trailing feature (Kelsall's dust clump trailing Earth) modelled well?
# (2) are the "bubbles" in the out-of-sample sky map the time-extrapolation pattern, smoothed by averaging versions?
# Uses round-16 runs + the per-component ZodiPy emission stored in data/zodipy115_5um_boresight.h5.
#   julia --project=. sweeps/trailing_check.jl  → figures/10162026_trailing_feature.png, figures/10162026_error_vs_gap.png
ENV["ZODI_DATA"] = "z115"
using LinearAlgebra; BLAS.set_num_threads(2)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "configs_v16.jl", "shift_helpers.jl")
    include(joinpath(@__DIR__, f))
end
TF = h5open(f -> read(f["emission_earth_trailing_feature"]), emission_file)
RING = h5open(f -> read(f["emission_circum_solar_ring"]), emission_file)
ftf = 100 .* TF ./ y                                         # trailing feature as % of the total brightness
oi = oos_prediction(which=:interior); ok = .!isnan.(oi.err_pct); err = oi.err_pct
# Sun-relative ecliptic longitude of the look direction (S = Sun → SPHEREx, heliocentric ecliptic): 0 = toward the Sun
S = spherex_positions; n = nvec_unit_cartesian
lsun = atand.(-S[2, :], -S[1, :]); lon_n = atand.(n[2, :], n[1, :])
dlam = mod.(lon_n .- lsun .+ 180, 360) .- 180
nvE = vec(sum(n .* v_earth_unit, dims=1))
β = Float64.(ecliptic_latitude_deg)
@printf("look direction vs Earth's motion: Δλ for n·vE>0.5 median %.1f°, for n·vE<−0.5 median %.1f°\n",
        median(dlam[nvE .> 0.5]), median(dlam[nvE .< -0.5]))
@printf("trailing feature: max %.2f%% of total; median %.3f%% (n·vE<0, trailing side) vs %.3f%% (n·vE>0, leading side)\n",
        maximum(ftf), median(ftf[nvE .< 0]), median(ftf[nvE .> 0]))

# ---- figure 1: trailing feature vs the residual, in the Sun-Earth frame -------------------------------------------
function cellmap(xv, yv, v, keep; xr=(-180, 180), yr=(-90, 90), d=2.0, f=median, minn=5)
    nx, ny = round(Int, (xr[2] - xr[1]) / d), round(Int, (yr[2] - yr[1]) / d)
    B = [Float64[] for _ in 1:nx, _ in 1:ny]
    for i in findall(keep)
        ix = clamp(floor(Int, (xv[i] - xr[1]) / d) + 1, 1, nx); iy = clamp(floor(Int, (yv[i] - yr[1]) / d) + 1, 1, ny)
        push!(B[ix, iy], v[i])
    end
    range(xr[1] + d / 2, xr[2] - d / 2, length=nx), range(yr[1] + d / 2, yr[2] - d / 2, length=ny), [length(b) >= minn ? f(b) : NaN for b in B]
end
fig = Figure(size=(1500, 1250), fontsize=16)
Label(fig[0, :], "Is the Earth-trailing dust feature modelled well?  (out-of-sample error, interior held-out windows, round 16)", font=:bold, fontsize=19)
sides = (("leading side (looking ahead of Earth, n·vE > 0)", nvE .> 0), ("trailing side (looking behind Earth, n·vE < 0)", nvE .< 0))
for (c, (ttl, side)) in enumerate(sides)
    xr = c == 1 ? (-136, -76) : (76, 136)
    xs, ys, G1 = cellmap(dlam, β, ftf, side .& ok; xr)
    Label(fig[1, c, Top()], ttl, font=:bold, fontsize=15, padding=(0, 0, 28, 0))
    ax = Axis(fig[1, c], title="ZodiPy trailing feature, % of the total", titlesize=14, xlabel="longitude from the Sun Δλ (°)", ylabel="ecliptic latitude (°)")
    hm = heatmap!(ax, xs, ys, G1, colormap=:magma, colorrange=(0, maximum(filter(!isnan, G1))), nan_color=:grey85); Colorbar(fig[1, c][1, 2], hm, label="% of total")
    xs, ys, G2 = cellmap(dlam, β, err, side .& ok; xr)
    ax = Axis(fig[2, c], title="median signed error (network − ZodiPy), %", titlesize=14, xlabel="longitude from the Sun Δλ (°)", ylabel="ecliptic latitude (°)")
    hm = heatmap!(ax, xs, ys, G2, colormap=:balance, colorrange=(-0.06, 0.06), nan_color=:grey85); Colorbar(fig[2, c][1, 2], hm, label="error (%)")
end
# error vs trailing-feature fraction, near the ecliptic (|β| < 15°), both sides
ax = Axis(fig[3, 1:2], xlabel="trailing feature, % of the total brightness along the line of sight", ylabel="error (%)",
          title="Error vs how much of the light comes from the trailing feature (|β| < 15°; median and 16–84% range per bin)", titlesize=14)
for (lbl, side, col) in (("leading side", nvE .> 0, :steelblue), ("trailing side", nvE .< 0, :crimson))
    k = findall(side .& ok .& (abs.(β) .< 15)); edges = quantile(ftf[k], range(0, 1, length=21))
    xm, md, lo, hi = Float64[], Float64[], Float64[], Float64[]
    for b in 1:20
        kk = k[edges[b] .<= ftf[k] .<= edges[b+1]]; length(kk) < 50 && continue
        push!(xm, median(ftf[kk])); push!(md, median(err[kk])); push!(lo, quantile(err[kk], 0.16)); push!(hi, quantile(err[kk], 0.84))
    end
    band!(ax, xm, lo, hi, color=(col, 0.2)); scatterlines!(ax, xm, md, color=col, label=lbl, linewidth=2.5)
    @printf("%-14s |β|<15°: trailing-feature fraction %.2f–%.2f%%; median error per bin %s\n", lbl, extrema(ftf[k])...,
            join([@sprintf("%.4f", v) for v in md], " "))
end
hlines!(ax, [0], color=:grey50, linewidth=1); axislegend(ax, position=:lt)
colsize!(fig.layout, 1, Auto(1)); colsize!(fig.layout, 2, Auto(1))
out1 = joinpath(@__DIR__, "..", "figures", "10162026_trailing_feature.png"); save(out1, fig, px_per_unit=2); println("wrote ", normpath(out1))

# ---- figure 2: error vs distance in time to the nearest training day, each version on its own (no averaging) -------
fig2 = Figure(size=(1300, 560), fontsize=16)
ax = Axis(fig2[1, 1], xlabel="days to the nearest training day", ylabel="median |error| (%)", yscale=log10,
          title="Each shifted version separately (5-seed ensemble, no averaging over versions)")
ax2 = Axis(fig2[1, 2], xlabel="days to the nearest training day", ylabel="median signed error (%)",
           title="Signed: the error drifts with distance from the training data")
cols = Makie.wong_colors()
for (j, Δ) in enumerate(SHIFTS16)
    rs = runs16(Δ); te, e = relerr(rs); trd = sort(t_rel[rs[1].tr_idx])
    gap = [(i = searchsortedfirst(trd, t); min(i <= length(trd) ? trd[i] - t : Inf, i > 1 ? t - trd[i-1] : Inf)) for t in t_rel[te]]
    inn = is_interior(Δ, te)
    for (m, ls, lbl) in ((inn, :solid, "shift $(Δ) d"), (.!inn, :dash, ""))
        any(m) || continue
        g, a, s = gap[m], abs.(e[m]), e[m]; edges = 0:1:ceil(Int, maximum(g))
        xm = Float64[]; md = Float64[]; sd = Float64[]
        for b in 1:length(edges)-1
            kk = edges[b] .<= g .< edges[b+1]; sum(kk) < 100 && continue
            push!(xm, (edges[b] + edges[b+1]) / 2); push!(md, median(a[kk])); push!(sd, median(s[kk]))
        end
        lines!(ax, xm, md, color=cols[j], linestyle=ls, linewidth=2.5, label=isempty(lbl) ? nothing : lbl)
        lines!(ax2, xm, sd, color=cols[j], linestyle=ls, linewidth=2.5)
    end
end
hlines!(ax2, [0], color=:black, linewidth=1)
axislegend(ax, position=:lt, labelsize=13, nbanks=2)
Label(fig2[2, :], "solid = held-out windows between training windows (interpolation); dashed = windows at the mission's start or end (extrapolation)", fontsize=14)
out2 = joinpath(@__DIR__, "..", "figures", "10162026_error_vs_gap.png"); save(out2, fig2, px_per_unit=2); println("wrote ", normpath(out2))
