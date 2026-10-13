# Summarize all sweep results: table + figures in sweeps/results/.
#   julia analyze.jl [prefix_filter]
using LinearAlgebra; BLAS.set_num_threads(2)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
include(joinpath(@__DIR__, "mb_train.jl"))
using Serialization
RES = joinpath(@__DIR__, "results")
filt = isempty(ARGS) ? "" : ARGS[1]
files = filter(f -> endswith(f, ".jls") && startswith(f, filt), readdir(RES))
R = Dict(splitext(f)[1] => deserialize(joinpath(RES, f)) for f in files)
names_sorted = sort(collect(keys(R)), by = k -> R[k].te_hist[end])

archstr(r) = r.arch === :mlp ? "mlp " * join(r.hidden, "-") : "res w$(r.width)×$(r.blocks)"
println("\nname                      arch                  params  sched     lr_max  ep   train MSE   test MSE   test rms  frac%   best-test(ep)   time")
for k in names_sorted
    r = R[k]; te = r.te_hist[end]; ib = argmin(r.te_hist)
    @printf("%-25s %-20s %7d  %-8s %.0e  %3d  %.3e  %.3e   %.4f  %5.2f   %.3e(%3d)  %5.0fs\n",
            k, archstr(r), r.n_params, r.schedule, r.lr_max, r.epochs, r.tr_hist[end], te, sqrt(te),
            100sqrt(te) / median(y[r.te_idx]), r.te_hist[ib], ib - 1, r.t_epoch[end])
end

colors = Makie.wong_colors()
function curves_fig(keys_, title, fname)
    fig = Figure(size=(1100, 650), fontsize=13)
    ax  = Axis(fig[1, 1], xlabel="epoch", ylabel="MSE (MJy/sr)²", yscale=log10, title=title)
    axl = Axis(fig[1, 2], xlabel="training progress", ylabel="learning rate", yscale=log10, title="LR schedule")
    for (i, k) in enumerate(keys_)
        r = R[k]; c = colors[mod1(i, length(colors))]
        lines!(ax, 0:length(r.te_hist)-1, r.te_hist, color=c, linewidth=2, label=k)
        lines!(ax, 0:length(r.tr_hist)-1, r.tr_hist, color=c, linewidth=1, linestyle=:dash)
        lines!(axl, range(0, 1, length=length(r.lr_curve)), r.lr_curve, color=c, linewidth=2)
    end
    hlines!(ax, [9.276e-4], color=:white, linestyle=:dot, label="full-batch best (2000 ep, ~2 h)")
    Legend(fig[2, 1:2], ax, orientation=:horizontal, nbanks=3, labelsize=11)
    colsize!(fig.layout, 2, Relative(0.3))
    save(joinpath(RES, fname), fig); fig
end

p1 = filter(startswith("p1_"), names_sorted)
isempty(p1) || curves_fig(p1, "Phase 1 — schedules (64-64-32-16, bs 512). solid = test, dashed = train", "phase1_curves.png")
p2 = filter(startswith("p2_"), names_sorted)
if !isempty(p2)
    curves_fig(p2, "Phase 2 — architectures. solid = test, dashed = train", "phase2_curves.png")
    fig = Figure(size=(800, 500), fontsize=13)
    ax = Axis(fig[1, 1], xlabel="parameters", ylabel="final test MSE", xscale=log10, yscale=log10,
              title="Phase 2 — test error vs model size")
    for k in p2
        r = R[k]; m = r.arch === :mlp ? :circle : :diamond
        scatter!(ax, [r.n_params], [r.te_hist[end]], marker=m, markersize=14,
                 color=r.arch === :mlp ? :deepskyblue : :orangered)
        text!(ax, r.n_params, r.te_hist[end], text=" " * archstr(r), fontsize=10, align=(:left, :center))
    end
    save(joinpath(RES, "phase2_size.png"), fig)
end
println("\nanalysis done")
