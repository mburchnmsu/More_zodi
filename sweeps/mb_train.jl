# ==============================================================================
# Mini-batch MLP / ResMLP training with per-step LR schedules.
# Requires the ZODI SETUP (zodi_setup.jl) to have been run in the same session.
#
#   train_mb(feature_names; arch=:mlp, hidden=(64,64,32,16), width=64, blocks=3,
#            schedule=:onecycle, lr_max=3e-3, epochs=60, batchsize=1024, seed=42)
#
# Schedules (per optimizer step, t = progress 0 → 1):
#   :onecycle  — cosine warm-up from lr_max/25 to lr_max over the first `pct` of
#                training, then cosine anneal down to lr_max/1e4
#   :cosexp    — single cosine × exponential envelope (no restarts):
#                lr = lr_max · ½(1 + cos πt) · exp(−decay·t)
#   :linear    — straight line from lr_max to lr_max/10 (the full-batch recipe)
# ==============================================================================
using Flux, Optimisers, Random, Statistics, Printf
using Flux: DataLoader

function lr_at(schedule, t; lr_max, pct=0.3, div=25.0, final_div=1e4, decay=3.0)
    if schedule === :onecycle
        lo, hi, fin = lr_max / div, lr_max, lr_max / final_div
        t <= pct && return lo + (hi - lo) * 0.5 * (1 - cos(π * t / pct))
        u = (t - pct) / (1 - pct)
        return fin + (hi - fin) * 0.5 * (1 + cos(π * u))
    elseif schedule === :cosexp
        return lr_max * 0.5 * (1 + cos(π * t)) * exp(-decay * t) + lr_max / 1e4
    elseif schedule === :linear
        return lr_max + (lr_max / 10 - lr_max) * t
    else
        error("unknown schedule $schedule")
    end
end

# plain MLP: n_in → hidden... → 1, gelu
function build_mlp(n_in, hidden, rng)
    widths = (n_in, hidden...)
    Chain([Dense(widths[i] => widths[i+1], gelu; init=Flux.glorot_uniform(rng)) for i in 1:length(hidden)]...,
          Dense(widths[end] => 1; init=Flux.glorot_uniform(rng)))
end

# residual MLP: lift to `width`, `blocks` residual blocks x + W₂·gelu(W₁·x), then head.
# The second layer of each block starts small so every block begins near identity.
function build_resmlp(n_in, width, blocks, rng)
    block() = SkipConnection(Chain(Dense(width => width, gelu; init=Flux.glorot_uniform(rng)),
                                   Dense(width => width; init=(d...) -> 0.1f0 .* Flux.glorot_uniform(rng, d...))), +)
    Chain(Dense(n_in => width, gelu; init=Flux.glorot_uniform(rng)),
          [block() for _ in 1:blocks]...,
          x -> gelu.(x),
          Dense(width => width ÷ 2, gelu; init=Flux.glorot_uniform(rng)),
          Dense(width ÷ 2 => 1; init=Flux.glorot_uniform(rng)))
end

# batched forward pass for evaluation (keeps memory bounded for wide nets)
function predict_batched(model, X; bs=65_536)
    out = Vector{Float32}(undef, size(X, 2))
    for s in 1:bs:size(X, 2)
        e = min(s + bs - 1, size(X, 2))
        # invokelatest: models loaded from disk may contain anonymous functions (softplus head,
        # ResMLP activation) defined after this function was compiled ("world age")
        out[s:e] .= vec(Base.invokelatest(model, X[:, s:e]))
    end
    out
end

# Output/target handling (`target` keyword of train_mb):
#   :linear   — predict y directly, MSE loss (the default)
#   :log      — predict log(y), MSE on log y (≈ squared FRACTIONAL error); output exp(·) is always positive
#   :softplus — predict y, but the last layer is followed by softplus → output always positive
#   :relmse   — predict y, loss = mean(((ŷ − y)/y)²)  (squared fractional error, no transform)
#   :mixlog   — predict log(y); loss = MSE(exp(z), y) + mix_alpha · MSE(z, log y)  (absolute + fractional error)
to_y(target, z) = target in (:log, :mixlog) ? exp.(z) : z  # network output → MJy/sr
predict_y(r, X) = to_y(get(r, :target, :linear), predict_batched(r.model, X))

function train_mb(feature_names; arch=:mlp, hidden=(64, 64, 32, 16), width=64, blocks=3,
                  schedule=:onecycle, lr_max=3e-3, epochs=60, batchsize=1024, seed=42,
                  split_name="80/20 Chronological", sched_kw=(;), label="", verbose=true,
                  val_days=nothing, weight_decay=0.0, target=:linear, mix_alpha=0.25, eval_every=1,
                  evals_per_epoch=0, eval_sub=50_000)
    # evals_per_epoch = K > 0: also record train/test MSE K times per epoch on a FIXED random subsample of `eval_sub`
    # rows of each set (tr_fine, te_fine at fractional epochs fine_epoch), and keep the weight vector at each of those
    # points (snaps; rebuild with Optimisers.restructure) so an ensemble's curve can be computed afterwards.
    # Off by default; it never touches the training RNGs, so the trained network is identical either way.
    tr_idx, te_idx = splits[split_name]
    # optional validation period: training exposures with t_rel ≥ val_days are held out
    # (fit on the rest); everything — normalization, baselines — then uses fit rows only
    val_idx = Int[]
    if val_days !== nothing
        val_idx = tr_idx[t_rel[tr_idx] .>= val_days]
        tr_idx  = tr_idx[t_rel[tr_idx] .<  val_days]
    end
    cols = [findfirst(==(nm), dot_names_all) for nm in feature_names]
    F  = Fd_raw[:, cols]
    μ  = [median(F[tr_idx, j]) for j in axes(F, 2)]
    σ  = [iqr(F[tr_idx, j]) / 1.34896 for j in axes(F, 2)]
    # features that are ~0 over most of the sky (the round-9 dust-band profiles) have IQR ≈ 0 → fall back to the std.
    # Never triggers for earlier features (their IQR/1.349 ÷ std is 0.9–1.5), so earlier runs are unchanged.
    for j in axes(F, 2)
        s = std(F[tr_idx, j]); σ[j] < 0.1s && (σ[j] = s)
    end
    X  = Float32.(((F .- μ') ./ σ')')
    Xtr, Xte = X[:, tr_idx], X[:, te_idx]
    Ytr = Float32.(reshape(target === :log ? log.(y[tr_idx]) : y[tr_idx], 1, :))   # what the net is trained to output
    ytr, yte = Float32.(y[tr_idx]), Float32.(y[te_idx])                             # always MJy/sr for reporting
    # reference baselines on the same features/split (used by the verification cells)
    mse_null = mean(abs2, y[te_idx] .- mean(y[tr_idx]))
    A        = hcat(ones(N), (F .- μ') ./ σ')
    mse_lin  = mean(abs2, y[te_idx] .- (A * (A[tr_idx, :] \ y[tr_idx]))[te_idx])

    rng   = Random.Xoshiro(seed)
    model = arch === :mlp ? build_mlp(size(X, 1), hidden, rng) : build_resmlp(size(X, 1), width, blocks, rng)
    target === :softplus && (model = Chain(model, z -> softplus.(z)))
    n_params = sum(length, Flux.trainables(model))
    lossfn = target === :relmse ? ((m, xb, yb) -> mean(abs2, (m(xb) .- yb) ./ yb)) :
             target === :mixlog ? ((m, xb, yb) -> (z = m(xb); Flux.mse(exp.(z), yb) + Float32(mix_alpha) * Flux.mse(z, log.(yb)))) :
                                  ((m, xb, yb) -> Flux.mse(m(xb), yb))
    # weight decay applied after the Adam step (decoupled): each step shrinks weights by weight_decay
    rule  = weight_decay > 0 ? Optimisers.OptimiserChain(Adam(lr_max), Optimisers.WeightDecay(weight_decay)) : Adam(lr_max)
    opt   = Flux.setup(rule, model)
    Xva, yva = X[:, val_idx], Float32.(y[val_idx])
    loader = DataLoader((Xtr, Ytr); batchsize, shuffle=true, rng=Random.Xoshiro(seed + 1))
    steps_per_epoch = length(loader)
    S = epochs * steps_per_epoch

    tr_hist, te_hist, va_hist, lr_epoch, t_epoch = Float64[], Float64[], Float64[], Float64[], Float64[]
    mse(a, b) = Float64(mean(abs2, a .- b))
    pred(Xs) = to_y(target, predict_batched(model, Xs))
    eval_va() = isempty(val_idx) ? NaN : mse(pred(Xva), yva)
    push!(tr_hist, mse(pred(Xtr), ytr)); push!(te_hist, mse(pred(Xte), yte))
    push!(va_hist, eval_va())
    verbose && println("[$label] $arch $(arch === :mlp ? hidden : (width, blocks)) | $n_params params | $schedule lr_max=$lr_max | bs=$batchsize × $steps_per_epoch steps × $epochs epochs")

    tr_fine, te_fine, fine_epoch, snaps = Float64[], Float64[], Float64[], Vector{Float32}[]
    fine_at = Set(round(Int, k * steps_per_epoch / max(evals_per_epoch, 1)) for k in 1:evals_per_epoch)
    sub_rng = Random.Xoshiro(seed + 7)                                   # separate stream: training RNGs untouched
    sub_tr = evals_per_epoch > 0 ? sort(randperm(sub_rng, length(tr_idx))[1:min(eval_sub, length(tr_idx))]) : Int[]
    sub_te = evals_per_epoch > 0 ? sort(randperm(sub_rng, length(te_idx))[1:min(eval_sub, length(te_idx))]) : Int[]
    Xtr_s, ytr_s, Xte_s, yte_s = Xtr[:, sub_tr], ytr[sub_tr], Xte[:, sub_te], yte[sub_te]
    function record_fine!(x_epoch)
        push!(tr_fine, mse(pred(Xtr_s), ytr_s)); push!(te_fine, mse(pred(Xte_s), yte_s))
        push!(fine_epoch, x_epoch); push!(snaps, copy(Optimisers.destructure(model)[1]))
    end
    evals_per_epoch > 0 && record_fine!(0.0)

    t0 = time(); step = 0
    for epoch in 1:epochs
        for (i, (xb, yb)) in enumerate(loader)
            step += 1
            Flux.adjust!(opt, lr_at(schedule, (step - 1) / max(S - 1, 1); lr_max, sched_kw...))
            g = Flux.gradient(m -> lossfn(m, xb, yb), model)
            Flux.update!(opt, model, g[1])
            i in fine_at && record_fine!(epoch - 1 + i / steps_per_epoch)
        end
        # evaluate every `eval_every` epochs (and always at the last) — lets small-data runs use many short epochs
        (epoch % eval_every == 0 || epoch == epochs) || continue
        push!(tr_hist, mse(pred(Xtr), ytr))
        push!(te_hist, mse(pred(Xte), yte))
        push!(va_hist, eval_va())
        push!(lr_epoch, lr_at(schedule, (step - 1) / max(S - 1, 1); lr_max, sched_kw...))
        push!(t_epoch, time() - t0)
        if verbose && (epoch % max(1, epochs ÷ 10) == 0 || epoch == 1)
            @printf("  [%s] epoch %3d/%d  lr %.2e  train %.3e  val %.3e  test %.3e  %.0fs\n",
                    label, epoch, epochs, lr_epoch[end], tr_hist[end], va_hist[end], te_hist[end], t_epoch[end])
        end
    end
    ypred = Float64.(pred(X))
    return (; label, feature_names, arch, hidden, width, blocks, schedule, lr_max, sched_kw, epochs,
              batchsize, seed, n_params, split_name, tr_idx, te_idx, val_idx, val_days, weight_decay, target, mix_alpha,
              μ, σ, model, tr_hist, te_hist, va_hist, lr_epoch, t_epoch, ypred, mse_null, mse_lin,
              lr_curve = [lr_at(schedule, t; lr_max, sched_kw...) for t in range(0, 1, length=500)],
              evals_per_epoch, tr_fine, te_fine, fine_epoch, snaps, sub_tr, sub_te)
end
