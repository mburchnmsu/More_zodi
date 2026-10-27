# Per-seed withheld-month loss curves at 2000 epochs, shifts 20 and 30: on shift 30 the test loss flattens from ~epoch
# 1600 while the training loss keeps falling, and seeds 43 and 45 stay well above the rest; shift 20 keeps improving.   julia --project=. sweeps/plot_r34_seeds.jl → figures/r34_seed_curves.png
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
fig = Figure(size=(1500, 620)); cols = Makie.wong_colors()
for (c, Δ) in enumerate((20, 30))
    ax = Axis(fig[1, c], yscale=log10, xlabel="epoch", ylabel="MSE (MJy/sr)²", yticks=([5e-9, 1e-8, 2e-8, 5e-8, 1e-7], ["5×10⁻⁹", "10⁻⁸", "2×10⁻⁸", "5×10⁻⁸", "10⁻⁷"]),
              yminorticksvisible=true, yminorticks=IntervalsBetween(9), title="Shift $Δ, 2000 epochs: each seed")
    for (j, r) in enumerate(runs16("z500h_bandplx2k_shift$Δ"))
        tr, te = epoch_avg(r)
        lines!(ax, 1:r.epochs, tr, color=cols[j], linestyle=:dash, linewidth=1)
        lines!(ax, 1:r.epochs, te, color=cols[j], linewidth=2, label="seed $(r.seed)")
        k = argmin(te); scatter!(ax, [k], [te[k]], color=cols[j], markersize=12)
    end
    m500 = mean(last(epoch_avg(r))[end] for r in runs16("z500h_bandplx_kelsall_shift$Δ"))
    hlines!(ax, [m500], color=:white, linestyle=:dot, label="500-epoch final test (mean of 5)")
    xlims!(ax, 800, 2000); ylims!(ax, 5e-9, 1e-7); c == 2 && axislegend(ax, position=:lb)
end
Label(fig[0, 1:2], "Solid = withheld months, dashed = training months, dot = test minimum", fontsize=17)
save(joinpath(@__DIR__, "..", "figures", "r34_seed_curves.png"), fig, px_per_unit=2)
println("ok")
