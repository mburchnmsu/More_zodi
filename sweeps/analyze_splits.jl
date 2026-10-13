# Round 3: the generalization table — recommended recipe on every split.
#   julia analyze_splits.jl
# For each split: null / linear / linear+quadratic baselines (same n·* features, train-only
# normalization) vs the NN (seed mean, range, 5- or 3-seed ensemble). Also: how far (in days)
# test exposures are from the nearest training exposure, and error growth vs that distance.
using LinearAlgebra; BLAS.set_num_threads(2)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
include(joinpath(@__DIR__, "mb_train.jl"))
using Serialization
RES = joinpath(@__DIR__, "results")

order = [("rand", "random 50/50"), ("wk7", "7-day alternating"), ("blk30", "30-day alternating"),
         ("mid", "50/50 mid-mission hole"), ("c25", "chrono 25/75"), ("c50", "chrono 50/50"),
         ("c75", "chrono 75/25"), ("c80", "chrono 80/20"), ("c85", "chrono 85/15")]
load_group(tag) = tag == "c80" ?
    [deserialize(joinpath(RES, "final_base_s$s.jls")) for s in 42:46] :
    [deserialize(joinpath(RES, f)) for f in sort(readdir(RES)) if startswith(f, "sp_$(tag)_s") && endswith(f, ".jls")]

# distance (days) from each test exposure to the nearest training exposure
function gap_days(tr, te)
    tt = sort(t_rel[tr])
    map(t_rel[te]) do t
        k = searchsortedfirst(tt, t)
        min(k <= length(tt) ? abs(tt[k] - t) : Inf, k > 1 ? abs(t - tt[k-1]) : Inf)
    end
end

rows = []; ens_preds = Dict{String, Vector{Float64}}()
for (tag, nice) in order
    rs = load_group(tag); isempty(rs) && continue
    r1 = rs[1]; tr, te = r1.tr_idx, r1.te_idx
    # baselines on the same features, standardized with this split's training rows
    cols = [findfirst(==(nm), dot_names_all) for nm in r1.feature_names]
    D    = (Fd_raw[:, cols] .- r1.μ') ./ r1.σ'
    _, Q = quadratic_terms(r1.feature_names, D)
    fit_mse(A) = mean(abs2, y[te] .- (A * (A[tr, :] \ y[tr]))[te])
    mse_null = mean(abs2, y[te] .- mean(y[tr]))
    mse_lin  = fit_mse(hcat(ones(N), D))
    mse_quad = fit_mse(hcat(ones(N), D, Q))
    te_seeds = [r.te_hist[end] for r in rs]
    ens      = vec(mean(reduce(hcat, [r.ypred for r in rs]), dims=2))
    ens_preds[tag] = ens
    mse_ens  = mean(abs2, ens[te] .- y[te])
    g = gap_days(tr, te)
    push!(rows, (; tag, nice, n=length(rs), ntr=length(tr), nte=length(te), mse_null, mse_lin, mse_quad,
                   nn_mean=mean(te_seeds), nn_min=minimum(te_seeds), nn_max=maximum(te_seeds), mse_ens,
                   rms_ens=sqrt(mse_ens), frac=100sqrt(mse_ens) / median(y[te]),
                   medfrac=100median(abs.(ens[te] .- y[te]) ./ y[te]),
                   gap_med=median(g), gap_max=maximum(g), tr_mean=mean(r.tr_hist[end] for r in rs)))
end

println("\nGENERALIZATION TABLE — test MSE (MJy/sr)²; NN = 64-64-32-16 one-cycle, n·* features")
println("split                     seeds  gap to train (median/max d)   null       linear     lin+quad   NN seed mean [min, max]          NN ensemble  rms     rms%   median|frac|%")
for r in rows
    @printf("%-25s %d     %6.2f / %6.1f            %.2e   %.2e   %.2e   %.2e [%.2e, %.2e]   %.2e   %.4f  %.2f   %.3f\n",
            r.nice, r.n, r.gap_med, r.gap_max, r.mse_null, r.mse_lin, r.mse_quad, r.nn_mean, r.nn_min, r.nn_max,
            r.mse_ens, r.rms_ens, r.frac, r.medfrac)
end
serialize(joinpath(RES, "_splits_rows.jls"), rows)

# --- figure 1: the table as a picture --------------------------------------------
fig = Figure(size=(1200, 600), fontsize=13)
ax  = Axis(fig[1, 1], ylabel="test MSE (MJy/sr)²", yscale=log10, xticks=(1:length(rows), [r.nice for r in rows]),
           xticklabelrotation=π/6, title="Generalization ladder — same recipe on every split (lower is better)")
xs = 1:length(rows)
scatter!(ax, xs .- 0.24, [r.mse_null for r in rows], marker=:hline, markersize=22, color=:gray70, label="null (train mean)")
scatter!(ax, xs .- 0.12, [r.mse_lin  for r in rows], marker=:rect,  markersize=11, color=:gold, label="linear")
scatter!(ax, xs,         [r.mse_quad for r in rows], marker=:diamond, markersize=12, color=:orange, label="linear + quadratic")
rangebars!(ax, xs .+ 0.12, [r.nn_min for r in rows], [r.nn_max for r in rows], color=:deepskyblue, whiskerwidth=8)
scatter!(ax, xs .+ 0.12, [r.nn_mean for r in rows], color=:deepskyblue, markersize=11, label="NN single seeds (mean, range)")
scatter!(ax, xs .+ 0.24, [r.mse_ens for r in rows], marker=:star5, color=:limegreen, markersize=17, label="NN seed ensemble")
axislegend(ax, position=:lt, labelsize=11)
save(joinpath(RES, "splits_ladder.png"), fig)

# --- figure 2: error vs distance to nearest training data (ensembles, binned) -----
fig2 = Figure(size=(900, 520), fontsize=13)
ax2  = Axis(fig2[1, 1], xlabel="days from the nearest training exposure", ylabel="ensemble MSE in bin (MJy/sr)²",
            xscale=log10, yscale=log10, title="How fast does accuracy degrade away from the training data?")
edges = [0; 10 .^ range(-3, log10(120), length=22)]
for (i, r) in enumerate(rows)
    rs1 = load_group(r.tag)[1]; te = rs1.te_idx; g = gap_days(rs1.tr_idx, te)
    se  = (ens_preds[r.tag][te] .- y[te]) .^ 2
    mids = Float64[]; vals = Float64[]
    for b in 1:length(edges)-1
        m = (g .>= edges[b]) .& (g .< edges[b+1])
        count(m) >= 200 || continue
        push!(mids, max(sqrt(edges[b] * edges[b+1]), 5e-4)); push!(vals, mean(se[m]))
    end
    isempty(mids) || scatterlines!(ax2, mids, vals, color=Makie.wong_colors()[mod1(i, 7)], label=r.nice, markersize=6)
end
axislegend(ax2, position=:lt, labelsize=10)
save(joinpath(RES, "splits_error_vs_gap.png"), fig2)
println("\nsplit analysis done")
