# Week 14 task 4: what model is SPHEREx's zodi column, relative to Kelsall (ZodiPy)? Per exposure (grid 2, all 192 patches, and
# |b| > 15°), the ratio SPHEREx zodi / ZodiPy against solar elongation, ecliptic latitude, time, wavelength and Earth-motion side.
# A multiple regression on log ratio says which geometry SPHEREx's model scales differently from Kelsall.
#     julia --project=. realdata/spherex_vs_kelsall.jl   → figures/11132026_spherex_vs_kelsall.png
using DelimitedFiles, Statistics, Printf, CairoMakie, LinearAlgebra
D = joinpath(@__DIR__, "..", "data", "spherex_real")
O, ho = readdlm(joinpath(D, "ttbin_L6_grid2_offsets.csv"), ',', header=true); ho = vec(ho); col(n) = findfirst(==(n), ho)
sunlon(mjd) = (d = mjd - 51544.5; g = deg2rad(mod(357.528 + 0.9856003d, 360)); mod(280.460 + 0.9856474d + 1.915sin(g) + 0.020sin(2g), 360))
R = Float64[]; EL = Float64[]; B = Float64[]; T = Float64[]; WL = Float64[]; BH = Bool[]; GB = Float64[]; LS = Float64[]
for i in axes(O, 1)
    f = joinpath(D, "ttbin_L6_$(O[i, 1])_ours.csv"); isfile(f) || continue
    X, h = readdlm(f, ',', header=true); h = vec(h); c(n) = Float64.(X[:, findfirst(==(n), h)])
    t, wl, zs, kp = c("t_mid_mjd"), c("wavelength"), c("zodi_spherex"), c("zodipy_lam")
    ok = isfinite.(zs) .& isfinite.(kp) .& (kp .> 0) .& (zs .> 0); any(ok) || continue
    λp, βp = Float64(O[i, col("λ")]), Float64(O[i, col("β")]); ls = sunlon.(t[ok])
    append!(R, zs[ok] ./ kp[ok]); append!(T, t[ok]); append!(WL, wl[ok]); append!(LS, ls)
    append!(EL, acosd.(clamp.(cosd(βp) .* cosd.(λp .- ls), -1, 1))); append!(B, fill(βp, sum(ok)))
    append!(BH, 90 .<= mod.(λp .- (ls .- 90), 360) .< 270); append!(GB, fill(Float64(O[i, col("b")]), sum(ok)))
end
@printf("%d exposures, %d with |b| > 15°\n", length(R), sum(abs.(GB) .> 15))
@printf("SPHEREx zodi / ZodiPy: median %.3f, 16–84%% %.3f–%.3f, min %.3f, max %.3f\n", median(R), quantile(R, 0.16), quantile(R, 0.84), extrema(R)...)
for (lbl, k) in (("|β| < 10°", abs.(B) .< 10), ("10–30°", 10 .<= abs.(B) .< 30), ("30–60°", 30 .<= abs.(B) .< 60), ("|β| ≥ 60°", abs.(B) .>= 60))
    @printf("  %-10s n %5d median ratio %.3f\n", lbl, sum(k), median(R[k]))
end
for (a, b) in ((85, 95), (95, 105), (105, 115), (115, 135))
    k = a .<= EL .< b; @printf("  elongation %3d–%3d° n %5d median ratio %.3f\n", a, b, sum(k), median(R[k]))
end
for (lbl, k) in (("behind Earth", BH), ("ahead of Earth", .!BH)); @printf("  %-15s median ratio %.3f\n", lbl, median(R[k])); end
# regression of log ratio on geometry (all exposures)
y = log.(R)
names = ["const", "elongation (per 10°)", "|β| (per 10°)", "sin|β|²", "behind Earth", "cos(λ_sun)", "sin(λ_sun)", "wavelength (per 0.05 μm)", "time (per 100 d)"]
A = hcat(ones(length(y)), (EL .- 95) ./ 10, abs.(B) ./ 10, sind.(abs.(B)) .^ 2, Float64.(BH), cosd.(LS), sind.(LS), (WL .- 4.95) ./ 0.05, (T .- 61040) ./ 100)
cf = A \ y; r = y .- A * cf; se = sqrt.(diag(inv(A' * A)) .* sum(abs2, r) / (length(y) - size(A, 2)))
@printf("regression of log(SPHEREx/ZodiPy): rms left %.2f%% (of %.2f%%)\n", 100std(r), 100std(y))
for (n, c, s) in zip(names, cf, se); @printf("  %-26s %+.4f ± %.4f  (%+.2f%%)\n", n, c, s, 100(exp(c) - 1)); end

set_theme!(merge(Theme(fontsize=18), theme_black()))
fig = Figure(size=(2000, 600))
ax = Axis(fig[1, 1], xlabel="solar elongation (°)", ylabel="SPHEREx zodi / ZodiPy", title="vs elongation (colour = |β|)")
sc = scatter!(ax, EL, R, color=abs.(B), colormap=:viridis, markersize=4); Colorbar(fig[1, 2], sc, label="|β| (°)")
ax2 = Axis(fig[1, 3], xlabel="|ecliptic latitude| (°)", ylabel="SPHEREx zodi / ZodiPy", title="vs ecliptic latitude")
scatter!(ax2, abs.(B), R, color=(:white, 0.3), markersize=4)
ax3 = Axis(fig[1, 4], xlabel="MJD", ylabel="SPHEREx zodi / ZodiPy", title="vs time (orange = behind Earth)")
scatter!(ax3, T[.!BH], R[.!BH], color=(:deepskyblue, 0.4), markersize=4); scatter!(ax3, T[BH], R[BH], color=(:orange, 0.4), markersize=4)
for a in (ax, ax2, ax3); ylims!(a, quantile(R, 0.002) - 0.02, quantile(R, 0.998) + 0.02); end
save(joinpath(@__DIR__, "..", "figures", "11132026_spherex_vs_kelsall.png"), fig, px_per_unit=1.5)
println("ok")
