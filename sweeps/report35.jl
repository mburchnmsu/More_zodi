# Round 35 report: cos×exp learning-rate schedule with warm-up (:cosexpw, peak 2e-3) vs one-cycle (peak 1e-3), parallax
# band layer, 500 epochs, shifts 0 and 30 × 5 seeds. Per-seed and ensemble test MSE, error statistics on the withheld
# months, and loss curves with the two learning-rate schedules.
#     julia --project=. sweeps/report35.jl → figures/r35_schedule.png
ENV["ZODI_DATA"] = "z500"; ENV["ZODI_HELIO"] = "1"
using LinearAlgebra; BLAS.set_num_threads(2)
redirect_stdout(devnull) do
    include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
    for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "shift_helpers.jl"); include(joinpath(@__DIR__, f)); end
end
using CairoMakie
const FAMS = (("z500h_bandplx_kelsall_shift", "one-cycle 1e-3", :deepskyblue), ("z500h_bandplx_cosexp_shift", "cos×exp 2e-3", :orange))
β = abs.(Float64.(ecliptic_latitude_deg))
for Δ in (0, 30), (fam, lbl, _) in FAMS
    rs = runs16("$fam$Δ"); te = rs[1].te_idx
    per = [mean(abs2, r.ypred[te] .- y[te]) for r in rs]
    e = ensemble_pred(rs); rel = abs.(100 .* (e[te] .- y[te]) ./ y[te]); b = β[te]
    @printf("shift %2d  %-15s seeds %s  (mean %.2e ± %.2e) | ensemble MSE %.3e  median %.4f%%  p95 %.3f%%  |β|<2° %.4f%%\n",
            Δ, lbl, join((@sprintf("%.2f", 1e8x) for x in per), " "), mean(per), std(per), mean(abs2, e[te] .- y[te]),
            median(rel), quantile(rel, 0.95), median(rel[b .< 2]))
end
function epoch_avg(r)
    tr = zeros(r.epochs); te = zeros(r.epochs)
    for ep in 1:r.epochs
        k = findall(x -> ep - 1 < x <= ep + 1e-9, r.fine_epoch); tr[ep] = mean(r.tr_fine[k]); te[ep] = mean(r.te_fine[k])
    end
    tr, te
end
set_theme!(merge(Theme(fontsize=17), theme_black()))
fig = Figure(size=(1800, 620))
for (c, Δ) in enumerate((0, 30))
    ax = Axis(fig[1, c], yscale=log10, xlabel="epoch", ylabel="MSE (MJy/sr)²", title="Shift $Δ: loss (5 seeds averaged)",
              yticks=LogTicks(-9:-5), yminorticksvisible=true, yminorticks=IntervalsBetween(9))
    for (fam, lbl, col) in FAMS
        rs = runs16("$fam$Δ"); TR = reduce(hcat, first.(epoch_avg.(rs))); TE = reduce(hcat, last.(epoch_avg.(rs)))
        lines!(ax, 1:size(TR, 1), vec(mean(TR, dims=2)), color=col, linestyle=:dash, label="$lbl train")
        lines!(ax, 1:size(TE, 1), vec(mean(TE, dims=2)), color=col, linewidth=2.5, label="$lbl test")
    end
    ylims!(ax, 1e-8, 1e-5); c == 1 && axislegend(ax, position=:rt)
end
ax = Axis(fig[1, 3], xlabel="epoch", ylabel="learning rate", yscale=log10, title="The two schedules")
for (fam, lbl, col) in FAMS
    r = runs16("$(fam)0")[1]; lines!(ax, range(0, r.epochs, length=length(r.lr_curve)), r.lr_curve, color=col, linewidth=2.5, label=lbl)
end
axislegend(ax, position=:lb)
save(joinpath(@__DIR__, "..", "figures", "r35_schedule.png"), fig, px_per_unit=2)
println("ok")
