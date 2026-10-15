# Round 16 helpers (10152026 notebook): shifted 30-day train/test windows, train + test MSE curves, all-sky error map.
# Requires ENV["ZODI_DATA"] = "z115" before zodi_setup.jl, then mb_train.jl, extra_features.jl, summary_helpers.jl,
# and configs_v16.jl (for SHIFTS16, shifted_30day_split, shift_run).
@assert ZODI_DATA == "z115" "shift_helpers.jl needs ENV[\"ZODI_DATA\"] = \"z115\""
using Serialization, CairoMakie, Statistics, Printf, DataFrames

const _R16 = Dict{Any, Vector{Any}}()
"""The 5 seeds of a run family: Δ (Int) for the shifted 30-day windows, or a run prefix (String), e.g. "z115_sunseason_r90"."""
runs16(key) = get!(_R16, key) do
    names = key isa Integer ? [shift_run(key, s) for s in 42:46] : ["$(key)_s$s" for s in 42:46]
    [deserialize(joinpath(RESULTS_DIR, n * ".jls")) for n in names if isfile(joinpath(RESULTS_DIR, n * ".jls"))]
end
relerr(rs) = (te = rs[1].te_idx; e = ensemble_pred(rs); (te, 100 .* (e[te] .- y[te]) ./ y[te]))

"""Held-out mission-day windows of a shift, e.g. "30–60, 90–120"."""
function held_out_days(Δ)
    _, te = shifted_30day_split(Δ); d = t_rel[te]
    w = sort(unique(floor.(Int, (d .- Δ) ./ 30)))
    join([@sprintf("%d–%d", max(0, 30k + Δ), min(ceil(Int, span_days), 30(k + 1) + Δ)) for k in w], ", ")
end

"""For each exposure held out by shift Δ: is its 30-day window INTERIOR (training data both before and after it →
interpolation) or at an EDGE of the mission (no training data on one side → extrapolation in time)?"""
function is_interior(Δ, idx)
    k = floor.(Int, (t_rel[idx] .- Δ) ./ 30)
    (30 .* k .+ Δ .> 0) .& (30 .* (k .+ 1) .+ Δ .< span_days)
end

"""Median |error| split into interior (interpolation) and edge (extrapolation) held-out windows, per shift."""
function interior_edge_table()
    df = DataFrame(shift_days=Int[], interior_days=String[], interior_median_pct=Float64[], interior_p95_pct=Float64[],
                   edge_days=String[], edge_median_pct=Float64[], edge_p95_pct=Float64[])
    fmt(d) = isempty(d) ? "—" : join([@sprintf("%d–%d", max(0, 30k + Δ0), min(ceil(Int, span_days), 30(k + 1) + Δ0)) for (k, Δ0) in d], ", ")
    for Δ in SHIFTS16
        rs = runs16(Δ); isempty(rs) && continue
        te, e = relerr(rs); a = abs.(e); inn = is_interior(Δ, te)
        ks(m) = [(k, Δ) for k in sort(unique(floor.(Int, (t_rel[te[m]] .- Δ) ./ 30)))]
        q(m, f) = any(m) ? round(f(a[m]), digits=4) : NaN
        push!(df, (Δ, fmt(ks(inn)), q(inn, median), q(inn, x -> quantile(x, 0.95)),
                   fmt(ks(.!inn)), q(.!inn, median), q(.!inn, x -> quantile(x, 0.95))))
    end
    df
end

"""One row per shift: which days were held out, and the 5-seed ensemble's accuracy on them."""
function shift_table()
    df = DataFrame(shift_days=Int[], held_out_days=String[], test_pct=Float64[], seeds=Int[], median_err_pct=Float64[],
                   p95_err_pct=Float64[], rms_err_pct=Float64[], within_0p1_pct=Float64[], ens_test_mse=String[],
                   final_train_mse=String[], final_test_mse=String[])
    for Δ in SHIFTS16
        rs = runs16(Δ); isempty(rs) && continue
        te, e = relerr(rs); a = abs.(e)
        push!(df, (Δ, held_out_days(Δ), round(100length(te) / N, digits=1), length(rs), round(median(a), digits=4),
                   round(quantile(a, 0.95), digits=3), round(sqrt(mean(abs2, e)), digits=4), round(100mean(a .< 0.1), digits=1),
                   sci(mean(abs2, ensemble_pred(rs)[te] .- y[te])), sci(mean(r.tr_hist[end] for r in rs)), sci(mean(r.te_hist[end] for r in rs))))
    end
    df
end

"""Timeline of every shift (train = blue, held out = red) with the ensemble's median error on its held-out days."""
function shift_timeline_fig()
    fig = Figure(size=(1200, 120 + 70length(SHIFTS16)), fontsize=15)
    ax = Axis(fig[1, 1], xlabel="mission day", yticks=(1:length(SHIFTS16), ["shift $(Δ) d" for Δ in SHIFTS16]),
              yreversed=true, limits=((0, span_days), (0.4, length(SHIFTS16) + 0.6)), xticks=0:10:140,
              title="Trained on (blue) / tested on: between training windows (red) or at the mission's start or end (orange)")
    grid = 0:0.25:span_days
    for (row, Δ) in enumerate(SHIFTS16)
        k = floor.(Int, (grid .- Δ) ./ 30); test = isodd.(k)
        edge = (30 .* k .+ Δ .<= 0) .| (30 .* (k .+ 1) .+ Δ .>= span_days)
        for i in 1:length(grid)-1
            c = !test[i] ? (:steelblue, 0.6) : edge[i] ? (:darkorange, 0.85) : (:crimson, 0.75)
            poly!(ax, Rect(grid[i], row - 0.35, grid[i+1] - grid[i], 0.7), color=c)
        end
        rs = runs16(Δ)
        lbl = isempty(rs) ? "(not run yet)" : @sprintf("median |error| %.4f%%", median(abs.(relerr(rs)[2])))
        text!(ax, span_days + 1, row, text=lbl, align=(:left, :center), fontsize=14)
    end
    xlims!(ax, 0, span_days + 38)
    fig
end

"""Train and test MSE vs epoch on the same axes, one panel per shift (+ the random 10% hold-out for comparison).
Thin lines: the 5 seeds; thick: their mean."""
function loss_curves_fig(; extra=[("z115_sunseason_r90", "random 10% held out")])
    panels = vcat([(Δ, "shift $(Δ) d: test days " * held_out_days(Δ)) for Δ in SHIFTS16], extra)
    nc = 3; nr = cld(length(panels), nc)
    fig = Figure(size=(1300, 330nr + 60), fontsize=14)
    for (k, (key, ttl)) in enumerate(panels)
        rs = runs16(key); isempty(rs) && continue
        r, c = fldmod1(k, nc)
        ax = Axis(fig[r, c], yscale=log10, title=ttl, titlesize=13, xlabel=r == nr ? "epoch" : "", ylabel=c == 1 ? "MSE (MJy/sr)²" : "")
        ep = 0:length(rs[1].tr_hist)-1
        for rr in rs
            lines!(ax, ep, rr.tr_hist, color=(:steelblue, 0.25), linewidth=1)
            lines!(ax, ep, rr.te_hist, color=(:crimson, 0.25), linewidth=1)
        end
        lines!(ax, ep, vec(mean(reduce(hcat, [rr.tr_hist for rr in rs]), dims=2)), color=:steelblue, linewidth=2.5, label="train")
        lines!(ax, ep, vec(mean(reduce(hcat, [rr.te_hist for rr in rs]), dims=2)), color=:crimson, linewidth=2.5, label="test")
        k == 1 && axislegend(ax, position=:rt)
    end
    Label(fig[0, :], "Train and test MSE during training (5 seeds each; thick = mean)", font=:bold, fontsize=17)
    fig
end

"""Out-of-sample prediction for every exposure: the mean of the ensembles of all shifts that held it out
(each exposure is held out by 3 of the 6 shifts; Δ = 0 and 30 alone already cover the mission once)."""
function oos_prediction(; which=:all)          # which = :all | :interior | :edge (see is_interior)
    s = zeros(N); n = zeros(Int, N)
    for Δ in SHIFTS16
        rs = runs16(Δ); isempty(rs) && continue
        te = rs[1].te_idx; inn = is_interior(Δ, te)
        te = which === :interior ? te[inn] : which === :edge ? te[.!inn] : te
        s[te] .+= ensemble_pred(rs)[te]; n[te] .+= 1
    end
    p = ifelse.(n .> 0, s ./ max.(n, 1), NaN)
    (; pred=p, nheld=n, err_pct=100 .* (p .- y) ./ y)
end

# --- Mollweide maps on a regular ecliptic lon/lat grid (cells of GRID_DEG × GRID_DEG) --------------------------
const GRID_DEG = 3.0
grid_cell(lon, lat) = (clamp(floor(Int, mod(lon, 360) / GRID_DEG) + 1, 1, round(Int, 360 / GRID_DEG)),
                       clamp(floor(Int, (lat + 90) / GRID_DEG) + 1, 1, round(Int, 180 / GRID_DEG)))
function moll_fwd(lon, lat)                 # ecliptic lon 0° at the centre, increasing to the LEFT
    λ = deg2rad(mod(lon + 180, 360) - 180); φ = deg2rad(lat); θ = φ
    for _ in 1:50; abs(φ) > π/2 - 1e-9 && break; Δ = (2θ + sin(2θ) - π * sin(φ)) / (2 + 2cos(2θ)); θ -= Δ; abs(Δ) < 1e-12 && break; end
    (-2√2 / π * λ * cos(θ), √2 * sin(θ))
end
function moll_raster(G; nx=1400)            # G: (360/GRID_DEG) × (180/GRID_DEG) cell values → image on the Mollweide plane
    ny = nx ÷ 2; img = fill(NaN, nx, ny); xs = range(-2√2, 2√2, length=nx); ys = range(-√2, √2, length=ny)
    for (j, yv) in enumerate(ys), (i, xv) in enumerate(xs)
        (xv / (2√2))^2 + (yv / √2)^2 > 1 && continue
        θ = asin(yv / √2); lat = asind(clamp((2θ + sin(2θ)) / π, -1, 1)); lon = -rad2deg(π * xv / (2√2 * cos(θ)))
        img[i, j] = G[grid_cell(lon, lat)...]
    end
    xs, ys, img
end
function graticule!(ax)
    for lat in -60:30:60
        p = [Point2f(moll_fwd(l, lat)...) for l in range(-179.99, 179.99, length=361)]
        lines!(ax, p, color=(:black, lat == 0 ? 0.6 : 0.25), linewidth=lat == 0 ? 1.2 : 0.6)
    end
    for lon in -120:60:180
        lines!(ax, [Point2f(moll_fwd(lon == 180 ? 179.99 : lon, b)...) for b in -90:0.5:90], color=(:black, 0.25), linewidth=0.6)
    end
    for lon in (-179.99, 179.99); lines!(ax, [Point2f(moll_fwd(lon, b)...) for b in -90:0.5:90], color=:black, linewidth=1); end
    for lon in -120:60:120; text!(ax, Point2f(moll_fwd(lon, 0)...), text="$(mod(lon, 360))°", fontsize=11, align=(:center, :bottom), offset=(0, 3)); end
end
"""Per-cell statistic of `v` over exposures (cells with fewer than `minn` exposures are left blank)."""
function grid_stat(v, f; minn=5)
    nlon, nlat = round(Int, 360 / GRID_DEG), round(Int, 180 / GRID_DEG)
    buckets = [Float64[] for _ in 1:nlon, _ in 1:nlat]
    for i in eachindex(v)
        isnan(v[i]) && continue
        push!(buckets[grid_cell(ecliptic_longitude_deg[i], ecliptic_latitude_deg[i])...], v[i])
    end
    [length(b) >= minn ? f(b) : NaN for b in buckets]
end

"""All-sky maps of the out-of-sample error (every exposure predicted by models that never saw its 30-day window)."""
function sky_error_fig()
    oi = oos_prediction(which=:interior); oe = oos_prediction(which=:edge)
    maps = [(grid_stat(oi.err_pct, median), "Interior windows (interpolation): median error (network − ZodiPy)", :balance, "error (%)", (-0.06, 0.06)),
            (grid_stat(oi.err_pct, x -> median(abs.(x))), "Interior windows (interpolation): median |error|", :viridis, "|error| (%)", (0.0, 0.08)),
            (grid_stat(oe.err_pct, x -> median(abs.(x))), "Edge windows (extrapolation at the mission's start/end): median |error|", :inferno, "|error| (%)", (0.0, 0.5)),
            (grid_stat(Float64.(ecliptic_latitude_deg), x -> log10(length(x)); minn=1), "Exposures per cell (whole mission)", :viridis, "log₁₀ count", nothing)]
    fig = Figure(size=(1100, 1950), fontsize=14)
    for (row, (G, ttl, cm, lbl, cr)) in enumerate(maps)
        ax = Axis(fig[row, 1], title=ttl, aspect=DataAspect()); hidedecorations!(ax); hidespines!(ax)
        xs, ys, img = moll_raster(G)
        hm = heatmap!(ax, xs, ys, img, colormap=cm, colorrange=cr === nothing ? extrema(filter(!isnan, img)) : cr,
                      nan_color=(:grey80, 1.0), lowclip=cr === nothing ? nothing : Makie.to_colormap(cm)[1],
                      highclip=cr === nothing ? nothing : Makie.to_colormap(cm)[end])
        graticule!(ax)
        Colorbar(fig[row, 2], hm, label=lbl, height=Relative(0.8))
    end
    Label(fig[0, :], @sprintf("Out-of-sample error on the sky (ecliptic, Mollweide, %g° × %g° cells; grey = not observed)", GRID_DEG, GRID_DEG),
          font=:bold, fontsize=16)
    fig
end
