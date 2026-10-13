# ==============================================================================
# MINI-BATCH SEED ENSEMBLE — the overnight sweep's recommended recipe
# n·* features, 64 → 64 → 32 → 16 MLP, batch 512, one-cycle LR (peak 1e-3), 100 epochs.
# Test error on the chronological split varies ~2× between seeds (it's set by how each
# run extrapolates, not by how well it fits), so we train several seeds and AVERAGE
# their predictions. ~4–6 min per seed on CPU.
# ==============================================================================
look_dir   = filter(nm -> startswith(nm, "n·") && nm != "n·n", dot_names_all)
ens_seeds  = [42, 43, 44, 45, 46]

runs_mb    = Dict{String, Any}()
seed_labels = String[]
for s in ens_seeds
    lbl = "mb 64-64-32-16 seed $s"
    runs_mb[lbl] = train_mb(look_dir; arch=:mlp, hidden=(64, 64, 32, 16), schedule=:onecycle,
                            lr_max=1e-3, epochs=100, batchsize=512, seed=s, label=lbl)
    push!(seed_labels, lbl)
end

# ensemble = mean of the seed predictions; stored like a run so the verification
# functions can treat it the same way
r1       = runs_mb[seed_labels[1]]
ens_pred = vec(mean(reduce(hcat, [runs_mb[l].ypred for l in seed_labels]), dims=2))
ens_lbl  = "ensemble of $(length(ens_seeds)) seeds"
runs_mb[ens_lbl] = merge(r1, (; label=ens_lbl, ypred=ens_pred,
    tr_hist=[mean(abs2, ens_pred[r1.tr_idx] .- y[r1.tr_idx])],
    te_hist=[mean(abs2, ens_pred[r1.te_idx] .- y[r1.te_idx])]))

println("\nseed       test MSE")
for l in seed_labels; @printf("%-26s %.3e\n", l, runs_mb[l].te_hist[end]); end
@printf("%-26s %.3e   (mean of single seeds %.3e)\n", ens_lbl, runs_mb[ens_lbl].te_hist[end],
        mean(runs_mb[l].te_hist[end] for l in seed_labels))
