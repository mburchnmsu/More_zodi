# Round-2 summary: group seeds, rank by VALIDATION (ensemble) MSE, report test alongside.
#   julia analyze_v2.jl
using LinearAlgebra; BLAS.set_num_threads(2)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
include(joinpath(@__DIR__, "mb_train.jl"))
using Serialization
RES = joinpath(@__DIR__, "results")
files = filter(f -> (startswith(f, "v_") || startswith(f, "blk_")) && endswith(f, ".jls"), readdir(RES))
R = Dict(splitext(f)[1] => deserialize(joinpath(RES, f)) for f in files)
grp(k) = replace(k, r"_s\d+$" => "")
groups = Dict{String, Vector{String}}()
for k in keys(R); push!(get!(groups, grp(k), String[]), k); end

ens(rs, idx) = vec(mean(reduce(hcat, [r.ypred[idx] for r in rs]), dims=2))
rows = []
for (g, ks) in groups
    rs = [R[k] for k in sort(ks)]; r1 = rs[1]
    va = [r.va_hist[end] for r in rs]; te = [r.te_hist[end] for r in rs]
    va_ens = isempty(r1.val_idx) ? NaN : mean(abs2, ens(rs, r1.val_idx) .- y[r1.val_idx])
    te_ens = mean(abs2, ens(rs, r1.te_idx) .- y[r1.te_idx])
    # drift diagnostic: mean ensemble residual in the last 10 days of the test period
    late = r1.te_idx[t_rel[r1.te_idx] .> maximum(t_rel[r1.te_idx]) - 10]
    bias_late = mean(ens(rs, late) .- y[late])
    push!(rows, (; g, n=length(rs), feats=length(r1.feature_names), wd=r1.weight_decay, split=r1.split_name,
                   va_mean=mean(va), va_ens, te_mean=mean(te), te_min=minimum(te), te_max=maximum(te), te_ens,
                   tr_mean=mean(r.tr_hist[end] for r in rs), bias_late))
end
sort!(rows, by = r -> isnan(r.va_ens) ? Inf : r.va_ens)
println("\nRanked by VALIDATION ensemble MSE (days 100–111). Test = days 111.4–139.7 (block split: alternate 30-day blocks).")
println("group          split                 nfeat  wd     seeds  val mean   val ENS    test mean [min, max]            test ENS   train mean  late-test bias")
for r in rows
    @printf("%-14s %-21s %3d   %.0e   %d    %.3e  %.3e  %.3e [%.2e, %.2e]   %.3e  %.2e    %+.4f\n",
            r.g, r.split, r.feats, r.wd, r.n, r.va_mean, r.va_ens, r.te_mean, r.te_min, r.te_max, r.te_ens, r.tr_mean, r.bias_late)
end
serialize(joinpath(RES, "_v2_rows.jls"), rows)

# figure: val vs test per config (ensembles), to show whether validation ranks like test
fig = Figure(size=(820, 520), fontsize=13)
ax  = Axis(fig[1, 1], xlabel="validation MSE, days 100–111 (5-seed ensemble)", ylabel="test MSE, days 111–140 (5-seed ensemble)",
           xscale=log10, yscale=log10, title="Round 2: does the validation period rank models like the test period?")
for r in filter(r -> !isnan(r.va_ens), rows)
    scatter!(ax, [r.va_ens], [r.te_ens], markersize=14)
    text!(ax, r.va_ens, r.te_ens, text="  " * r.g, fontsize=11, align=(:left, :center))
end
save(joinpath(RES, "v2_val_vs_test.png"), fig)
println("\nv2 analysis done")
