# Round 19: 80/20 chronological, 300 epochs, peak LR 1e-3 vs 3e-4 — epoch-averaged train/test MSE (option (a) of
# plot_smooth_loss.jl), compared with the 100-epoch run (round 18).   julia --project=. sweeps/plot_ch300.jl
#   → figures/10162026_loss_ch300.png
ENV["ZODI_DATA"] = "z115"
using LinearAlgebra; BLAS.set_num_threads(2)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "configs_v16.jl", "shift_helpers.jl")
    include(joinpath(@__DIR__, f))
end
function epoch_avg(r)                       # mean of the 10 in-epoch points of each epoch
    tr = zeros(r.epochs); te = zeros(r.epochs)
    for e in 1:r.epochs
        k = findall(x -> e - 1 < x <= e + 1e-9, r.fine_epoch); tr[e] = mean(r.tr_fine[k]); te[e] = mean(r.te_fine[k])
    end
    tr, te
end
meancurve(rs, f) = vec(mean(reduce(hcat, [f(r) for r in rs]), dims=2))
rough(v) = (n = length(v); median(abs.(diff(log10.(v[round(Int, 0.2n):round(Int, 0.8n)])))))   # middle 60% of the run

arms = [("z115_fine_ch", "100 epochs, peak LR 1e-3 (before)"), ("z115_ch300_lr1e3", "300 epochs, peak LR 1e-3"),
        ("z115_ch300_lr3e4", "300 epochs, peak LR 3e-4")]
fig = Figure(size=(1750, 640), fontsize=16)
axs = Axis[]; res = []
for (c, (key, ttl)) in enumerate(arms)
    rs = runs16(key); @assert length(rs) == 5 "$key: expected 5 seeds, found $(length(rs))"
    tra = meancurve(rs, r -> epoch_avg(r)[1]); tea = meancurve(rs, r -> epoch_avg(r)[2])
    e = ensemble_pred(rs); te = rs[1].te_idx; rel = 100 .* (e[te] .- y[te]) ./ y[te]
    trF = mean(r.tr_hist[end] for r in rs); teF = mean(r.te_hist[end] for r in rs); ensF = mean(abs2, e[te] .- y[te])
    ax = Axis(fig[1, c], yscale=log10, title=ttl, xlabel="epoch", ylabel=c == 1 ? "MSE  (MJy/sr)²" : "",
              subtitle=@sprintf("final: train %.1e, test %.1e; 5-net average: test %.1e, median |err| %.3f%%", trF, teF, ensF, median(abs.(rel))),
              subtitlesize=12)
    push!(axs, ax)
    ep = 0:rs[1].epochs
    lines!(ax, ep, meancurve(rs, r -> r.tr_hist), color=(:steelblue, 0.3), linewidth=1.2)
    lines!(ax, ep, meancurve(rs, r -> r.te_hist), color=(:crimson, 0.3), linewidth=1.2)
    lines!(ax, 1:rs[1].epochs, tra, color=:steelblue, linewidth=3, label="train")
    lines!(ax, 1:rs[1].epochs, tea, color=:crimson, linewidth=3, label="test")
    c == 1 && axislegend(ax, position=:rt)
    push!(res, (ttl, rough(tra), rough(tea), trF, teF, ensF, median(abs.(rel)), quantile(abs.(rel), 0.95)))
end
linkyaxes!(axs...)
Label(fig[0, 1:3], "80/20 chronological, epoch-averaged loss (5 networks, mean) — faint: the raw end-of-epoch values", font=:bold, fontsize=18)
out = joinpath(@__DIR__, "..", "figures", "10162026_loss_ch300.png"); save(out, fig, px_per_unit=2); println("wrote ", normpath(out))
for (ttl, rtr, rte, trF, teF, ensF, md, p95) in res
    @printf("%-36s roughness (middle 60%%) train %.3f test %.3f | final train %.2e test %.2e | 5-net test MSE %.2e median %.4f%% p95 %.3f%%\n",
            ttl, rtr, rte, trF, teF, ensF, md, p95)
end
