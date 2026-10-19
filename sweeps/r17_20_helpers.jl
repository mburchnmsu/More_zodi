# Helpers for 10172026.ipynb (rounds 17–20, Oct 16–17): loss curves for the 80/20 split and the shifted month splits,
# why they are jagged and how to smooth them, error vs time gap, the Earth-trailing feature check, and the 300-epoch
# month-split sky map. Requires ENV["ZODI_DATA"] = "z115", zodi_setup.jl, mb_train.jl, extra_features.jl,
# summary_helpers.jl, configs_v16.jl and shift_helpers.jl (runs16, relerr, is_interior, footprint_stat, ...).
# The standalone scripts sweeps/plot_chrono_loss.jl, trailing_check.jl, plot_smooth_loss.jl, plot_ch300.jl and
# plot_m300.jl draw the same figures to figures/1016…/1017….png.

H(rs, f) = reduce(hcat, [Float64.(getfield(r, f)) for r in rs])          # epochs × seeds
meancurve(rs, f) = vec(mean(reduce(hcat, [f(r) for r in rs]), dims=2))
"""Mean of the in-epoch evaluations of each epoch (runs trained with evals_per_epoch > 0)."""
function epoch_avg(r)
    tr = zeros(r.epochs); te = zeros(r.epochs)
    for e in 1:r.epochs
        k = findall(x -> e - 1 < x <= e + 1e-9, r.fine_epoch); tr[e] = mean(r.tr_fine[k]); te[e] = mean(r.te_fine[k])
    end
    tr, te
end
"""Typical epoch-to-epoch jump of a curve: median |Δ log10| over the middle 60% of the run."""
roughness(v) = (n = length(v); median(abs.(diff(log10.(v[max(1, round(Int, 0.2n)):round(Int, 0.8n)])))))
function dayspan(idx)                      # contiguous day ranges covered by idx, e.g. "0–20, 110–140"
    d = sort(t_rel[idx]); s = [d[1]]; e = Float64[]
    for i in 2:length(d)
        d[i] - d[i-1] > 1 && (push!(e, d[i-1]); push!(s, d[i]))
    end
    push!(e, d[end])
    join([@sprintf("%.0f–%.0f", a, b) for (a, b) in zip(s, e)], ", ")
end
ens_err(rs) = (te = rs[1].te_idx; e = ensemble_pred(rs); (e, te, 100 .* (e[te] .- y[te]) ./ y[te]))

# ---------------------------------------------------------------------------------------------------- loss curves
"""Raw end-of-epoch train/test MSE (5 seeds thin, mean thick), one panel per run family."""
function raw_loss_fig(panels)
    fig = Figure(size=(1650, 600), fontsize=16); axs = Axis[]
    for (c, (key, ttl)) in enumerate(panels)
        rs = runs16(key); TR, TE = H(rs, :tr_hist), H(rs, :te_hist); ep = 0:size(TR, 1)-1
        _, te, rel = ens_err(rs)
        ax = Axis(fig[1, c], yscale=log10, xlabel="epoch", ylabel=c == 1 ? "MSE  (MJy/sr)²" : "", title=ttl,
                  subtitle="test days " * dayspan(te), titlesize=16, subtitlesize=13)
        push!(axs, ax)
        for s in 1:size(TR, 2)
            lines!(ax, ep, TR[:, s], color=(:steelblue, 0.3), linewidth=1); lines!(ax, ep, TE[:, s], color=(:crimson, 0.3), linewidth=1)
        end
        lines!(ax, ep, vec(mean(TR, dims=2)), color=:steelblue, linewidth=3, label="train")
        lines!(ax, ep, vec(mean(TE, dims=2)), color=:crimson, linewidth=3, label="test")
        c == 1 && axislegend(ax, position=:rt)
        text!(ax, 0.03, 0.03, space=:relative, align=(:left, :bottom), fontsize=13,
              text=@sprintf("final: train %.1e, test %.1e (%.0f×)\n5-net average: median |err| %.3f%%, p95 %.2f%%",
                            mean(TR[end, :]), mean(TE[end, :]), mean(TE[end, :]) / mean(TR[end, :]), median(abs.(rel)), quantile(abs.(rel), 0.95)))
    end
    linkyaxes!(axs...)
    Label(fig[0, 1:length(panels)], "Train vs test MSE (5 networks thin, mean thick; raw end-of-epoch values)", font=:bold, fontsize=17)
    fig
end

"""Ensemble MSE at every `step`-th epoch end, from weight snapshots (runs with keep_snaps). Full train/test sets."""
function ensemble_curve(rs; step=5)
    r1 = rs[1]; cols = [findfirst(==(nm), dot_names_all) for nm in r1.feature_names]
    X = Float32.(((Fd_raw[:, cols] .- r1.μ') ./ r1.σ')'); idx = vcat(r1.tr_idx, r1.te_idx); Xs = X[:, idx]
    ntr = length(r1.tr_idx); yt = Float32.(y[idx]); re = Optimisers.destructure(r1.model)[2]
    eps = collect(0:step:r1.epochs); trE = zeros(length(eps)); teE = zeros(length(eps))
    for (j, e) in enumerate(eps)
        k = findfirst(x -> abs(x - e) < 1e-9, r1.fine_epoch)
        P = mean(predict_batched(re(r.snaps[k]), Xs) for r in rs)
        trE[j] = mean(abs2, P[1:ntr] .- yt[1:ntr]); teE[j] = mean(abs2, P[ntr+1:end] .- yt[ntr+1:end])
    end
    eps, trE, teE
end

"""(a) epoch-averaged loss per family (top row); (b) the 5-network ensemble's loss for the first family (bottom left)."""
function smooth_loss_fig(panels; ens_step=5)
    fig = Figure(size=(1700, 1100), fontsize=15); rows = []
    for (c, (key, ttl)) in enumerate(panels)
        rs = runs16(key); ep = 0:rs[1].epochs
        tra, tea = meancurve(rs, r -> epoch_avg(r)[1]), meancurve(rs, r -> epoch_avg(r)[2])
        ax = Axis(fig[1, c], yscale=log10, title=ttl, subtitle="(a) averaged over 10 points per epoch", xlabel="epoch",
                  ylabel=c == 1 ? "MSE  (MJy/sr)²" : "", titlesize=16, subtitlesize=13)
        lines!(ax, ep, meancurve(rs, r -> r.tr_hist), color=(:steelblue, 0.3), linewidth=1.2)
        lines!(ax, ep, meancurve(rs, r -> r.te_hist), color=(:crimson, 0.3), linewidth=1.2)
        lines!(ax, 1:rs[1].epochs, tra, color=:steelblue, linewidth=3, label="train")
        lines!(ax, 1:rs[1].epochs, tea, color=:crimson, linewidth=3, label="test")
        c == 1 && axislegend(ax, position=:rt)
        push!(rows, (ttl, roughness(meancurve(rs, r -> r.te_hist)), roughness(tea)))
        if c == 1                                               # ensemble curve (slow: one family only)
            eps, trE, teE = ensemble_curve(rs; step=ens_step)
            ax2 = Axis(fig[2, 1], yscale=log10, subtitle="(b) loss of the 5-network average, every $(ens_step) epochs, full sets",
                       xlabel="epoch", ylabel="MSE  (MJy/sr)²", subtitlesize=13)
            lines!(ax2, ep, meancurve(rs, r -> r.tr_hist), color=(:steelblue, 0.3), linewidth=1.2)
            lines!(ax2, ep, meancurve(rs, r -> r.te_hist), color=(:crimson, 0.3), linewidth=1.2)
            scatterlines!(ax2, eps, trE, color=:steelblue, linewidth=3, markersize=5)
            scatterlines!(ax2, eps, teE, color=:crimson, linewidth=3, markersize=5)
            linkyaxes!(ax, ax2)
        end
    end
    Label(fig[0, 1:length(panels)], "Smoothed loss curves — faint: the raw end-of-epoch curves (mean of 5 networks)", font=:bold, fontsize=17)
    df = DataFrame(run=first.(rows), test_roughness_raw=round.(getindex.(rows, 2), digits=3),
                   test_roughness_epoch_avg=round.(getindex.(rows, 3), digits=3))
    fig, df
end

"""Same split, different training length / peak LR: epoch-averaged loss + a summary table."""
function lr_epochs_fig(arms)
    fig = Figure(size=(1750, 620), fontsize=15); axs = Axis[]
    df = DataFrame(run=String[], epochs=Int[], lr_max=Float64[], test_roughness=Float64[], final_train_mse=String[],
                   final_test_mse=String[], ens_test_mse=String[], ens_median_pct=Float64[], ens_p95_pct=Float64[])
    for (c, (key, ttl)) in enumerate(arms)
        rs = runs16(key); tra, tea = meancurve(rs, r -> epoch_avg(r)[1]), meancurve(rs, r -> epoch_avg(r)[2])
        e, te, rel = ens_err(rs); ep = 0:rs[1].epochs
        ax = Axis(fig[1, c], yscale=log10, title=ttl, xlabel="epoch", ylabel=c == 1 ? "MSE  (MJy/sr)²" : "", titlesize=16)
        push!(axs, ax)
        lines!(ax, ep, meancurve(rs, r -> r.tr_hist), color=(:steelblue, 0.3), linewidth=1.2)
        lines!(ax, ep, meancurve(rs, r -> r.te_hist), color=(:crimson, 0.3), linewidth=1.2)
        lines!(ax, 1:rs[1].epochs, tra, color=:steelblue, linewidth=3, label="train")
        lines!(ax, 1:rs[1].epochs, tea, color=:crimson, linewidth=3, label="test")
        c == 1 && axislegend(ax, position=:rt)
        push!(df, (ttl, rs[1].epochs, rs[1].lr_max, round(roughness(tea), digits=3), sci(mean(r.tr_hist[end] for r in rs)),
                   sci(mean(r.te_hist[end] for r in rs)), sci(mean(abs2, e[te] .- y[te])), round(median(abs.(rel)), digits=4),
                   round(quantile(abs.(rel), 0.95), digits=3)))
    end
    linkyaxes!(axs...)
    Label(fig[0, 1:length(arms)], "80/20 chronological: epoch-averaged loss (mean of 5 networks; faint = raw end-of-epoch values)", font=:bold, fontsize=17)
    fig, df
end

# ---------------------------------------------------------------------------------------------------- time gap
"""Each shifted version on its own: median |error| and signed error vs days to the nearest training day."""
function error_vs_gap_fig(fam=identity)
    fig = Figure(size=(1300, 560), fontsize=15)
    ax = Axis(fig[1, 1], xlabel="days to the nearest training day", ylabel="median |error| (%)", yscale=log10,
              title="Each shifted version separately (5-network average)")
    ax2 = Axis(fig[1, 2], xlabel="days to the nearest training day", ylabel="median signed error (%)", title="Signed error")
    cols = Makie.wong_colors()
    for (j, Δ) in enumerate(SHIFTS16)
        rs = runs16(fam(Δ)); te, e = relerr(rs); trd = sort(t_rel[rs[1].tr_idx])
        gap = [(i = searchsortedfirst(trd, t); min(i <= length(trd) ? trd[i] - t : Inf, i > 1 ? t - trd[i-1] : Inf)) for t in t_rel[te]]
        inn = is_interior(Δ, te)
        for (m, ls, lbl) in ((inn, :solid, "shift $(Δ) d"), (.!inn, :dash, nothing))
            any(m) || continue
            g, s = gap[m], e[m]; xm = Float64[]; md = Float64[]; sd = Float64[]
            for b in 0:ceil(Int, maximum(g)) - 1
                kk = b .<= g .< b + 1; sum(kk) < 100 && continue
                push!(xm, b + 0.5); push!(md, median(abs.(s[kk]))); push!(sd, median(s[kk]))
            end
            lines!(ax, xm, md, color=cols[j], linestyle=ls, linewidth=2.5, label=lbl)
            lines!(ax2, xm, sd, color=cols[j], linestyle=ls, linewidth=2.5)
        end
    end
    hlines!(ax2, [0], color=:grey50, linewidth=1); axislegend(ax, position=:lt, labelsize=12, nbanks=2)
    Label(fig[2, :], "solid = held-out windows between training windows (interpolation); dashed = windows at the mission's start or end (extrapolation)", fontsize=13)
    fig
end

# ---------------------------------------------------------------------------------------------------- trailing feature
const TF_EMISSION = h5open(f -> read(f["emission_earth_trailing_feature"]), emission_file)
"""Look direction relative to the Sun (Δλ, ecliptic longitude from the Sun) and n·vE for every exposure."""
function sun_frame_coords()
    S = spherex_positions; n = nvec_unit_cartesian
    lsun = atand.(-S[2, :], -S[1, :]); lon_n = atand.(n[2, :], n[1, :])
    (mod.(lon_n .- lsun .+ 180, 360) .- 180, vec(sum(n .* v_earth_unit, dims=1)))
end
function cellmap(xv, yv, v, keep; xr, yr=(-90, 90), d=2.0, minn=5)
    nx, ny = round(Int, (xr[2] - xr[1]) / d), round(Int, (yr[2] - yr[1]) / d)
    B = [Float64[] for _ in 1:nx, _ in 1:ny]
    for i in findall(keep)
        push!(B[clamp(floor(Int, (xv[i] - xr[1]) / d) + 1, 1, nx), clamp(floor(Int, (yv[i] - yr[1]) / d) + 1, 1, ny)], v[i])
    end
    range(xr[1] + d / 2, xr[2] - d / 2, length=nx), range(yr[1] + d / 2, yr[2] - d / 2, length=ny), [length(b) >= minn ? median(b) : NaN for b in B]
end
"""The ZodiPy trailing-feature component vs the out-of-sample error (round-16 interior windows), leading vs trailing side."""
function trailing_feature_fig()
    ftf = 100 .* TF_EMISSION ./ y; dlam, nvE = sun_frame_coords(); β = Float64.(ecliptic_latitude_deg)
    err = oos_prediction(which=:interior).err_pct; ok = .!isnan.(err)
    fig = Figure(size=(1500, 1250), fontsize=15)
    Label(fig[0, 1:2], "Is the Earth-trailing dust feature modelled well?  (out-of-sample error, between-month windows, round 16)", font=:bold, fontsize=18)
    for (c, (ttl, side, xr)) in enumerate((("leading side (looking ahead of Earth, n·vE > 0)", nvE .> 0, (-136, -76)),
                                          ("trailing side (looking behind Earth, n·vE < 0)", nvE .< 0, (76, 136))))
        Label(fig[1, c, Top()], ttl, font=:bold, fontsize=15, padding=(0, 0, 28, 0))
        xs, ys, G1 = cellmap(dlam, β, ftf, side .& ok; xr)
        ax = Axis(fig[1, c], title="ZodiPy trailing feature, % of the total", xlabel="longitude from the Sun Δλ (°)", ylabel="ecliptic latitude (°)")
        hm = heatmap!(ax, xs, ys, G1, colormap=:magma, colorrange=(0, maximum(filter(!isnan, G1))), nan_color=:grey85)
        Colorbar(fig[1, c][1, 2], hm, label="% of total")
        xs, ys, G2 = cellmap(dlam, β, err, side .& ok; xr)
        ax = Axis(fig[2, c], title="median signed error (network − ZodiPy), %", xlabel="longitude from the Sun Δλ (°)", ylabel="ecliptic latitude (°)")
        hm = heatmap!(ax, xs, ys, G2, colormap=:balance, colorrange=(-0.06, 0.06), nan_color=:grey85)
        Colorbar(fig[2, c][1, 2], hm, label="error (%)")
    end
    ax = Axis(fig[3, 1:2], xlabel="trailing feature, % of the total brightness along the line of sight", ylabel="error (%)",
              title="Error vs how much of the light comes from the trailing feature (|β| < 15°; median and 16–84% range per bin)")
    df = DataFrame(side=String[], feature_pct_range=String[], median_err_per_bin_range=String[])
    for (lbl, side, col) in (("leading side", nvE .> 0, :steelblue), ("trailing side", nvE .< 0, :crimson))
        k = findall(side .& ok .& (abs.(β) .< 15)); edges = quantile(ftf[k], range(0, 1, length=21))
        xm, md, lo, hi = Float64[], Float64[], Float64[], Float64[]
        for b in 1:20
            kk = k[edges[b] .<= ftf[k] .<= edges[b+1]]; length(kk) < 50 && continue
            push!(xm, median(ftf[kk])); push!(md, median(err[kk])); push!(lo, quantile(err[kk], 0.16)); push!(hi, quantile(err[kk], 0.84))
        end
        band!(ax, xm, lo, hi, color=(col, 0.2)); scatterlines!(ax, xm, md, color=col, label=lbl, linewidth=2.5)
        push!(df, (lbl, @sprintf("%.2f–%.2f%%", extrema(ftf[k])...), @sprintf("%+.3f … %+.3f%%", extrema(md)...)))
    end
    hlines!(ax, [0], color=:grey50, linewidth=1); axislegend(ax, position=:lt)
    colsize!(fig.layout, 1, Auto(1)); colsize!(fig.layout, 2, Auto(1))
    fig, df
end

# ---------------------------------------------------------------------------------------------------- 300-epoch sky map
fam100(Δ) = Δ                                # round 16 (100 epochs); Δ = 0 is z115_sunseason_blk
fam300(Δ) = "z115_m300_shift$Δ"              # round 20 (300 epochs)
"""Out-of-sample error (%) per exposure from the between-month windows, averaged over the versions that held it out."""
function oos_interior(fam)
    s = zeros(N); n = zeros(Int, N)
    for Δ in SHIFTS16
        rs = runs16(fam(Δ)); te = rs[1].te_idx; te = te[is_interior(Δ, te)]
        s[te] .+= ensemble_pred(rs)[te]; n[te] .+= 1
    end
    100 .* (ifelse.(n .> 0, s ./ max.(n, 1), NaN) .- y) ./ y
end
function sky_stats(e)
    ok = .!isnan.(e); a = abs.(e[ok]); b = abs.(Float64.(ecliptic_latitude_deg[ok]))
    (; n=sum(ok), med=median(a), p95=quantile(a, 0.95), ecl=median(a[b .< 2]), pole=median(a[b .>= 60]))
end
fam750(Δ) = "z115_m750_shift$Δ"              # round 21 (750 epochs)
"""Out-of-sample sky maps for several training lengths side by side (same colour scale) + a summary table.
radius = footprint radius in degrees: 1.75 → 3.5°-wide patches (≈ SPHEREx's view); 3.5 → the 7° blend chosen on Oct 18."""
function skymap_100v300_fig(fams=((fam100, 100), (fam300, 300)); radius=1.75)
    fig = Figure(size=(900length(fams), 640), fontsize=16); hm = nothing
    df = DataFrame(epochs=Int[], exposures=Int[], median_pct=Float64[], p95_pct=Float64[], ecliptic_lt2deg_pct=Float64[], above60deg_pct=Float64[])
    for (c, (fam, ep)) in enumerate(fams)
        E = oos_interior(fam); S = sky_stats(E); push!(df, (ep, S.n, round(S.med, digits=4), round(S.p95, digits=3), round(S.ecl, digits=4), round(S.pole, digits=4)))
        ax = Axis(fig[1, c], title="$ep epochs", titlesize=18, aspect=DataAspect(), subtitlesize=13,
                  subtitle=@sprintf("median |error| %.4f%%; within 2° of the ecliptic %.4f%%, above 60° %.4f%%", S.med, S.ecl, S.pole))
        hidedecorations!(ax); hidespines!(ax)
        xs, ys, img = moll_raster(footprint_stat(E, x -> median(abs.(x)); radius))
        hm = heatmap!(ax, xs, ys, img, colormap=:viridis, colorrange=(0.0, 0.08), nan_color=(:grey80, 1.0), highclip=Makie.to_colormap(:viridis)[end])
        graticule!(ax)
    end
    Colorbar(fig[1, length(fams) + 1], hm, label="median |error| (%)", height=Relative(0.75))
    Label(fig[0, 1:length(fams)], @sprintf("Out-of-sample error on the sky, between-month windows of the 6 shifted 30-day splits (5 networks each; %.1f° patches; grey = not tested)", 2radius),
          font=:bold, fontsize=17)
    fig, df
end
"""The same out-of-sample map drawn with bigger patches (footprint radius in degrees): blending for display only —
each patch is still the median of the errors at the boresights it covers."""
function skymap_blend_fig(fam=fam300; radii=(1.75, 3.5, 5.0))
    E = oos_interior(fam); fig = Figure(size=(1900, 560), fontsize=15); hm = nothing
    for (c, r) in enumerate(radii)
        ax = Axis(fig[1, c], title=@sprintf("patches %.1f° wide%s", 2r, r == 1.75 ? " (as before: ≈ SPHEREx's view)" : ""),
                  titlesize=15, aspect=DataAspect())
        hidedecorations!(ax); hidespines!(ax)
        xs, ys, img = moll_raster(footprint_stat(E, x -> median(abs.(x)); radius=r))
        hm = heatmap!(ax, xs, ys, img, colormap=:viridis, colorrange=(0.0, 0.08), nan_color=(:grey80, 1.0), highclip=Makie.to_colormap(:viridis)[end])
        graticule!(ax)
    end
    Colorbar(fig[1, length(radii) + 1], hm, label="median |error| (%)", height=Relative(0.75))
    Label(fig[0, 1:length(radii)], "300-epoch out-of-sample sky map, blended by drawing each pointing as a bigger patch (display only; same data)", font=:bold, fontsize=17)
    fig
end

"""Grid of out-of-sample sky maps: rows = drawing (3.5° patches, 7° blend), columns = training length. Same colour
scale everywhere; blending is display only (each patch is the median of the boresight errors it covers)."""
function skymap_grid_fig(fams=((fam100, 100), (fam300, 300), (fam750, 750)); radii=(1.75, 3.5))
    nc = length(fams); fig = Figure(size=(820nc + 160, 420length(radii) + 140), fontsize=15); hm = nothing
    for (c, (fam, ep)) in enumerate(fams)
        E = oos_interior(fam); S = sky_stats(E)
        Label(fig[0, c], ep isa Integer ? "$ep epochs" : string(ep), font=:bold, fontsize=19, tellwidth=false)
        Label(fig[length(radii) + 1, c], @sprintf("median %.4f%%  ·  p95 %.3f%%\nwithin 2° of the ecliptic %.4f%%  ·  above 60° %.4f%%",
                                                   S.med, S.p95, S.ecl, S.pole), fontsize=14, tellwidth=false)
        for (r_, r) in enumerate(radii)
            ax = Axis(fig[r_, c], aspect=DataAspect()); hidedecorations!(ax); hidespines!(ax)
            xs, ys, img = moll_raster(footprint_stat(E, x -> median(abs.(x)); radius=r))
            hm = heatmap!(ax, xs, ys, img, colormap=:viridis, colorrange=(0.0, 0.08), nan_color=(:grey80, 1.0),
                          highclip=Makie.to_colormap(:viridis)[end])
            graticule!(ax)
        end
    end
    for (r_, r) in enumerate(radii)
        Label(fig[r_, 0], r == 1.75 ? "no blending\n(3.5° patches ≈\nSPHEREx's view)" : @sprintf("blended\n(%.0f° patches)", 2r),
              rotation=0, fontsize=15, font=:bold, tellheight=false)
    end
    Colorbar(fig[1:length(radii), nc + 1], hm, label="median |error| (%)", height=Relative(0.8))
    Label(fig[-1, 1:nc], "Out-of-sample error on the sky — month-on/month-off splits (6 shifts × 5 networks, between-month windows; grey = not tested)",
          font=:bold, fontsize=18)
    fig
end

"""Per shift: median |error| between months and at the start/end, for each training length."""
function m300_table(fams=((fam100, 100), (fam300, 300)))
    df = DataFrame(shift_days=SHIFTS16)
    for (fam, ep) in fams
        v = map(SHIFTS16) do Δ
            te, e = relerr(runs16(fam(Δ))); inn = is_interior(Δ, te)
            (round(median(abs.(e[inn])), digits=4), any(.!inn) ? round(median(abs.(e[.!inn])), digits=4) : NaN)
        end
        df[!, "between_$(ep)ep"] = first.(v); df[!, "ends_$(ep)ep"] = last.(v)
    end
    df
end
"""Epoch-averaged train/test MSE for every shift (default: the 300-epoch runs)."""
function loss_m300_fig(fam=fam300)
    fig = Figure(size=(1700, 950), fontsize=15); axs = Axis[]
    for (k, Δ) in enumerate(SHIFTS16)
        rs = runs16(fam(Δ)); r_, c_ = fldmod1(k, 3); ep = 0:rs[1].epochs
        ax = Axis(fig[r_, c_], yscale=log10, title="shift $(Δ) d: test days " * held_out_days(Δ), titlesize=14,
                  xlabel=r_ == 2 ? "epoch" : "", ylabel=c_ == 1 ? "MSE  (MJy/sr)²" : "")
        push!(axs, ax)
        lines!(ax, ep, meancurve(rs, r -> r.tr_hist), color=(:steelblue, 0.3), linewidth=1)
        lines!(ax, ep, meancurve(rs, r -> r.te_hist), color=(:crimson, 0.3), linewidth=1)
        lines!(ax, 1:rs[1].epochs, meancurve(rs, r -> epoch_avg(r)[1]), color=:steelblue, linewidth=2.5, label="train")
        lines!(ax, 1:rs[1].epochs, meancurve(rs, r -> epoch_avg(r)[2]), color=:crimson, linewidth=2.5, label="test")
        k == 1 && axislegend(ax, position=:rt)
    end
    linkyaxes!(axs...)
    Label(fig[0, 1:3], "Month-to-month splits, $(runs16(fam(0))[1].epochs) epochs: epoch-averaged train/test MSE (mean of 5 networks; faint = raw end-of-epoch values)",
          font=:bold, fontsize=17)
    fig
end
