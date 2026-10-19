# Helpers for 10182026.ipynb (Oct 18): the month splits at 750 epochs (round 21), the sky map with/without blending,
# the mentor's Earth-trailing-cloud stack, and the overnight model experiments (round 22).
# Requires the same setup as r17_20_helpers.jl (which this builds on: fam100/fam300/fam750, oos_interior, sky_stats,
# skymap_grid_fig, m300_table, loss_m300_fig, TF_EMISSION).

# ---------------------------------------------------------------------------------------------------- trailing-cloud stack
# Kelsall (1998) Earth-trailing blob: centred R_TB = 1.06 AU from the Sun, θ_TB = 10° behind Earth in heliocentric
# longitude (Earth moves toward increasing longitude), in the ecliptic plane (σ_r 0.10 AU, σ_z 0.091 AU, σ_θ 12.1°).
const TB_R, TB_DTHETA = 1.06, -10.0
"""Two "how much am I looking through the trailing cloud" axes for every exposure:
  ahead = angle between the look direction and Earth's direction of motion v̂⊕ (0° ahead, 180° behind);
  blob  = angle between the look direction and the direction from SPHEREx to the blob centre (0° = looking at it)."""
function trailing_axes()
    E = earth_positions; S = spherex_positions; n = nvec_unit_cartesian
    λE = atan.(E[2, :], E[1, :]) .+ deg2rad(TB_DTHETA)
    B = vcat((TB_R .* cos.(λE))', (TB_R .* sin.(λE))', zeros(1, size(E, 2)))
    d = B .- S; d ./= sqrt.(sum(abs2, d, dims=1))
    # as angles (degrees): SPHEREx looks ~90° from the Sun, so the dot products pile up near ±1; angles spread them out
    (; ahead=acosd.(clamp.(vec(sum(n .* v_earth_unit, dims=1)), -1, 1)),     # 0° = straight ahead, 180° = straight behind
       blob=acosd.(clamp.(vec(sum(n .* d, dims=1)), -1, 1)))                 # 0° = looking right at the cloud's centre
end

"""Bin `v` (keep-mask `k`) by axis `x` into equal-width bins of `w` (skipping bins with < `minn` exposures):
centres, means, standard errors."""
function stack(x, v, k; w=5.0, minn=200)
    i = findall(k .& .!isnan.(v)); lo, hi = extrema(x[i])
    xc = Float64[]; m = Float64[]; se = Float64[]
    for a in floor(lo / w) * w:w:hi
        kk = i[a .<= x[i] .< a + w]; length(kk) < minn && continue
        push!(xc, mean(x[kk])); push!(m, mean(v[kk])); push!(se, std(v[kk]) / sqrt(length(kk)))
    end
    xc, m, se
end
"""Break a binned curve where bins are missing (so lines never bridge empty stretches of the axis)."""
function gapped(xc, ys...; w=5.0)
    X = Float64[]; Ys = [Float64[] for _ in ys]
    for i in eachindex(xc)
        if i > 1 && xc[i] - xc[i-1] > 1.5w
            push!(X, NaN); foreach(Y -> push!(Y, NaN), Ys)
        end
        push!(X, xc[i]); for (Y, y_) in zip(Ys, ys); push!(Y, y_[i]); end
    end
    (X, Ys...)
end

"""Least-squares fit of residual = a·(trailing-cloud %) + b on unbinned exposures → a = fraction of the cloud's
signal left in the residuals (a = −1: the cloud is entirely missing; 0: perfectly modelled). Uncertainty from the
spread of a over the 5 seeds (each seed's own out-of-sample prediction)."""
function missing_fraction(fam, k)
    ftf = 100 .* TF_EMISSION ./ y
    fit(e) = (i = findall(k .& .!isnan.(e)); A = hcat(ftf[i], ones(length(i))); (A \ e[i])[1])
    a_ens = fit(oos_interior(fam))
    a_seed = [fit(oos_interior_seed(fam, s)) for s in 1:5]
    (; a=a_ens, a_std=std(a_seed))
end
"""Like oos_interior, but from one seed's network per version instead of the 5-network average."""
function oos_interior_seed(fam, s)
    acc = zeros(N); n = zeros(Int, N)
    for Δ in SHIFTS16
        r = runs16(fam(Δ))[s]; te = r.te_idx; te = te[is_interior(Δ, te)]
        acc[te] .+= r.ypred[te]; n[te] .+= 1
    end
    100 .* (ifelse.(n .> 0, acc ./ max.(n, 1), NaN) .- y) ./ y
end

"""The mentor's test: stack Kelsall's trailing-cloud signal and the network's out-of-sample residuals along both axes.
Rows: (top) what Kelsall predicts — the trailing cloud as % of the total; (bottom) the mean residual for each training
length, with the curve a model that missed 1% of the cloud would show. Near the plane (|β| < 15°) and everywhere."""
function trailing_stack_fig(fams=((fam100, 100), (fam300, 300), (fam750, 750)); betamax=15.0)
    ax_ = trailing_axes(); ftf = 100 .* TF_EMISSION ./ y; β = abs.(Float64.(ecliptic_latitude_deg)); near = β .< betamax
    E = Dict(ep => oos_interior(fam) for (fam, ep) in fams)
    tested = .!isnan.(E[fams[end][2]])
    fig = Figure(size=(1600, 1050), fontsize=15); cols = Makie.wong_colors()
    df = DataFrame(axis=String[], epochs=Int[], region=String[], missing_fraction=Float64[], seed_std=Float64[])
    for (c, (key, lbl)) in enumerate(((:ahead, "angle from Earth's direction of motion, acos(n·v̂⊕) (°): 0 = straight ahead, 180 = straight behind"),
                                     (:blob, "angle between the look direction and the trailing cloud's centre (°): 0 = looking right at it")))
        x = getproperty(ax_, key)
        a1 = Axis(fig[1, c], ylabel=c == 1 ? "trailing cloud, % of total" : "", title=c == 1 ? "Axis 1: ahead of vs behind Earth" : "Axis 2: toward the cloud's centre",
                  subtitle="Kelsall model (ZodiPy): the signal to look for", titlesize=16)
        for (k, l, ls) in ((near .& tested, "within $(Int(betamax))° of the plane", :solid), (tested, "whole sky", :dash))
            X, M = gapped(stack(x, ftf, k)[1:2]...)
            scatterlines!(a1, X, M, color=:crimson, linewidth=3, linestyle=ls, markersize=6, label=l)
        end
        c == 1 && axislegend(a1, position=c == 1 ? :lt : :rt)
        a2 = Axis(fig[2, c], xlabel=lbl, ylabel=c == 1 ? "mean residual, network − ZodiPy (%)" : "",
                  subtitle="network residuals on pointings it never saw (whole sky), mean ± 1 s.e. per 5° bin", titlesize=16)
        X, M = gapped(stack(x, ftf, tested)[1:2]...)
        lines!(a2, X, -0.01 .* (M .- mean(filter(!isnan, M))), color=(:crimson, 0.8), linewidth=2.5, linestyle=:dot,
               label="if 1% of the cloud were missing")
        for (j, (fam, ep)) in enumerate(fams)
            X, M, SE = gapped(stack(x, E[ep], tested)...)
            band!(a2, X, M .- SE, M .+ SE, color=(cols[j], 0.25)); scatterlines!(a2, X, M, color=cols[j], linewidth=2.5, markersize=5, label="$ep epochs")
        end
        hlines!(a2, [0], color=:grey50, linewidth=1)
        c == 1 && axislegend(a2, position=:lb, labelsize=13)
        linkxaxes!(a1, a2)
    end
    for (fam, ep) in fams, (reg, k) in (("|β| < $(Int(betamax))°", near), ("whole sky", trues(N)))
        mf = missing_fraction(fam, k)
        push!(df, ("residual = a·(cloud %) + b", ep, reg, round(mf.a, digits=4), round(mf.a_std, digits=4)))
    end
    Label(fig[0, 1:2], "Is the Earth-trailing cloud modelled well? Stacking Kelsall's signal and the residuals along the mentor's axis",
          font=:bold, fontsize=18)
    fig, df
end

# ---------------------------------------------------------------------------------------------------- round 22–23
famB(Δ) = Δ == 0 ? "z115_r22_bands" : "z115_r23_bands_shift$Δ"   # poster model + dust-band inputs, 300 epochs (rounds 22–23)
"""Round 22 (overnight model experiments, 30-day split shift 0, 300 epochs) vs the round-20 baseline: accuracy on the
withheld months, overall and on the ecliptic."""
function r22_table(arms)
    β = abs.(Float64.(ecliptic_latitude_deg))
    df = DataFrame(arm=String[], seeds=Int[], median_pct=Float64[], p95_pct=Float64[], ecl_lt2deg_pct=Float64[],
                   above60_pct=Float64[], ens_test_mse=String[], final_train_mse=String[])
    for (key, lbl) in arms
        rs = runs16(key); isempty(rs) && continue
        te, e = relerr(rs); a = abs.(e); b = β[te]
        push!(df, (lbl, length(rs), round(median(a), digits=4), round(quantile(a, 0.95), digits=3), round(median(a[b .< 2]), digits=4),
                   round(median(a[b .>= 60]), digits=4), sci(mean(abs2, ensemble_pred(rs)[te] .- y[te])), sci(mean(r.tr_hist[end] for r in rs))))
    end
    df
end
