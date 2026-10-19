# Round 20: month-to-month splits at 300 epochs vs the round-16 100-epoch runs.
#   (1) out-of-sample sky-error map (between-month windows only), 100 vs 300 epochs side by side, same colour scale,
#       each exposure drawn as a 3.5°-wide patch (footprint_stat) → figures/10172026_skymap_100v300.png
#   (2) epoch-averaged train/test MSE for every shift at 300 epochs           → figures/10172026_loss_m300.png
#   julia --project=. sweeps/plot_m300.jl
ENV["ZODI_DATA"] = "z115"
using LinearAlgebra; BLAS.set_num_threads(2)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "configs_v16.jl", "shift_helpers.jl")
    include(joinpath(@__DIR__, f))
end
fam100(Δ) = Δ                               # runs16(Δ) → round-16 runs (Δ = 0: z115_sunseason_blk)
fam300(Δ) = "z115_m300_shift$Δ"
"""Out-of-sample prediction from the between-month (interior) windows: mean over the versions that held each exposure out."""
function oos_interior(fam)
    s = zeros(N); n = zeros(Int, N)
    for Δ in SHIFTS16
        rs = runs16(fam(Δ)); @assert length(rs) == 5 "$(fam(Δ)): expected 5 seeds, found $(length(rs))"
        te = rs[1].te_idx; te = te[is_interior(Δ, te)]
        s[te] .+= ensemble_pred(rs)[te]; n[te] .+= 1
    end
    p = ifelse.(n .> 0, s ./ max.(n, 1), NaN); 100 .* (p .- y) ./ y
end
β = abs.(Float64.(ecliptic_latitude_deg))
stats(e) = (ok = .!isnan.(e); a = abs.(e[ok]); b = β[ok];
            (; n=sum(ok), med=median(a), p95=quantile(a, 0.95), ecl=median(a[b .< 2]), pole=median(a[b .>= 60])))

E100, E300 = oos_interior(fam100), oos_interior(fam300)
S100, S300 = stats(E100), stats(E300)
fig = Figure(size=(1800, 640), fontsize=16)
for (c, (E, S, ttl)) in enumerate(((E100, S100, "100 epochs (as on the poster)"), (E300, S300, "300 epochs")))
    G = footprint_stat(E, x -> median(abs.(x)))
    ax = Axis(fig[1, c], title=ttl, titlesize=18, aspect=DataAspect(),
              subtitle=@sprintf("median |error| %.4f%% (p95 %.3f%%); within 2° of the ecliptic %.4f%%, above 60° %.4f%%",
                                S.med, S.p95, S.ecl, S.pole), subtitlesize=13)
    hidedecorations!(ax); hidespines!(ax)
    xs, ys, img = moll_raster(G)
    global hm = heatmap!(ax, xs, ys, img, colormap=:viridis, colorrange=(0.0, 0.08), nan_color=(:grey80, 1.0),
                         highclip=Makie.to_colormap(:viridis)[end])
    graticule!(ax)
end
Colorbar(fig[1, 3], hm, label="median |error| (%)", height=Relative(0.75))
Label(fig[0, 1:2], "Out-of-sample error on the sky, between-month windows of the 6 shifted 30-day splits (5 networks each; ecliptic coordinates; grey = not tested)",
      font=:bold, fontsize=17)
out1 = joinpath(@__DIR__, "..", "figures", "10172026_skymap_100v300.png"); save(out1, fig, px_per_unit=2); println("wrote ", normpath(out1))
for (lbl, S) in (("100 epochs", S100), ("300 epochs", S300))
    @printf("%-10s %d exposures: median %.4f%%  p95 %.3f%%  |β|<2° %.4f%%  |β|≥60° %.4f%%\n", lbl, S.n, S.med, S.p95, S.ecl, S.pole)
end
# per-shift medians (between-month and start/end windows), 100 vs 300 epochs
for Δ in SHIFTS16, (lbl, fam) in (("100", fam100), ("300", fam300))
    te, e = relerr(runs16(fam(Δ))); inn = is_interior(Δ, te)
    @printf("shift %2d d, %s ep: between-month median %.4f%%%s\n", Δ, lbl, median(abs.(e[inn])),
            any(.!inn) ? @sprintf(", start/end median %.4f%%", median(abs.(e[.!inn]))) : "")
end

# (2) epoch-averaged loss curves at 300 epochs
function epoch_avg(r)
    tr = zeros(r.epochs); te = zeros(r.epochs)
    for e in 1:r.epochs
        k = findall(x -> e - 1 < x <= e + 1e-9, r.fine_epoch); tr[e] = mean(r.tr_fine[k]); te[e] = mean(r.te_fine[k])
    end
    tr, te
end
meancurve(rs, f) = vec(mean(reduce(hcat, [f(r) for r in rs]), dims=2))
fig2 = Figure(size=(1700, 950), fontsize=15); axs = Axis[]
for (k, Δ) in enumerate(SHIFTS16)
    rs = runs16(fam300(Δ)); r_, c_ = fldmod1(k, 3)
    ax = Axis(fig2[r_, c_], yscale=log10, title="shift $(Δ) d: test days " * held_out_days(Δ), titlesize=14,
              xlabel=r_ == 2 ? "epoch" : "", ylabel=c_ == 1 ? "MSE  (MJy/sr)²" : "")
    push!(axs, ax); ep = 0:rs[1].epochs
    lines!(ax, ep, meancurve(rs, r -> r.tr_hist), color=(:steelblue, 0.3), linewidth=1)
    lines!(ax, ep, meancurve(rs, r -> r.te_hist), color=(:crimson, 0.3), linewidth=1)
    lines!(ax, 1:rs[1].epochs, meancurve(rs, r -> epoch_avg(r)[1]), color=:steelblue, linewidth=2.5, label="train")
    lines!(ax, 1:rs[1].epochs, meancurve(rs, r -> epoch_avg(r)[2]), color=:crimson, linewidth=2.5, label="test")
    k == 1 && axislegend(ax, position=:rt)
end
linkyaxes!(axs...)
Label(fig2[0, 1:3], "Month-to-month splits, 300 epochs: epoch-averaged train/test MSE (mean of 5 networks; faint = raw end-of-epoch values)",
      font=:bold, fontsize=17)
out2 = joinpath(@__DIR__, "..", "figures", "10172026_loss_m300.png"); save(out2, fig2, px_per_unit=2); println("wrote ", normpath(out2))
