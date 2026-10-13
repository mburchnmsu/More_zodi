# ==============================================================================
# MINI-BATCH LOSS CURVES — each seed (solid = test, dashed = train), the ensemble's
# final test error, the full-batch result for scale, and the one-cycle LR schedule.
# ==============================================================================
fig_mb = Figure(size=(1100, 600), fontsize=14)
ax_mb  = Axis(fig_mb[1, 1], xlabel="epoch", ylabel="MSE (MJy/sr)²", yscale=log10,
              title="Mini-batch 64-64-32-16, one-cycle 1e-3, 80/20 chronological")
for (k, l) in enumerate(seed_labels)
    r = runs_mb[l]; c = Makie.wong_colors()[mod1(k, 7)]
    lines!(ax_mb, 0:length(r.te_hist)-1, r.te_hist, color=c, linewidth=2, label=l)
    lines!(ax_mb, 0:length(r.tr_hist)-1, r.tr_hist, color=c, linewidth=1, linestyle=:dash)
end
hlines!(ax_mb, [runs_mb[ens_lbl].te_hist[end]], color=:gold, linewidth=3, label="$ens_lbl (test)")
if @isdefined(runs) && haskey(runs, "n·* only (64-64-32-16)")
    hlines!(ax_mb, [runs["n·* only (64-64-32-16)"].te_hist[end]], color=:white, linestyle=:dot,
            label="full-batch 64-64-32-16, 2000 ep")
end
axislegend(ax_mb, position=:rt, labelsize=11)
ax_lr2 = Axis(fig_mb[1, 2], xlabel="training progress", ylabel="learning rate", yscale=log10, title="one-cycle schedule")
lines!(ax_lr2, range(0, 1, length=500), runs_mb[seed_labels[1]].lr_curve, color=:white, linewidth=2)
colsize!(fig_mb.layout, 2, Relative(0.28))
save(joinpath(PROJECT_DIR, "figures", "minibatch_ensemble_loss.png"), fig_mb)
fig_mb
