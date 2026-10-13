# Round 9 helpers (dust-band features, n·vS control, real-data pipeline) for the 10132026 notebook.
# Requires zodi_setup.jl, mb_train.jl, extra_features.jl, extra_splits.jl, nb_verify_fns.jl, summary_helpers.jl,
# checks_helpers.jl.

const ARMS9L  = [("season", "season model  n·* + sin/cos λ⊕"), ("sharp", "+ sharp band profiles (3)"),
                 ("plx", "+ parallax band profiles (9)"), ("both", "+ sharp + parallax (12)"), ("novS", "season − n·vS (control)")]
const TESTS9L = [("blk", "30-day blocks"), ("p1", "patch: ecliptic"), ("p2", "patch: mid-latitude"),
                 ("p3", "patch: near pole"), ("ch", "80/20 chronological")]
const ARMCOL  = Dict("season" => :limegreen, "sharp" => :deepskyblue, "plx" => :orange, "both" => :magenta, "novS" => :gray70)
# same names as sweeps/configs_v9.jl (the season reference keeps its earlier run names)
function runname9(arm, test, s)
    arm == "season" && test == "blk" && return "se_blk_s$s"
    arm == "season" && test in ("p1", "p2", "p3") && return "patch$(test[2])_season_s$s"
    "b9_$(arm)_$(test)_s$s"
end
const _RUNS9 = Dict{Tuple{String, String}, Vector{Any}}()
runs9(arm, test) = get!(_RUNS9, (arm, test)) do
    [load_run(runname9(arm, test, s)) for s in 42:46 if isfile(joinpath(RES, runname9(arm, test, s) * ".jls"))]
end
fracerr(e, idx) = abs.(e[idx] .- y[idx]) ./ y[idx]

"""Ensemble results for every (test, arm): MSE, ratio to the season model, seed wins, median/p95 error and the
error ON the ecliptic (|β| < 2°) where the test set has such exposures."""
function band_table()
    df = DataFrame(test=String[], variant=String[], seeds=Int[], test_ens=String[], vs_season=Float64[],
                   seeds_better=String[], median_err_pct=Float64[], p95_err_pct=Float64[], ecliptic_err_pct=String[])
    for (t, tl) in TESTS9L
        ref = runs9("season", t); isempty(ref) && continue
        mref = mse_on(ensemble_pred(ref), ref[1].te_idx)
        for (a, al) in ARMS9L
            rs = runs9(a, t); isempty(rs) && continue
            e = ensemble_pred(rs); te = rs[1].te_idx; m = mse_on(e, te); fe = fracerr(e, te)
            ecl = te[abs.(ecliptic_latitude_deg[te]) .< 2]
            wins = a == "season" ? "—" : string(count(k -> rs[k].te_hist[end] < ref[k].te_hist[end], 1:min(length(rs), length(ref))),
                                               "/", min(length(rs), length(ref)))
            push!(df, (tl, al, length(rs), sci(m), round(m / mref, digits=3), wins, round(100median(fe), digits=4),
                       round(100quantile(fe, 0.95), digits=3), isempty(ecl) ? "—" : @sprintf("%.4f", 100median(fracerr(e, ecl)))))
        end
    end
    df
end

"""Ensemble MSE relative to the season model, per test (big markers), with each seed's own ratio (small dots)."""
function band_fig()
    fig = Figure(size=(1150, 520), fontsize=14)
    ax = Axis(fig[1, 1], ylabel="test MSE ÷ season model", yscale=log10, xticks=(1:length(TESTS9L), last.(TESTS9L)),
              title="Dust-band features and the n·vS control vs the season model (5-seed ensembles; dots = single seeds vs same-seed season)")
    hlines!(ax, [1.0], color=:white, linestyle=:dash)
    for (k, (a, al)) in enumerate(ARMS9L[2:end])
        xs = Float64[]; ys = Float64[]
        for (i, (t, _)) in enumerate(TESTS9L)
            ref, rs = runs9("season", t), runs9(a, t); (isempty(rs) || isempty(ref)) && continue
            x = i + (k - 2.5) * 0.13
            push!(xs, x); push!(ys, mse_on(ensemble_pred(rs), rs[1].te_idx) / mse_on(ensemble_pred(ref), ref[1].te_idx))
            sr = [rs[j].te_hist[end] / ref[j].te_hist[end] for j in 1:min(length(rs), length(ref))]
            scatter!(ax, fill(x, length(sr)), sr, color=(ARMCOL[a], 0.5), markersize=6)
        end
        scatter!(ax, xs, ys, color=ARMCOL[a], markersize=16, marker=:diamond, label=al)
    end
    axislegend(ax, position=:lt, labelsize=12); fig
end

"""Median |error| vs ecliptic latitude for the held-out ecliptic patch and the 30-day blocks — the 'β = 0 stripe'."""
function stripe_fig()
    fig = Figure(size=(1150, 480), fontsize=14)
    for (col, (t, tl, edges)) in enumerate((("p1", "held-out ecliptic patch (210°, 0°)", -12:1:12), ("blk", "30-day blocks, |β| < 20°", -20:1:20)))
        ax = Axis(fig[1, col], xlabel="ecliptic latitude β (°)", ylabel="median |error| (%)", title=tl)
        for (a, al) in ARMS9L
            rs = runs9(a, t); isempty(rs) && continue
            e = ensemble_pred(rs); te = rs[1].te_idx; β = ecliptic_latitude_deg[te]; fe = 100fracerr(e, te)
            c = Float64[]; v = Float64[]
            for k in 1:length(edges)-1
                s = edges[k] .<= β .< edges[k+1]; count(s) < 30 && continue
                push!(c, (edges[k] + edges[k+1]) / 2); push!(v, median(fe[s]))
            end
            scatterlines!(ax, c, v, color=ARMCOL[a], linewidth=2, markersize=6, label=al)
        end
        col == 1 && axislegend(ax, position=:ct, labelsize=11)
    end
    fig
end

# ---------------------------------------------------------------- physics check of the features themselves
function _moll(vals, pixels, np)
    hres = Healpix.Resolution(Healpix.npix2nside(np)); m = fill(NaN, np); m[pixels] .= vals
    xs = range(-2√2, 2√2, length=900); yy = range(-√2, √2, length=450); I = fill(NaN, 900, 450)
    for (j, yv) in enumerate(yy), (i, xv) in enumerate(xs)
        θ = asin(clamp(yv / √2, -1, 1)); lon = -rad2deg(π * xv / (2√2 * cos(θ))); abs(lon) > 180 && continue
        I[i, j] = m[Healpix.ang2pixRing(hres, deg2rad(90 - asind(clamp((2θ + sin(2θ)) / π, -1, 1))), deg2rad(mod(lon, 360)))]
    end
    xs, yy, I
end
"""For each Kelsall band: ZodiPy's true band brightness (epoch 13170) next to the sharp (no-parallax) and the
parallax (R = 1.5 AU) feature. Plus the Spearman correlation of every band feature with every band component."""
function band_feature_check(; TINDX=13170)
    sky = h5open(allsky_file) do f
        (; lat=read(f["ecliptic_latitude_deg"]), lon=read(f["ecliptic_longitude_deg"]), pixels=read(f["pixels"]) .+ 1,
           b=[read(f["emission_dust_band_$k"]) for k in 1:3], tot=read(f["emission"]))
    end
    np = length(sky.lat)
    nv = vcat((cosd.(sky.lat) .* cosd.(sky.lon))', (cosd.(sky.lat) .* sind.(sky.lon))', sind.(sky.lat)')
    B = band_columns(nv, fill(TINDX, np)); bn = vcat(BAND_SHARP_NAMES, BAND_PLX_NAMES)
    df = DataFrame(feature=bn)
    for k in 1:3; df[!, "ρ with band$(k) (ZodiPy)"] = [round(corspearman(B[:, j], sky.b[k]), digits=3) for j in eachindex(bn)]; end
    fig = Figure(size=(1400, 820), fontsize=13)
    for k in 1:3
        for (c, (v, t)) in enumerate(((sky.b[k], "ZodiPy band $k brightness (MJy/sr)"), (B[:, k], "feature band$k (sharp, no parallax)"),
                                       (B[:, findfirst(==("band$(k)@1.5"), bn)], "feature band$(k)@1.5 (parallax, R = 1.5 AU)")))
            ax = Axis(fig[k, c], title=t, aspect=DataAspect()); hidedecorations!(ax); hidespines!(ax)
            xs, yy, I = _moll(v, sky.pixels, np); heatmap!(ax, xs, yy, I, colormap=:inferno)
        end
    end
    Label(fig[0, :], "Do the band features look like the bands?  (epoch $TINDX; Mollweide, ecliptic coordinates)", fontsize=16, font=:bold)
    near = abs.(sky.lat) .< 10
    (; table=df, fig, share=[round(100median(sky.b[k][near] ./ sky.tot[near]), digits=2) for k in 1:3])
end

"""All-sky test (epoch 13170) of the 30-day-block ensembles: in-domain accuracy and which Kelsall components the
residual still follows."""
function band_allsky_table()
    df = DataFrame(variant=String[], in_domain_sky_pct=Float64[], in_domain_median_err_pct=Float64[], in_domain_rms=String[],
                   ρ_band1=Float64[], ρ_band2=Float64[], ρ_band3=Float64[], ρ_ring=Float64[], ρ_trailing=Float64[], ρ_cloud=Float64[])
    figs = Dict{String, Any}()
    for (a, al) in ARMS9L
        rs = runs9(a, "blk"); isempty(rs) && continue
        A = allsky_eval(rs; title=al); figs[a] = A.fig
        c = Dict(A.comps.component .=> A.comps.corr_with_residual_in_domain)
        push!(df, (al, round(A.metrics.sky_pct[1], digits=1), round(A.metrics.median_abs_frac_pct[1], digits=4), sci(A.metrics.rms_MJy_sr[1]),
                   c["dust band 1"], c["dust band 2"], c["dust band 3"], c["circumsolar ring"], c["Earth-trailing"], c["smooth cloud"]))
    end
    df, figs
end

"""Pipeline sensitivity: ensemble error on the test rows with exact SPHEREx geometry vs SPHEREx placed at Earth
(no spacecraft ephemeris), for the season model and the n·vS-free control."""
function ephemeris_sensitivity(; test="blk")
    df = DataFrame(variant=String[], exact_median_pct=Float64[], spacecraft_at_Earth_median_pct=Float64[],
                   median_shift_pct=Float64[], exact_p95_pct=Float64[], spacecraft_at_Earth_p95_pct=Float64[])
    for a in ("season", "novS", "plx")
        rs = runs9(a, test); isempty(rs) && continue; te = rs[1].te_idx
        function ens(g)
            Fg, nms = ZodiPipeline.build_features(nvec_unit_cartesian[:, te], map(A -> A[:, te], g))
            cols = [findfirst(==(f), nms) for f in rs[1].feature_names]
            vec(mean(reduce(hcat, [Float64.(predict_y(r, Float32.(((Fg[:, cols] .- r.μ') ./ r.σ')'))) for r in rs]), dims=2))
        end
        g0 = (; S=spherex_positions, E=earth_positions, vS=v_spherex, vE=v_earth, J=jupiter_positions)
        p0, p1 = ens(g0), ens((; g0..., S=earth_positions, vS=v_earth))
        f0, f1 = 100abs.(p0 .- y[te]) ./ y[te], 100abs.(p1 .- y[te]) ./ y[te]
        push!(df, (Dict(ARMS9L)[a], round(median(f0), digits=4), round(median(f1), digits=4),
                   round(100median(abs.(p1 .- p0) ./ y[te]), digits=4), round(quantile(f0, 0.95), digits=3), round(quantile(f1, 0.95), digits=3)))
    end
    df
end
