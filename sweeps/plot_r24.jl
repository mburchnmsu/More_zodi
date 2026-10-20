# Round 24 figures (dark theme): 140-day (poster model, 750 epochs) vs 500-day (poster model + n·J, 500 epochs)
#   figures/10202026_skymap_140v500.png  — out-of-sample sky-error maps, 3.5° patches and 7° blend, same colour scale
#   figures/10202026_loss_140v500.png    — epoch-averaged train/test MSE vs epoch and vs number of training updates
# Inputs: poster/fig_skyerror.jld2, poster/fig_training.jld2 (140 days), sweeps/results_z500/r24_summary.jld2 (sweeps/r24_data.jl)
#   julia --project=. sweeps/plot_r24.jl
using CairoMakie, JLD2, Statistics, Printf
const R = joinpath(@__DIR__, "..")
S140 = JLD2.load(joinpath(R, "poster", "fig_skyerror.jld2")); T140 = JLD2.load(joinpath(R, "poster", "fig_training.jld2"))
S500 = JLD2.load(joinpath(R, "sweeps", "results_z500", "r24_summary.jld2"))
st = S500["stats"]; done = S500["done"]
set_theme!(merge(Theme(fontsize=17), theme_black()))

function moll_fwd(lon, lat)
    λ = deg2rad(mod(lon + 180, 360) - 180); φ = deg2rad(lat); θ = φ
    for _ in 1:50; abs(φ) > π/2 - 1e-9 && break; Δ = (2θ + sin(2θ) - π * sin(φ)) / (2 + 2cos(2θ)); θ -= Δ; abs(Δ) < 1e-12 && break; end
    (-2√2 / π * λ * cos(θ), √2 * sin(θ))
end
function moll_raster(G; nx=1400)
    res = 360 / size(G, 1); ny = nx ÷ 2; img = fill(NaN, nx, ny); xs = range(-2√2, 2√2, length=nx); ys = range(-√2, √2, length=ny)
    for (j, yv) in enumerate(ys), (i, xv) in enumerate(xs)
        (xv / (2√2))^2 + (yv / √2)^2 > 1 && continue
        θ = asin(yv / √2); lat = asind(clamp((2θ + sin(2θ)) / π, -1, 1)); lon = -rad2deg(π * xv / (2√2 * cos(θ)))
        img[i, j] = G[clamp(floor(Int, mod(lon, 360) / res) + 1, 1, size(G, 1)), clamp(floor(Int, (lat + 90) / res) + 1, 1, size(G, 2))]
    end
    xs, ys, img
end
function graticule!(ax)
    for lat in -60:30:60
        p = [Point2f(moll_fwd(l, lat)...) for l in range(-179.99, 179.99, length=361)]
        lines!(ax, p, color=(:white, lat == 0 ? 0.6 : 0.25), linewidth=lat == 0 ? 1.2 : 0.6)
    end
    for lon in -120:60:180
        lines!(ax, [Point2f(moll_fwd(lon == 180 ? 179.99 : lon, b)...) for b in -90:0.5:90], color=(:white, 0.25), linewidth=0.6)
    end
    for lon in (-179.99, 179.99); lines!(ax, [Point2f(moll_fwd(lon, b)...) for b in -90:0.5:90], color=:white, linewidth=1); end
end

# --- sky maps ---
cols = [("140 days (poster model, 750 epochs)", S140["G"], S140["G7"],
         @sprintf("median %.4f%%  ·  p95 %.3f%%\nwithin 2° of the ecliptic %.4f%%  ·  above 60° %.4f%%",
                  S140["median_pct"], S140["p95_pct"], S140["eclip_median_pct"], S140["pole_median_pct"])),
        ("500 days (poster model + n·J, 500 epochs)", S500["G"], S500["G7"],
         @sprintf("median %.4f%%  ·  p95 %.3f%%\nwithin 2° of the ecliptic %.4f%%  ·  above 60° %.4f%%",
                  st.med, st.p95, st.ecl, st.pole))]
fig = Figure(size=(1900, 980)); hm = nothing
for (c, (ttl, G, G7, txt)) in enumerate(cols)
    Label(fig[0, c], ttl, font=:bold, fontsize=21, tellwidth=false)
    for (r, M) in enumerate((G, G7))
        ax = Axis(fig[r, c], aspect=DataAspect()); hidedecorations!(ax); hidespines!(ax)
        xs, ys, img = moll_raster(M)
        global hm = heatmap!(ax, xs, ys, img, colormap=:viridis, colorrange=(0.0, 0.08), nan_color=(:grey35, 1.0),
                             highclip=Makie.to_colormap(:viridis)[end])
        graticule!(ax)
    end
    Label(fig[3, c], txt, fontsize=16, tellwidth=false)
end
Label(fig[1, 1, Left()], "3.5° patches (≈ SPHEREx's view)", font=:bold, fontsize=16, rotation=π/2, padding=(0, 15, 0, 0))
Label(fig[2, 1, Left()], "blended (7° patches)", font=:bold, fontsize=16, rotation=π/2, padding=(0, 15, 0, 0))
Colorbar(fig[1:2, 3], hm, label="median |error| (%)", height=Relative(0.8))
Label(fig[-1, 1:3],@sprintf("Out-of-sample error on the sky, month-on/month-off splits (between-month windows)%s",
      length(done) < 6 ? " — 500 days: preliminary, $(length(done)) of 6 shifts" : ""), font=:bold, fontsize=22)
save(joinpath(R, "figures", "10202026_skymap_140v500.png"), fig, px_per_unit=2)

# --- loss curves ---
TR1, TE1 = T140["blk_tr"], T140["blk_te"]; spe1 = cld(243_441, 512)
TR5, TE5 = S500["TR"], S500["TE"]; spe5 = S500["spe"]
fig2 = Figure(size=(1800, 700))
for (c, (xl, f1, f5)) in enumerate((("training pass (epoch)", 1, 1), ("number of training updates (millions)", spe1 / 1e6, spe5 / 1e6)))
    ax = Axis(fig2[1, c], yscale=log10, xlabel=xl, ylabel=c == 1 ? "MSE  (MJy/sr)²" : "", limits=(nothing, (1e-8, 1.0)),
              yticks=([1e-8, 1e-6, 1e-4, 1e-2, 1.0], ["10⁻⁸", "10⁻⁶", "10⁻⁴", "10⁻²", "1"]),
              title=c == 1 ? "vs epoch" : "vs number of updates (500 days has 3.3× more per epoch)")
    for (TR, TE, f, col, lbl) in ((TR1, TE1, f1, :deepskyblue, "140 days"), (TR5, TE5, f5, :hotpink, "500 days"))
        x = (1:size(TR, 1)) .* f
        lines!(ax, x, vec(mean(TR, dims=2)), color=col, linewidth=3, label="$lbl: training data")
        lines!(ax, x, vec(mean(TE, dims=2)), color=col, linewidth=3, linestyle=:dash, label="$lbl: withheld months")
    end
    c == 1 && axislegend(ax, position=:rt, labelsize=15)
end
Label(fig2[0, 1:2], @sprintf("Train vs test loss, poster split (shift 0), mean of 5 networks, epoch-averaged — final test MSE: 140 d %.2e, 500 d %.2e",
      mean(TE1[end, :]), mean(TE5[end, :])), font=:bold, fontsize=20)
save(joinpath(R, "figures", "10202026_loss_140v500.png"), fig2, px_per_unit=2)
println("ok")
