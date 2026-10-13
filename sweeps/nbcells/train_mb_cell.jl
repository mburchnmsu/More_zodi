# ==============================================================================
# MINI-BATCH TRAINING — MLP / ResMLP with per-step learning-rate schedules
# (same code as sweeps/mb_train.jl)
#
#   train_mb(feature_names; arch=:mlp, hidden=(64,64,32,16), width=64, blocks=3,
#            schedule=:onecycle, lr_max=1e-3, epochs=100, batchsize=512, seed=42,
#            val_days=nothing, weight_decay=0.0, target=:linear)
#
# Schedules (per optimizer step, t = progress 0 → 1):
#   :onecycle  — cosine warm-up from lr_max/25 to lr_max over the first `pct` of
#                training, then cosine anneal down to lr_max/1e4
#   :cosexp    — single cosine × exponential envelope (no restarts):
#                lr = lr_max · ½(1 + cos πt) · exp(−decay·t)
#   :linear    — straight line from lr_max to lr_max/10 (the full-batch recipe)
# val_days     — if set (e.g. 100.0), training exposures with t_rel ≥ val_days become a
#                VALIDATION period (days 100–111.4); the model is fit on the rest and
#                normalization/baselines use fit rows only. Use it to choose models;
#                keep the test period (days 111.4–139.7) for the final number.
# weight_decay — decoupled decay applied after each Adam step (1e-6 harmless, 1e-5 underfits)
# target       — output handling (see below); always use predict_y(run, X) to get MJy/sr
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
to_y(target, z) = target === :log ? exp.(z) : z            # network output → MJy/sr
predict_y(r, X) = to_y(get(r, :target, :linear), predict_batched(r.model, X))

function train_mb(feature_names; arch=:mlp, hidden=(64, 64, 32, 16), width=64, blocks=3,
                  schedule=:onecycle, lr_max=1e-3, epochs=100, batchsize=512, seed=42,
                  split_name="80/20 Chronological", sched_kw=(;), label="", verbose=true,
                  val_days=nothing, weight_decay=0.0, target=:linear)
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

    t0 = time(); step = 0
    for epoch in 1:epochs
        for (xb, yb) in loader
            step += 1
            Flux.adjust!(opt, lr_at(schedule, (step - 1) / max(S - 1, 1); lr_max, sched_kw...))
            g = Flux.gradient(m -> lossfn(m, xb, yb), model)
            Flux.update!(opt, model, g[1])
        end
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
              batchsize, seed, n_params, split_name, tr_idx, te_idx, val_idx, val_days, weight_decay, target,
              μ, σ, model, tr_hist, te_hist, va_hist, lr_epoch, t_epoch, ypred, mse_null, mse_lin,
              lr_curve = [lr_at(schedule, t; lr_max, sched_kw...) for t in range(0, 1, length=500)])
end