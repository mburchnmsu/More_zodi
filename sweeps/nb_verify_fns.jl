# ==============================================================================
# VERIFICATION FUNCTIONS — reusable checks for any collection of runs.
# Each run is a NamedTuple with: feature_names, tr_idx, te_idx, μ, σ, ypred,
# tr_hist, te_hist, mse_null, mse_lin (train_mlp and train_mb both return these).
#   verify_integrity(runs, labels)          — split/leakage/normalization asserts + input-domain table
#   verify_metrics(runs, labels; tag)        — headline table, pred-vs-true, residual histograms
#   verify_residuals(runs, labels; tag)      — residuals vs time / latitude / solar elongation
# ==============================================================================
function verify_integrity(runs, labels)
    for label in labels
        r = runs[label]; tr, te = r.tr_idx, r.te_idx
        va = hasproperty(r, :val_idx) ? r.val_idx : Int[]          # empty unless trained with val_days
        println("\n=== $label ===")
        @assert isempty(intersect(tr, te)) && isempty(intersect(tr, va)) && isempty(intersect(va, te)) "fit/val/test overlap"
        @assert sort(vcat(tr, va, te)) == collect(1:N)   "split does not cover every exposure"
        @assert maximum(t_rel[tr]) <= minimum(t_rel[isempty(va) ? te : va]) "split is not chronological"
        isempty(va) || @assert maximum(t_rel[va]) <= minimum(t_rel[te])     "validation not before test"
        @printf("  PASS split: %d fit (day %.1f–%.1f)", length(tr), extrema(t_rel[tr])...)
        isempty(va) || @printf(" | %d val (day %.1f–%.1f)", length(va), extrema(t_rel[va])...)
        @printf(" | %d test (day %.1f–%.1f)\n", length(te), extrema(t_rel[te])...)
        cols = [findfirst(==(nm), dot_names_all) for nm in r.feature_names]
        F    = Fd_raw[:, cols]
        @assert r.μ ≈ [median(F[tr, j]) for j in axes(F, 2)]        "μ not from training rows"
        @assert r.σ ≈ [iqr(F[tr, j]) / 1.34896 for j in axes(F, 2)] "σ not from training rows"
        println("  PASS normalization: constants match training rows")
        println("  feature   test rows outside train range   furthest excursion (train σ)")
        for (j, nm) in enumerate(r.feature_names)
            lo, hi = extrema(F[tr, j]); v = F[te, j]
            frac  = mean((v .< lo) .| (v .> hi))
            excur = max(maximum(v) - hi, lo - minimum(v), 0) / r.σ[j]
            @printf("  %-7s %8.1f%%                       %6.2f%s\n", nm, 100frac, excur, frac > 0.01 ? "  ⚠ extrapolating" : "")
        end
    end
end

function verify_metrics(runs, labels; tag="")
    println("run                            train MSE    test MSE   test rms   frac%   ÷null   ÷linear")
    for label in labels
        r = runs[label]
        mse_te = mean(abs2, r.ypred[r.te_idx] .- y[r.te_idx])
        mse_tr = mean(abs2, r.ypred[r.tr_idx] .- y[r.tr_idx])
        @assert isapprox(mse_te, r.te_hist[end]; rtol=1e-3) "test MSE mismatch vs training log"
        @printf("%-30s %.3e   %.3e   %.4f   %5.2f   %5.3f   %6.3f\n", label, mse_tr, mse_te, sqrt(mse_te),
                100sqrt(mse_te) / median(y[r.te_idx]), mse_te / r.mse_null, mse_te / r.mse_lin)
    end
    println("(÷null, ÷linear < 1 means the NN beats that baseline on the test set)")
    for label in labels
        r = runs[label]
        @printf("%-30s min prediction %.4f MJy/sr (negative: %d)\n", label, minimum(r.ypred), count(<(0), r.ypred))
    end
    fig = Figure(size=(1000, 360 * length(labels)), fontsize=13)
    for (k, label) in enumerate(labels)
        r = runs[label]; yt = y[r.te_idx]; yp = r.ypred[r.te_idx]; res = yp .- yt
        ax1 = Axis(fig[k, 1], title="$label — test: predicted vs true", xlabel="true (MJy/sr)",
                   ylabel="predicted (MJy/sr)", aspect=DataAspect())
        hb = hexbin!(ax1, yt, yp, bins=80, colorscale=log10, colormap=:viridis)
        lims = extrema(vcat(yt, yp)); lines!(ax1, [lims...], [lims...], color=:red, linestyle=:dash)
        Colorbar(fig[k, 2], hb, label="count")
        ax2 = Axis(fig[k, 3], title="$label — test residuals", xlabel="predicted − true (MJy/sr)", ylabel="count")
        hist!(ax2, res, bins=120, color=(:skyblue, 0.8)); vlines!(ax2, [0.0], color=:red, linestyle=:dash)
    end
    save(joinpath(PROJECT_DIR, "figures", "verify_pred_vs_true$tag.png"), fig)
    fig
end

function verify_residuals(runs, labels; tag="")
    S_unit = spherex_positions ./ sqrt.(sum(spherex_positions .^ 2, dims=1))
    elong  = acosd.(clamp.(-dot_prod_matrix(nvec_unit_cartesian, S_unit), -1.0, 1.0))
    sub    = sort(sample(Xoshiro(7), 1:N, 40_000, replace=false))
    fig = Figure(size=(1300, 330 * length(labels)), fontsize=13)
    for (k, label) in enumerate(labels)
        r = runs[label]; res = r.ypred .- y
        is_te = falses(N); is_te[r.te_idx] .= true
        lim = quantile(abs.(res[sub]), 0.995); t_cut = minimum(t_rel[r.te_idx])
        s_tr = filter(i -> !is_te[i], sub); s_te = filter(i -> is_te[i], sub)
        for (c, (xv, xl)) in enumerate([(t_rel, "days since first exposure"),
                                        (ecliptic_latitude_deg, "ecliptic latitude (°)"),
                                        (elong, "solar elongation (°)")])
            ax = Axis(fig[k, c], xlabel=xl, ylabel=c == 1 ? "$label\npred − true" : "", limits=(nothing, (-lim, lim)))
            scatter!(ax, xv[s_tr], res[s_tr], markersize=1.5, color=(:dodgerblue, 0.3), label="train")
            scatter!(ax, xv[s_te], res[s_te], markersize=1.5, color=(:orangered, 0.4), label="test")
            hlines!(ax, [0.0], color=:white, linewidth=0.8)
            c == 1 && vlines!(ax, [t_cut], color=:gray70, linestyle=:dash)
            k == 1 && c == 1 && axislegend(ax, position=:lb, markersize=8)
        end
    end
    Label(fig[0, :], "Residuals, $(runs[labels[1]].split_name) split (dashed = first train/test boundary)", fontsize=16, font=:bold)
    save(joinpath(PROJECT_DIR, "figures", "verify_residuals$tag.png"), fig)
    fig
end
