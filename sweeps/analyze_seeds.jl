# Seed-aggregated summary + ensemble evaluation for the sweep.
#   julia analyze_seeds.jl
using LinearAlgebra; BLAS.set_num_threads(2)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
include(joinpath(@__DIR__, "mb_train.jl"))
using Serialization
RES = joinpath(@__DIR__, "results")
R = Dict(splitext(f)[1] => deserialize(joinpath(RES, f)) for f in readdir(RES) if endswith(f, ".jls") && !startswith(f, "_"))

# group runs that differ only by seed. The phase-1 one-cycle 1e-3 runs ARE the
# 64-64-32-16 point of the architecture scan (same config), so map them in.
function group_of(k)
    k in ("p1_onecycle_1e-3", "p1s_onecycle_1e-3_s43", "p1s_onecycle_1e-3_s44") && return "p2_mlp_64-64-32-16"
    startswith(k, "p3_mlp_64-64-32-16_s") && return "p2_mlp_64-64-32-16"   # extra seeds, same config
    k == "p1_cosexp_1e-2" && return "p1_cosexp_1e-2"
    k == "p1_linear_1e-3" && return "p1_linear_1e-3"
    k == "p1_cosexp_3e-3" && return "p1_cosexp_3e-3"
    m = match(r"^(p1s_|p2_|p3_)(.*)_s\d+$", k)
    m === nothing && return k
    m.captures[1] == "p1s_" ? "p1_" * m.captures[2] : m.captures[1] * m.captures[2]
end
groups = Dict{String, Vector{String}}()
for k in keys(R); push!(get!(groups, group_of(k), String[]), k); end

archstr(r) = r.arch === :mlp ? "mlp " * join(r.hidden, "-") : "res w$(r.width)×$(r.blocks)"
rows = []
for (g, ks) in groups
    rs   = [R[k] for k in ks]
    te   = [r.te_hist[end] for r in rs]
    tr   = [r.tr_hist[end] for r in rs]
    te_idx = rs[1].te_idx
    ens  = mean(reduce(hcat, [r.ypred for r in rs]), dims=2)[:]          # seed-averaged prediction
    te_ens = length(rs) > 1 ? mean(abs2, ens[te_idx] .- y[te_idx]) : NaN
    push!(rows, (; g, arch=archstr(rs[1]), params=rs[1].n_params, sched=rs[1].schedule, lr=rs[1].lr_max,
                   n=length(rs), te_mean=mean(te), te_min=minimum(te), te_max=maximum(te), tr_mean=mean(tr),
                   te_ens, time=mean(r.t_epoch[end] for r in rs)))
end
sort!(rows, by = r -> r.te_mean)
println("\ngroup                         arch                 params  sched     lr     seeds  test MSE mean [min, max]           ensemble   train mean   s/run")
for r in rows
    @printf("%-29s %-20s %7d  %-8s %.0e   %d    %.3e [%.2e, %.2e]   %s   %.2e   %5.0f\n",
            r.g, r.arch, r.params, r.sched, r.lr, r.n, r.te_mean, r.te_min, r.te_max,
            isnan(r.te_ens) ? "    —    " : @sprintf("%.3e", r.te_ens), r.tr_mean, r.time)
end

# figure: test MSE vs parameters, seed range as error bars, ensemble as star
p2 = filter(r -> startswith(r.g, "p2_") || startswith(r.g, "p3_"), rows)
if !isempty(p2)
    fig = Figure(size=(950, 560), fontsize=13)
    ax  = Axis(fig[1, 1], xlabel="parameters", ylabel="final test MSE (MJy/sr)²", xscale=log10, yscale=log10,
               title="Architecture scan, 80/20 chronological (one-cycle 1e-3, 100 ep). Bars = seed range, ★ = seed ensemble")
    for r in p2
        c = occursin("res", r.arch) ? :orangered : :deepskyblue
        rangebars!(ax, [r.params], [r.te_min], [r.te_max], color=c, whiskerwidth=8)
        scatter!(ax, [r.params], [r.te_mean], color=c, markersize=12)
        isnan(r.te_ens) || scatter!(ax, [r.params], [r.te_ens], color=:gold, marker=:star5, markersize=16)
        text!(ax, r.params, r.te_mean, text="  " * r.arch, fontsize=10, align=(:left, :center))
    end
    xlims!(ax, 5e2, 3e6)
    hlines!(ax, [9.276e-4], color=:white, linestyle=:dot)
    text!(ax, 1e3, 9.276e-4, text="full-batch 64-64-32-16, 2000 ep (~2 h)", fontsize=10, align=(:left, :bottom))
    save(joinpath(RES, "arch_scan.png"), fig)
end
serialize(joinpath(RES, "_summary_rows.jls"), rows)
println("\nseed analysis done")
