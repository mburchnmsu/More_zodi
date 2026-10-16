# Mentor request (Oct 16): train and test MSE vs epoch for the 80/20 chronological split (round 17, configs_v17.jl)
# and for the shifted 30-day splits whose held-out days include the mission's start/end (shift 20, 30; round 16).
# Poster model (Sun frame + sin/cos λ⊕). NOT a poster figure.
#   julia --project=. sweeps/plot_chrono_loss.jl  → figures/10162026_loss_curves.png
ENV["ZODI_DATA"] = "z115"
using LinearAlgebra; BLAS.set_num_threads(2)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "configs_v16.jl", "shift_helpers.jl")
    include(joinpath(@__DIR__, f))
end
H(rs, f) = reduce(hcat, [Float64.(getfield(r, f)) for r in rs])
function dayspan(idx)            # contiguous day ranges covered by idx, e.g. "0–20, 110–140"
    d = sort(t_rel[idx]); s = [d[1]]; e = Float64[]
    for i in 2:length(d)
        d[i] - d[i-1] > 1 && (push!(e, d[i-1]); push!(s, d[i]))
    end
    push!(e, d[end])
    join([@sprintf("%.0f–%.0f", a, b) for (a, b) in zip(s, e)], ", ")
end
panels = [("z115_sunseason_ch", "80/20 chronological"), (20, "30-day split shifted 20 d"), (30, "30-day split shifted 30 d")]
fig = Figure(size=(1650, 640), fontsize=16)
axs = Axis[]
for (c, (key, ttl)) in enumerate(panels)
    rs = runs16(key); @assert length(rs) == 5 "$key: expected 5 seeds, found $(length(rs))"
    TR, TE = H(rs, :tr_hist), H(rs, :te_hist); ep = 0:size(TR, 1)-1
    te = rs[1].te_idx; e = ensemble_pred(rs); rel = 100 .* (e[te] .- y[te]) ./ y[te]
    ax = Axis(fig[1, c], yscale=log10, xlabel="epoch", ylabel=c == 1 ? "MSE  (MJy/sr)²" : "",
              title=ttl, subtitle="test days " * dayspan(te), titlesize=16, subtitlesize=13)
    push!(axs, ax)
    for s in 1:size(TR, 2)
        lines!(ax, ep, TR[:, s], color=(:steelblue, 0.3), linewidth=1); lines!(ax, ep, TE[:, s], color=(:crimson, 0.3), linewidth=1)
    end
    lines!(ax, ep, vec(mean(TR, dims=2)), color=:steelblue, linewidth=3, label="train")
    lines!(ax, ep, vec(mean(TE, dims=2)), color=:crimson, linewidth=3, label="test")
    c == 1 && axislegend(ax, position=:rt)
    txt = @sprintf("final: train %.1e, test %.1e (%.0f×)\nensemble test: median |err| %.3f%%, p95 %.2f%%",
                   mean(TR[end, :]), mean(TE[end, :]), mean(TE[end, :]) / mean(TR[end, :]), median(abs.(rel)), quantile(abs.(rel), 0.95))
    text!(ax, 0.03, 0.03, space=:relative, align=(:left, :bottom), fontsize=13, text=txt)
    @printf("%-28s test days %s | final train %.2e test %.2e (%.1f×) | min of mean test MSE at epoch %d | ensemble median %.4f%% p95 %.3f%%\n",
            ttl, dayspan(te), mean(TR[end, :]), mean(TE[end, :]), mean(TE[end, :]) / mean(TR[end, :]),
            argmin(vec(mean(TE, dims=2))) - 1, median(abs.(rel)), quantile(abs.(rel), 0.95))
end
linkyaxes!(axs...)
Label(fig[0, 1:length(panels)], "Train vs test MSE during training — Sun frame + sin/cos λ⊕ inputs, 64-64-32-16 gelu, one-cycle LR 1e-3; 5 seeds (thin), mean (thick)",
      font=:bold, fontsize=17)
out = joinpath(@__DIR__, "..", "figures", "10162026_loss_curves.png"); mkpath(dirname(out)); save(out, fig, px_per_unit=2)
println("wrote ", normpath(out))
