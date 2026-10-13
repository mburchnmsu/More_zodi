# Round 8 helpers (block-length sweep, sky-patch holdouts, learning curve) for the 10102026 notebook.
# Requires zodi_setup.jl, mb_train.jl, extra_features.jl, extra_splits.jl, nb_verify_fns.jl, summary_helpers.jl,
# checks_helpers.jl, season_helpers.jl.

# run-name lookup for each experiment cell (reusing identical earlier runs where they exist)
function bl_runs(L, mt)
    L == 30 && return mt == "base" ? load_run.(["sp_blk30_s42", "sp_blk30_s43", "sp_blk30_s44"]) :
                                     load_run.(["se_blk_s42", "se_blk_s43", "se_blk_s44"])
    L == 7 && mt == "base" && return load_run.(["sp_wk7_s42", "sp_wk7_s43", "sp_wk7_s44"])
    load_prefix("bl$(L)_$(mt)_s")
end
patch_runs(i, mt) = load_prefix("patch$(i)_$(mt)_s")
lc_runs(f, mt) = f == 1.0 ? bl_runs(30, mt) : load_prefix("lc$(f)_$(mt)_s")
const MLABEL = Dict("base" => "baseline n·*", "season" => "n·* + sin/cos λ⊕")

summ(rs) = (e = ensemble_pred(rs); te = rs[1].te_idx; fe = abs.(e[te] .- y[te]) ./ y[te];
            (; n=length(rs), ens=mse_on(e, te), seeds=[r.te_hist[end] for r in rs], med=100median(fe), p95=100quantile(fe, 0.95)))

# ---------------------------------------------------------------- block-length sweep
function blocklength_table()
    df = DataFrame(block_days=Int[], model=String[], median_gap_days=Float64[], test_ens=String[], seed_range=String[],
                   ens_median_err_pct=Float64[], ens_p95_err_pct=Float64[])
    for (L, sp) in BLOCK_LENGTHS, mt in ("base", "season")
        rs = bl_runs(L, mt); isempty(rs) && continue; s = summ(rs)
        push!(df, (L, MLABEL[mt], round(median(gap_days(rs[1].tr_idx, rs[1].te_idx)), digits=2), sci(s.ens),
                   sci(minimum(s.seeds)) * " – " * sci(maximum(s.seeds)), round(s.med, digits=3), round(s.p95, digits=2)))
    end
    df
end
function blocklength_fig()
    fig = Figure(size=(1150, 480), fontsize=14)
    ax1 = Axis(fig[1, 1], xlabel="train/test block length (days)", ylabel="test MSE (MJy/sr)²", xscale=log10, yscale=log10,
               title="Error vs block length", xticks=[1, 3, 7, 15, 30, 45])
    ax2 = Axis(fig[1, 2], xlabel="train/test block length (days)", ylabel="median |error| (%)", xscale=log10, yscale=log10,
               title="Median fractional error", xticks=[1, 3, 7, 15, 30, 45])
    for (mt, c) in (("base", :orangered), ("season", :limegreen))
        Ls = Int[]; ens = Float64[]; lo = Float64[]; hi = Float64[]; med = Float64[]
        for (L, _) in BLOCK_LENGTHS
            rs = bl_runs(L, mt); isempty(rs) && continue; s = summ(rs)
            push!(Ls, L); push!(ens, s.ens); push!(lo, minimum(s.seeds)); push!(hi, maximum(s.seeds)); push!(med, s.med)
        end
        band!(ax1, Ls, lo, hi, color=(c, 0.2)); scatterlines!(ax1, Ls, ens, color=c, linewidth=2.5, markersize=11, label=MLABEL[mt])
        scatterlines!(ax2, Ls, med, color=c, linewidth=2.5, markersize=11)
    end
    axislegend(ax1, position=:lt)
    Label(fig[0, :], "Block-length sweep: alternate L-day train/test blocks (lines = 3-seed ensembles, bands = single-seed range)",
          fontsize=15, font=:bold); fig
end

# ---------------------------------------------------------------- sky-patch holdouts
function patch_table()
    df = DataFrame(patch=String[], centre=String[], test_exposures=Int[], model=String[], test_ens=String[], seed_range=String[],
                   ens_median_err_pct=Float64[], ens_p95_err_pct=Float64[], test_out_of_range_pct=Float64[])
    for (i, (nm, lo, la)) in enumerate(PATCHES), mt in ("base", "season")
        rs = patch_runs(i, mt); isempty(rs) && continue; s = summ(rs); r1 = rs[1]
        cols = [findfirst(==(f), dot_names_all) for f in r1.feature_names]
        inr = trues(length(r1.te_idx))                                   # training range computed once per feature
        for c in cols
            lo_, hi_ = extrema(view(Fd_raw, r1.tr_idx, c)); v = view(Fd_raw, r1.te_idx, c)
            inr .&= (lo_ .<= v .<= hi_)
        end
        oor = 1 - mean(inr)
        push!(df, (nm, @sprintf("(%.0f°, %+.0f°)", lo, la), length(r1.te_idx), MLABEL[mt], sci(s.ens),
                   sci(minimum(s.seeds)) * " – " * sci(maximum(s.seeds)), round(s.med, digits=3), round(s.p95, digits=2), round(100oor, digits=1)))
    end
    df
end
"""Mollweide map of the season ensemble's median |error| per HEALPix pixel (nside 32), all 3 patch runs combined:
each patch's held-out exposures shown with the model that never saw them; outlines mark the patches."""
function patch_map_fig(mt="season"; nside=32)
    hres = Healpix.Resolution(nside); np = Healpix.nside2npix(nside)
    pix = [Healpix.ang2pixRing(hres, acos(clamp(nvec_unit_cartesian[3, i], -1, 1)), mod(atan(nvec_unit_cartesian[2, i], nvec_unit_cartesian[1, i]), 2π)) for i in 1:N]
    errs = [Float64[] for _ in 1:np]; seen = falses(np)
    for i in 1:N; seen[pix[i]] = true; end
    for (k, _) in enumerate(PATCHES)
        rs = patch_runs(k, mt); isempty(rs) && continue; e = ensemble_pred(rs)
        for i in rs[1].te_idx; push!(errs[pix[i]], 100abs(e[i] - y[i]) / y[i]); end
    end
    vals = [isempty(v) ? (seen[p] ? -1.0 : NaN) : median(v) for (p, v) in enumerate(errs)]
    xs = range(-2√2, 2√2, length=1200); ys = range(-√2, √2, length=600); img = fill(NaN, 1200, 600)
    for (j, yv) in enumerate(ys), (i, xv) in enumerate(xs)
        θ = asin(clamp(yv / √2, -1, 1)); lon = -rad2deg(π * xv / (2√2 * cos(θ))); abs(lon) > 180 && continue
        img[i, j] = vals[Healpix.ang2pixRing(hres, deg2rad(90 - asind(clamp((2θ + sin(2θ)) / π, -1, 1))), deg2rad(mod(lon, 360)))]
    end
    moll(lon, lat) = (θ = deg2rad(lat); for _ in 1:30; θ -= (2θ + sin(2θ) - π * sind(lat)) / (2 + 2cos(2θ) + 1e-12); end;
                      (-2√2 / π * deg2rad(mod(lon + 180, 360) - 180) * cos(θ), √2 * sin(θ)))
    fig = Figure(size=(1150, 620), fontsize=14)
    ax = Axis(fig[1, 1], aspect=DataAspect(), title="Held-out sky patches: median |error| of the $(MLABEL[mt]) ensemble that never saw them " *
              "(grey = training sky, dark = unobserved)"); hidedecorations!(ax); hidespines!(ax)
    shown = map(v -> v < 0 ? NaN : v, img)
    heatmap!(ax, xs, ys, map(v -> v < 0 ? 1.0 : NaN, img), colormap=[:gray35, :gray35], colorrange=(0, 1))
    hm = heatmap!(ax, xs, ys, shown, colormap=:inferno, colorrange=(0, 0.3), highclip=:white)
    Colorbar(fig[1, 2], hm, label="median |error| (%)  (white > 0.3%)", height=Relative(0.7))
    # patch boundaries: points at angular distance R from the centre along each bearing (spherical "destination" formula),
    # split into separate line pieces where the boundary wraps across the map edge (lon = ±180°)
    for (nm, lo, la) in PATCHES
        bnd = map(0:2:360) do a
            φ2 = asind(sind(la) * cosd(PATCH_RADIUS) + cosd(la) * sind(PATCH_RADIUS) * cosd(a))
            λ2 = lo + atand(sind(a) * sind(PATCH_RADIUS) * cosd(la), cosd(PATCH_RADIUS) - sind(la) * sind(φ2))
            Point2f(moll(λ2, φ2)...)
        end
        piece = [bnd[1]]
        for p in bnd[2:end]
            if abs(p[1] - piece[end][1]) > 1.0; lines!(ax, piece, color=:cyan, linewidth=1.8); piece = [p]; else; push!(piece, p); end
        end
        lines!(ax, piece, color=:cyan, linewidth=1.8)
        text!(ax, Point2f(moll(lo, la - PATCH_RADIUS - 2)...), text=nm, color=:cyan, fontsize=13, align=(:center, :top))
    end
    fig
end

# ---------------------------------------------------------------- learning curve
function lc_table()
    df = DataFrame(fraction=Float64[], train_exposures=Int[], model=String[], test_ens=String[], seed_range=String[],
                   ens_median_err_pct=Float64[], train_mse_mean=String[])
    for f in LC_FRACTIONS, mt in ("base", "season")
        rs = lc_runs(f, mt); isempty(rs) && continue; s = summ(rs)
        push!(df, (f, length(rs[1].tr_idx), MLABEL[mt], sci(s.ens), sci(minimum(s.seeds)) * " – " * sci(maximum(s.seeds)),
                   round(s.med, digits=3), sci(mean(r.tr_hist[end] for r in rs))))
    end
    df
end
function lc_fig()
    fig = Figure(size=(1150, 480), fontsize=14)
    ax1 = Axis(fig[1, 1], xlabel="training exposures", ylabel="test MSE (MJy/sr)²", xscale=log10, yscale=log10, title="Learning curve (30-day-block split)")
    ax2 = Axis(fig[1, 2], xlabel="training exposures", ylabel="median |error| (%)", xscale=log10, yscale=log10, title="Median fractional error")
    for (mt, c) in (("base", :orangered), ("season", :limegreen))
        n = Int[]; ens = Float64[]; lo = Float64[]; hi = Float64[]; med = Float64[]; trm = Float64[]
        for f in LC_FRACTIONS
            rs = lc_runs(f, mt); isempty(rs) && continue; s = summ(rs)
            push!(n, length(rs[1].tr_idx)); push!(ens, s.ens); push!(lo, minimum(s.seeds)); push!(hi, maximum(s.seeds)); push!(med, s.med)
            push!(trm, mean(r.tr_hist[end] for r in rs))
        end
        band!(ax1, n, lo, hi, color=(c, 0.2)); scatterlines!(ax1, n, ens, color=c, linewidth=2.5, markersize=11, label="$(MLABEL[mt]) — test")
        lines!(ax1, n, trm, color=c, linestyle=:dash, linewidth=1.5, label="$(MLABEL[mt]) — train")
        scatterlines!(ax2, n, med, color=c, linewidth=2.5, markersize=11)
    end
    axislegend(ax1, position=:rt, labelsize=11)
    Label(fig[0, :], "Learning curve: same test blocks, random subsets of the training data, equal number of optimizer steps",
          fontsize=15, font=:bold); fig
end
