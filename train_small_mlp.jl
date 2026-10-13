# ==============================================================================
# SMALL MLP  (n_features → 32 → 16 → 1)  ON THE 80/20 CHRONOLOGICAL SPLIT
# Requires the ZODI SETUP cell. Full-batch Adam, MSE loss, linear LR schedule.
# ==============================================================================
using Flux

split_name     = "80/20 Chronological"
tr_idx, te_idx = splits[split_name]

epochs     = 750
lr_initial = 1e-3     # learning rate at epoch 1
lr_final   = 1e-4     # learning rate at the last epoch (set = lr_initial for a constant rate)
lr_schedule(epoch) = lr_initial + (lr_final - lr_initial) * (epoch - 1) / max(epochs - 1, 1)
lr_hist = lr_schedule.(1:epochs)

# --- A. Normalization from TRAINING rows only (split before normalizing) -----
keep_dots = [iqr(Fd_raw[tr_idx, i]) > 1e-12 for i in axes(Fd_raw, 2)]
dot_names = dot_names_all[keep_dots]
dot_mean  = [median(Fd_raw[tr_idx, i]) for i in axes(Fd_raw, 2)][keep_dots]
dot_norm  = [iqr(Fd_raw[tr_idx, i]) / 1.34896 for i in axes(Fd_raw, 2)][keep_dots]
standardize_dots(Fd) = (Fd[:, keep_dots] .- dot_mean') ./ dot_norm'

D_tr = standardize_dots(Fd_raw[tr_idx, :])
D_te = standardize_dots(Fd_raw[te_idx, :])

# --- B. Reference baselines (dashed lines on the loss plot) -----------------
mse_null = mean(abs2, y[te_idx] .- mean(y[tr_idx]))
c_lin    = hcat(ones(length(tr_idx)), D_tr) \ y[tr_idx]
mse_lin  = mean(abs2, y[te_idx] .- hcat(ones(length(te_idx)), D_te) * c_lin)

# --- C. Flux inputs: (n_features × n_samples), Float32 ----------------------
Xtr = Float32.(D_tr')
Xte = Float32.(D_te')
Ytr = Float32.(reshape(y[tr_idx], 1, :))
Yte = Float32.(reshape(y[te_idx], 1, :))
n_in = size(Xtr, 1)
println("$split_name: $(size(Xtr, 2)) train / $(size(Xte, 2)) test, $n_in features")

rng = Random.Xoshiro(42)
model_small = Chain(
    Dense(n_in => 32, gelu; init=Flux.glorot_uniform(rng)),
    Dense(32 => 16, gelu;   init=Flux.glorot_uniform(rng)),
    Dense(16 => 1;          init=Flux.glorot_uniform(rng)),
)
println("parameters: ", sum(length, Flux.trainables(model_small)))

opt_state = Flux.setup(Adam(lr_initial), model_small)
loss_fn(m, x, y_true) = Flux.mse(m(x), y_true)

tr_loss_hist = Float64[loss_fn(model_small, Xtr, Ytr)]
te_loss_hist = Float64[loss_fn(model_small, Xte, Yte)]

# --- D. Training loop --------------------------------------------------------
println("Training for $epochs epochs (linear lr $lr_initial → $lr_final)...")
t_start = time()
for epoch in 1:epochs
    Flux.adjust!(opt_state, lr_hist[epoch])
    grads = Flux.gradient(m -> loss_fn(m, Xtr, Ytr), model_small)
    Flux.update!(opt_state, model_small, grads[1])

    push!(tr_loss_hist, loss_fn(model_small, Xtr, Ytr))
    push!(te_loss_hist, loss_fn(model_small, Xte, Yte))

    if epoch % 50 == 0 || epoch == 1
        @printf("  Epoch %4d/%d - lr: %.2e | Train: %.6e | Test: %.6e | %.0fs\n",
                epoch, epochs, lr_hist[epoch], tr_loss_hist[end], te_loss_hist[end], time() - t_start)
    end
end

@printf("\n  test MSE   null: %.5e   linear: %.5e\n", mse_null, mse_lin)
@printf("  NN MSE     train: %.5e | test: %.5e\n", tr_loss_hist[end], te_loss_hist[end])
@printf("  NN test rms: %.4f MJy/sr (%.2f%% of median emission)\n",
        sqrt(te_loss_hist[end]), 100sqrt(te_loss_hist[end]) / median(y))

# --- E. Loss curves ----------------------------------------------------------
fig_small = Figure(size=(900, 750), fontsize=14)
ax_lr = Axis(fig_small[1, 1], ylabel="Learning rate",
             title="$n_in → 32 → 16 → 1 MLP, $split_name split")
lines!(ax_lr, 1:epochs, lr_hist, color=:white, linewidth=2)

ax_loss = Axis(fig_small[2, 1], xlabel="Epoch", ylabel="MSE loss (MJy/sr)²", yscale=log10)
lines!(ax_loss, 0:epochs, tr_loss_hist, label="Train", color=:dodgerblue, linewidth=2)
lines!(ax_loss, 0:epochs, te_loss_hist, label="Test",  color=:orangered,  linewidth=2)
hlines!(ax_loss, [mse_null], color=:gray70, linestyle=:dash, label="Null (train mean)")
hlines!(ax_loss, [mse_lin],  color=:gold,   linestyle=:dash, label="Linear on dots")
axislegend(ax_loss, position=:rt)

linkxaxes!(ax_lr, ax_loss)
hidexdecorations!(ax_lr, grid=false)
rowsize!(fig_small.layout, 1, Relative(0.25))
save(joinpath(PROJECT_DIR, "figures", "small_mlp_80_20_loss.png"), fig_small)
fig_small
