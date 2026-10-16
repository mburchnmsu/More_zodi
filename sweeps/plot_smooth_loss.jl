# Smoother train/test loss curves (round 18, configs_v18.jl), two ways:
#   (a) average the 10 in-epoch evaluations of each epoch (fixed 50k-row subsamples), per network, then over 5 seeds;
#   (b) the loss of the 5-network ENSEMBLE (average prediction) at the end of every epoch, on the full sets.
# Also checks that the round-18 networks are identical to the originals (logging must not change training).
#   julia -t 4 --project=. sweeps/plot_smooth_loss.jl  → figures/10162026_loss_smooth.png
ENV["ZODI_DATA"] = "z115"
using LinearAlgebra; BLAS.set_num_threads(1)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "configs_v16.jl", "shift_helpers.jl")
    include(joinpath(@__DIR__, f))
end
const PANELS = [("ch", "z115_sunseason_ch", "80/20 chronological"), ("shift20", 20, "30-day split shifted 20 d"),
                ("shift30", 30, "30-day split shifted 30 d")]
H(rs, f) = reduce(hcat, [Float64.(getfield(r, f)) for r in rs])
mse(a, b) = Float64(mean(abs2, a .- b))

function epoch_avg(r)                       # mean of the in-epoch points of epoch e (fine_epoch in (e−1, e])
    E = r.epochs; tr = zeros(E); te = zeros(E)
    for e in 1:E
        k = findall(x -> e - 1 < x <= e + 1e-9, r.fine_epoch); tr[e] = mean(r.tr_fine[k]); te[e] = mean(r.te_fine[k])
    end
    tr, te
end
function ensemble_curve(rs)                 # ensemble MSE at the end of every epoch (epoch 0 = initial weights), full sets
    r1 = rs[1]; cols = [findfirst(==(nm), dot_names_all) for nm in r1.feature_names]
    X = Float32.(((Fd_raw[:, cols] .- r1.μ') ./ r1.σ')'); idx = vcat(r1.tr_idx, r1.te_idx); Xs = X[:, idx]
    ntr = length(r1.tr_idx); yt = Float32.(y[idx])
    ends = [findfirst(x -> abs(x - e) < 1e-9, r1.fine_epoch) for e in 0:r1.epochs]
    re = Optimisers.destructure(r1.model)[2]
    trE = zeros(length(ends)); teE = zeros(length(ends))
    Threads.@threads for j in eachindex(ends)
        P = mean(predict_batched(re(r.snaps[ends[j]]), Xs) for r in rs)
        trE[j] = mse(P[1:ntr], yt[1:ntr]); teE[j] = mse(P[ntr+1:end], yt[ntr+1:end])
    end
    trE, teE
end

fig = Figure(size=(1700, 1150), fontsize=16)
for (c, (tag, orig, ttl)) in enumerate(PANELS)
    rs = runs16("z115_fine_$tag"); @assert length(rs) == 5 "z115_fine_$tag: expected 5 seeds, found $(length(rs))"
    ro = runs16(orig)
    d = maximum(maximum(abs.(r.te_hist .- o.te_hist) ./ o.te_hist) for (r, o) in zip(rs, ro))
    @printf("%-28s identical to the original runs? max relative difference in test MSE history = %.1e\n", ttl, d)
    ep = 0:rs[1].epochs; TR, TE = H(rs, :tr_hist), H(rs, :te_hist)
    A = [epoch_avg(r) for r in rs]; TRa = reduce(hcat, first.(A)); TEa = reduce(hcat, last.(A))
    trE, teE = ensemble_curve(rs)
    # (a) within-epoch average
    ax = Axis(fig[1, c], yscale=log10, title=ttl, subtitle="(a) each network's loss averaged over 10 points per epoch",
              xlabel="epoch", ylabel=c == 1 ? "MSE  (MJy/sr)²" : "", titlesize=16, subtitlesize=13)
    lines!(ax, ep, vec(mean(TR, dims=2)), color=(:steelblue, 0.35), linewidth=1.5)
    lines!(ax, ep, vec(mean(TE, dims=2)), color=(:crimson, 0.35), linewidth=1.5)
    lines!(ax, 1:rs[1].epochs, vec(mean(TRa, dims=2)), color=:steelblue, linewidth=3, label="train")
    lines!(ax, 1:rs[1].epochs, vec(mean(TEa, dims=2)), color=:crimson, linewidth=3, label="test")
    c == 1 && axislegend(ax, position=:rt)
    # (b) ensemble
    ax2 = Axis(fig[2, c], yscale=log10, subtitle="(b) loss of the 5-network average (the model we use), full sets",
               xlabel="epoch", ylabel=c == 1 ? "MSE  (MJy/sr)²" : "", subtitlesize=13)
    lines!(ax2, ep, vec(mean(TR, dims=2)), color=(:steelblue, 0.35), linewidth=1.5)
    lines!(ax2, ep, vec(mean(TE, dims=2)), color=(:crimson, 0.35), linewidth=1.5)
    lines!(ax2, ep, trE, color=:steelblue, linewidth=3); lines!(ax2, ep, teE, color=:crimson, linewidth=3)
    linkyaxes!(ax, ax2)
    @printf("   final: single-network mean train %.2e test %.2e | ensemble train %.2e test %.2e (%.0f×)\n",
            mean(TR[end, :]), mean(TE[end, :]), trE[end], teE[end], teE[end] / trE[end])
    # roughness: median |Δ log10 MSE| between consecutive epochs, epochs 20–80
    rough(v) = median(abs.(diff(log10.(v[21:81]))))
    @printf("   epoch-to-epoch roughness (median |Δlog10|, epochs 20–80), test: raw %.3f, epoch-avg %.3f, ensemble %.3f\n",
            rough(vec(mean(TE, dims=2))), rough(vec(mean(TEa, dims=2))), rough(teE))
end
Label(fig[0, :], "Smoothed train vs test loss — faint lines: the raw per-epoch curves (mean of 5 networks) from before", font=:bold, fontsize=18)
out = joinpath(@__DIR__, "..", "figures", "10162026_loss_smooth.png"); save(out, fig, px_per_unit=2); println("wrote ", normpath(out))
