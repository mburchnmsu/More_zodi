# Week 14 task 1: the "jump near MJD 61,200" in the NEP time series (figures/11042026_talltable_L8_nep_ours.png).
# Measured − SPHEREx zodi at the NEP against time, split by wavelength (the 4.98–5.01 μm detector edge vs the rest),
# with the number of exposures per 5 days. Also the scatter by wavelength sky-wide (grid 2, |b| > 15°).
#     julia --project=. realdata/nep_burst.jl   → figures/11132026_nep_burst.png
using DelimitedFiles, Statistics, Printf, CairoMakie
D = joinpath(@__DIR__, "..", "data", "spherex_real")
T, h = readdlm(joinpath(D, "tt_L8_nep_ours.csv"), ',', header=true); h = vec(h)
c(n) = Float64.(T[:, findfirst(==(n), h)])
t, w, f, z, o = c("t_mid_mjd"), c("wavelength_median"), c("flux_median"), c("zodi_median"), c("ours_lam")
r = f .- z
loc = [r[i] - median(r[abs.(t .- t[i]) .< 5]) for i in eachindex(t)]      # minus a ±5-day running median
edge = w .>= 4.98; kb = 61145 .<= t .< 61195
@printf("NEP: %d exposures; MJD 61145–61195: %d (%.1f/day vs %.1f/day otherwise), %.0f%% at ≥ 4.98 μm (vs %.0f%%)\n", length(t), sum(kb),
        sum(kb) / 50, sum(.!kb) / (maximum(t) - minimum(t) - 50), 100mean(edge[kb]), 100mean(edge[.!kb]))
@printf("NEP local scatter (MJy/sr): edge %.4f, rest %.4f; median level measured − SPHEREx zodi: before %.4f, burst %.4f, after %.4f\n",
        std(loc[edge]), std(loc[.!edge]), median(r[t .< 61145]), median(r[kb]), median(r[t .>= 61195]))

# sky-wide: scatter of the time residual by wavelength (grid 2, |b| > 15°)
O, ho = readdlm(joinpath(D, "ttbin_L6_grid2_offsets.csv"), ',', header=true); ho = vec(ho)
W = Float64[]; R = Float64[]
for i in axes(O, 1)
    abs(O[i, findfirst(==("b"), ho)]) > 15 || continue
    fn = joinpath(D, "ttbin_L6_$(O[i, 1])_ours.csv"); isfile(fn) || continue
    P, hp = readdlm(fn, ',', header=true); hp = vec(hp); cp(n) = Float64.(P[:, findfirst(==(n), hp)])
    a, b, wl = cp("flux_median"), cp("zodi_spherex"), cp("wavelength"); ok = isfinite.(a) .& isfinite.(b); sum(ok) >= 4 || continue
    x = a[ok] .- b[ok]; append!(R, x .- median(x)); append!(W, wl[ok])
end
println("sky-wide (grid 2, |b| > 15°), measured − SPHEREx zodi minus each patch's median, by wavelength:")
for (a, b) in ((4.88, 4.92), (4.92, 4.95), (4.95, 4.98), (4.98, 5.02))
    k = a .<= W .< b
    sum(k) > 10 && @printf("  %.2f–%.2f μm: n %5d, rms %.4f, 16–84%% half-width %.4f, frac > +0.02 %.3f\n", a, b, sum(k),
                           sqrt(mean(abs2, R[k])), (quantile(R[k], 0.84) - quantile(R[k], 0.16)) / 2, mean(R[k] .> 0.02))
end

set_theme!(merge(Theme(fontsize=18), theme_black()))
fig = Figure(size=(1500, 900))
ax = Axis(fig[1, 1], ylabel="measured − SPHEREx zodi (MJy/sr)", title="North ecliptic pole, tall table 4.9–5.01 μm")
scatter!(ax, t[.!edge], r[.!edge], markersize=5, color=(:white, 0.7), label="4.90–4.98 μm")
scatter!(ax, t[edge], r[edge], markersize=5, color=(:orange, 0.8), label="4.98–5.01 μm (detector edge)")
vspan!(ax, [61145], [61195], color=(:deepskyblue, 0.15)); axislegend(ax, position=:lt)
ax2 = Axis(fig[2, 1], ylabel="exposures per 5 days", xlabel="MJD (61145–61195 = 2026-04-29 to 06-18)")
hist!(ax2, t, bins=range(minimum(t), maximum(t) + 5, step=5), color=:grey70)
vspan!(ax2, [61145], [61195], color=(:deepskyblue, 0.15)); linkxaxes!(ax, ax2); rowsize!(fig.layout, 2, Relative(0.3))
save(joinpath(@__DIR__, "..", "figures", "11132026_nep_burst.png"), fig, px_per_unit=1.5)
println("ok")
