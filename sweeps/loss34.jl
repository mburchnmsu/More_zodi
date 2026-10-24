# Round 34 loss curves on the full log range the user asked for (MSE axis 10⁰ → 10⁻⁹): poster split (shift 0),
# 2000 vs 500 epochs, epoch-averaged, 5 seeds averaged.   julia --project=. sweeps/loss34.jl → figures/r34_loss_full.png
ENV["ZODI_DATA"] = "z500"; ENV["ZODI_HELIO"] = "1"
using LinearAlgebra; BLAS.set_num_threads(2)
redirect_stdout(devnull) do
    include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
    for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "shift_helpers.jl"); include(joinpath(@__DIR__, f)); end
end
using CairoMakie
function epoch_avg(r)
    tr = zeros(r.epochs); te = zeros(r.epochs)
    for ep in 1:r.epochs
        k = findall(x -> ep - 1 < x <= ep + 1e-9, r.fine_epoch); tr[ep] = mean(r.tr_fine[k]); te[ep] = mean(r.te_fine[k])
    end
    tr, te
end
set_theme!(merge(Theme(fontsize=17), theme_black()))
fig = Figure(size=(1500, 650))
for (c, xs) in enumerate((:epoch, :frac))
    ax = Axis(fig[1, c], yscale=log10, xlabel=xs === :epoch ? "epoch" : "fraction of the training schedule",
              ylabel="MSE (MJy/sr)²", yticks=LogTicks(0:-1:-9), yminorticksvisible=true, yminorticks=IntervalsBetween(9),
              title=xs === :epoch ? "Poster split: loss vs epoch" : "Same, schedule stretched to 0–1")
    for (fam, col, lbl) in (("z500h_bandplx_kelsall_shift0", :deepskyblue, "500 epochs"), ("z500h_bandplx2k_shift0", :orange, "2000 epochs"))
        rs = runs16(fam); TR = reduce(hcat, first.(epoch_avg.(rs))); TE = reduce(hcat, last.(epoch_avg.(rs)))
        x = xs === :epoch ? (1:size(TR, 1)) : (1:size(TR, 1)) ./ size(TR, 1)
        lines!(ax, x, vec(mean(TR, dims=2)), color=col, linestyle=:dash, label="$lbl train")
        lines!(ax, x, vec(mean(TE, dims=2)), color=col, linewidth=2.5, label="$lbl test (withheld months)")
    end
    ylims!(ax, 1e-9, 1); c == 2 && axislegend(ax, position=:rt)
end
save(joinpath(@__DIR__, "..", "figures", "r34_loss_full.png"), fig, px_per_unit=2)
println("ok")
