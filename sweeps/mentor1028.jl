# Mentor's requests (Oct 28), on the best model (round 34: parallax band layer, 2000 epochs, 6 shifts × 5 seeds):
#  A. out-of-sample sky error from interpolation windows only (withheld months with training months on both sides),
#     from all withheld windows, and from the extrapolation windows only (first/last withheld month of each split)
#     → figures/r34_interp_extrap_sky.png
#  B. 2-D map of the residuals in a frame tied to Earth's motion: longitude 0–360° measured from Earth's direction of
#     motion (0 = ahead, 180 = behind, where Kelsall's trailing cloud sits; the Sun is at 90°), ecliptic latitude up.
#     Compared with Kelsall's trailing-cloud share of the light and with what a model missing 1% of it would show.
#     → figures/r34_trailing_2d.png
#     julia --project=. sweeps/mentor1028.jl
ENV["ZODI_DATA"] = "z500"; ENV["ZODI_HELIO"] = "1"
using LinearAlgebra; BLAS.set_num_threads(2)
redirect_stdout(devnull) do
    include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
    for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "shift_helpers.jl"); include(joinpath(@__DIR__, f)); end
    include(joinpath(@__DIR__, "configs_v24.jl"))
end
using CairoMakie, JLD2, HDF5
include(joinpath(@__DIR__, "plot_sky_common.jl"))
const FAM = get(ENV, "R34_FAM", "z500h_bandplx2k_shift")
β = Float64.(ecliptic_latitude_deg); aβ = abs.(β)

# ------------------------------------------------------------------------------------------- A. interpolation vs extrapolation
"""Out-of-sample % error, averaged over the splits that withheld each exposure. which = :interior | :edge | :all.
seed = nothing → 5-network average, else that one seed's network."""
function oos(which; seed=nothing)
    s = zeros(N); n = zeros(Int, N)
    for Δ in SHIFTS24
        rs = runs16("$FAM$Δ"); te = rs[1].te_idx; inn = is_interior(Δ, te)
        te = which === :interior ? te[inn] : which === :edge ? te[.!inn] : te
        p = seed === nothing ? ensemble_pred(rs) : rs[seed].ypred
        s[te] .+= p[te]; n[te] .+= 1
    end
    100 .* (ifelse.(n .> 0, s ./ max.(n, 1), NaN) .- y) ./ y
end
function stats(E)
    ok = .!isnan.(E); a = abs.(E[ok]); b = aβ[ok]
    (n=sum(ok), frac=mean(ok), med=median(a), p95=quantile(a, 0.95), ecl=median(a[b .< 2]), pole=median(a[b .>= 60]))
end
EI, EA, EE = oos(:interior), oos(:all), oos(:edge)
println("which windows       exposures  (of all)   median    p95      |β|<2°    |β|≥60°")
for (lbl, E) in (("interpolation only", EI), ("interp + extrap", EA), ("extrapolation only", EE))
    S = stats(E)
    @printf("%-19s %9d  (%5.1f%%)  %.4f%%  %.3f%%  %.4f%%  %.4f%%\n", lbl, S.n, 100S.frac, S.med, S.p95, S.ecl, S.pole)
end
println("\nper shift: median |error| in the interpolation / extrapolation windows (mission days of the extrapolation windows)")
for Δ in SHIFTS24
    te, e = relerr(runs16("$FAM$Δ")); a = abs.(e); inn = is_interior(Δ, te)
    d = t_rel[te[.!inn]]; ends = [d[d .< span_days / 2], d[d .>= span_days / 2]]
    @printf("shift %2d: %.4f%% / %.4f%%   extrap. days %s\n", Δ, median(a[inn]), any(.!inn) ? median(a[.!inn]) : NaN,
            join([@sprintf("%.0f–%.0f", extrema(x)...) for x in ends if !isempty(x)], ", "))
end

set_theme!(merge(Theme(fontsize=17), theme_black()))
fig = Figure(size=(2700, 700)); hm = nothing
for (c, (ttl, E)) in enumerate((("Interpolation windows only (what we usually show)", EI),
                                ("All withheld windows (interpolation + extrapolation)", EA),
                                ("Extrapolation windows only (first / last month withheld)", EE)))
    S = stats(E); G = footprint_stat(E, x -> median(abs.(x)); radius=1.75)
    ax = Axis(fig[1, c], aspect=DataAspect(), title=ttl, titlesize=20); hidedecorations!(ax); hidespines!(ax)
    xs, ys, img = moll_raster(G)
    global hm = heatmap!(ax, xs, ys, img, colormap=:viridis, colorrange=(0.0, 0.08), nan_color=(:grey35, 1.0),
                         highclip=Makie.to_colormap(:viridis)[end]); graticule!(ax)
    Label(fig[2, c], @sprintf("%.0f%% of the exposures · median %.4f%% · p95 %.3f%%\nwithin 2° of the ecliptic %.4f%% · above 60° %.4f%%",
                              100S.frac, S.med, S.p95, S.ecl, S.pole), fontsize=16, tellwidth=false)
end
Colorbar(fig[1, 4], hm, label="median |error| (%), 3.5° patches", height=Relative(0.8))
Label(fig[0, 1:3], "Out-of-sample error, best model (parallax band layer, 2000 epochs, 6 splits × 5 seeds; grey = not covered)",
      font=:bold, fontsize=22)
save(joinpath(@__DIR__, "..", "figures", "r34_interp_extrap_sky.png"), fig, px_per_unit=2)

# ------------------------------------------------------------------------------------------- B. 2-D trailing-cloud residual map
# Frame tied to Earth's motion: x̂ = Earth's velocity projected on the ecliptic plane, ẑ = ecliptic north, ŷ = ẑ × x̂
# (points to the Sun for a circular orbit). φ = longitude from x̂ (0–360°), latitude = ecliptic latitude.
v = copy(v_earth_unit); v[3, :] .= 0; v ./= sqrt.(sum(abs2, v, dims=1))
n = nvec_unit_cartesian
yv = vcat(-v[2:2, :], v[1:1, :], zeros(1, N))                  # ẑ × x̂
φ = mod.(atand.(vec(sum(n .* yv, dims=1)), vec(sum(n .* v, dims=1))), 360)
sunang = mod.(atand.(-vec(sum(earth_positions .* yv, dims=1)), -vec(sum(earth_positions .* v, dims=1))), 360)
@printf("\nSun direction in this frame: φ = %.1f–%.1f° (should be ≈ 90°)\n", extrema(sunang)...)
TF = h5open(f -> read(f["emission_earth_trailing_feature"]), emission_file); share = 100 .* TF ./ y
const W = 3.0                                                  # bin size (°)
nφ, nb = round(Int, 360 / W), round(Int, 180 / W)
bin(i) = (clamp(floor(Int, φ[i] / W) + 1, 1, nφ), clamp(floor(Int, (β[i] + 90) / W) + 1, 1, nb))
"""Per-bin mean of v (exposures where v is not NaN), with the standard error; bins with < minn exposures are NaN."""
function grid(v; minn=30)
    S = zeros(nφ, nb); S2 = zeros(nφ, nb); C = zeros(Int, nφ, nb)
    for i in eachindex(v)
        isnan(v[i]) && continue; a, b = bin(i); S[a, b] += v[i]; S2[a, b] += v[i]^2; C[a, b] += 1
    end
    M = ifelse.(C .>= minn, S ./ max.(C, 1), NaN)
    SE = ifelse.(C .>= minn, sqrt.(max.(S2 ./ max.(C, 1) .- M .^ 2, 0) ./ max.(C .- 1, 1)), NaN)
    M, SE, C
end
tested = .!isnan.(EI)
Gs, _, _ = grid(ifelse.(tested, share, NaN)); Gr, Gse, Gc = grid(EI)
Gmiss = -0.01 .* Gs                                            # residual of a model that missed 1% of the cloud
# missing-fraction fit: residual = a·(cloud %) + b, ensemble and per seed (spread over seeds = uncertainty)
fitA(E, k) = (i = findall(k .& .!isnan.(E)); ([share[i] ones(length(i))] \ E[i])[1])
for (lbl, k) in (("|β| < 15°", aβ .< 15), ("whole sky", trues(N)))
    a = fitA(EI, k); as = [fitA(oos(:interior; seed=s), k) for s in 1:5]
    @printf("missing fraction of the trailing cloud (%s): %+.4f  (seed spread ± %.4f)\n", lbl, a, std(as))
end
# behind-Earth patch (φ 150–210°, |β| < 15°) vs ahead patch (φ −30–30°)
for (lbl, k) in (("behind (φ 150–210°, |β|<15°)", (150 .<= φ .< 210) .& (aβ .< 15)), ("ahead (φ 330–30°, |β|<15°)", ((φ .>= 330) .| (φ .< 30)) .& (aβ .< 15)))
    kk = k .& tested
    @printf("%-30s n=%7d  cloud share %.2f%%  mean residual %+.5f%% ± %.5f%%  median |error| %.4f%%\n", lbl, sum(kk),
            mean(share[kk]), mean(EI[kk]), std(EI[kk]) / sqrt(sum(kk)), median(abs.(EI[kk])))
end
@printf("covered: %.1f%% of the 3°×3° cells in the 0–360° × ±90° frame\n", 100mean(.!isnan.(Gr)))

fig = Figure(size=(2000, 1250)); xφ = (0:nφ-1) .* W .+ W / 2; xb = (0:nb-1) .* W .- 90 .+ W / 2
function panel(pos, G, ttl, cmap, cr, lbl)
    ax = Axis(pos, title=ttl, titlesize=19, xlabel="longitude from Earth's direction of motion (°):  0 = ahead · 90 = Sun · 180 = behind · 270 = anti-Sun",
              ylabel="ecliptic latitude (°)", xticks=0:30:360, yticks=-90:30:90, backgroundcolor=:grey25)
    h = heatmap!(ax, xφ, xb, G, colormap=cmap, colorrange=cr, nan_color=(:grey25, 1.0), lowclip=Makie.to_colormap(cmap)[1],
                 highclip=Makie.to_colormap(cmap)[end])
    vlines!(ax, [0, 180, 360], color=(:white, 0.4), linestyle=:dash); xlims!(ax, 0, 360); ylims!(ax, -90, 90)
    Colorbar(pos[1, 2], h, label=lbl); ax
end
panel(fig[1, 1], Gs, "What Kelsall predicts: the trailing cloud's share of the light", :inferno, (0, 8), "% of the total")
panel(fig[1, 2], Gmiss, "What the residuals would look like if 1% of the cloud were missed", Reverse(:RdBu_9), (-0.03, 0.03), "residual (%)")
panel(fig[2, 1], Gr, "Our residuals: mean (network − Kelsall) on withheld months", Reverse(:RdBu_9), (-0.03, 0.03), "mean residual (%)")
panel(fig[2, 2], Gr ./ Gse, "Our residuals in units of their standard error (mean / s.e.)", Reverse(:RdBu_9), (-5, 5), "σ")
Label(fig[0, 1:2], "Earth-trailing cloud: residuals of the best model (parallax band layer, 2000 epochs) on the full 0–360° sky, 3° bins (grey = SPHEREx never looks there)",
      font=:bold, fontsize=21)
save(joinpath(@__DIR__, "..", "figures", "r34_trailing_2d.png"), fig, px_per_unit=2)
println("ok")
