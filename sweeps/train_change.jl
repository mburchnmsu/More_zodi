# Week 15 task 6 (redefined Nov 22, approved by the user with no λ input): a geometric network trained on the CHANGE of the
# sky only. No absolute zodi level is borrowed (no SPHEREx ZODI, no Kelsall × 1.165 added back).
# Data: realdata/tt_change.py → tt_change_prep.py (every 32nd partition): per exposure × level-9 cell, c = flux scaled to
# 5 μm minus each pixel's median over time, stars and all flagged pixels masked.
# Loss: residual r = c − f(geometry); per cell, its mean over that cell's training visits is removed before the (Huber)
# loss, so any per-cell constant (the static sky, an absolute zodi level) drops out and f learns only the change.
# Inputs, the onboarding notebook's vector registry (dot products, standardized with training medians and IQR/1.349):
#   ARM A: base registry {n̂, S⃗, ẑ}: n·S, n·z, S·z, S·S (rotation-invariant: the Week 15 card)
#   ARM B: A + v̂_E (Earth's velocity direction): n·v, S·v, z·v (time-variable, still invariant about ẑ)
# Split: 30-day blocks, test = blocks with index % 5 == FOLD (onboarding rung 2; same as the task 1 months test).
# Scoring: on the test visits, r minus that cell's median r over its TRAINING visits, robust rms (1.4826 MAD) in MJy/sr;
# SPHEREx ZODI scored on the same footing with its own change cz (realdata/tt_change.py) in place of f.
#   julia --project=. -t 4 sweeps/train_change.jl ARM FOLD SEED [EPOCHS=400]
#   → sweeps/results_change/chg_<ARM>_f<FOLD>_s<SEED>_e<EPOCHS>.jls (+ .test.f32 residuals of the test rows)
using Flux, Statistics, Random, Printf, Serialization, LinearAlgebra
BLAS.set_num_threads(parse(Int, get(ENV, "OPENBLAS_NUM_THREADS", "4")))
const ROOT = normpath(joinpath(@__DIR__, ".."))
ARM, FOLD, SEED = ARGS[1], parse(Int, ARGS[2]), parse(Int, ARGS[3]); EPOCHS = length(ARGS) >= 4 ? parse(Int, ARGS[4]) : 400
HOLD, BLOCK, BATCH, MINVIS = 5, 30.0, 8192, 3
FEATS = Dict("A" => ["n·S", "n·z", "S·z", "S·S"], "B" => ["n·S", "n·z", "S·z", "S·S", "n·v", "S·v", "z·v"])[ARM]
name = "chg_$(ARM)_f$(FOLD)_s$(SEED)_e$(EPOCHS)"
outdir = joinpath(ROOT, "sweeps", "results_change"); mkpath(outdir)
isfile(joinpath(outdir, "$name.jls")) && (println("$name: already done"); exit(0))

D = joinpath(ROOT, "data")
cols = filter(!isempty, readlines(joinpath(D, "tt_change_train.cols"))); nc = length(cols)
raw = reinterpret(Float32, read(joinpath(D, "tt_change_train.f32"))); M = permutedims(reshape(raw, nc, :))   # rows × cols
cell = reinterpret(Int64, read(joinpath(D, "tt_change_train.cell"))) |> collect
col(n) = Float64.(M[:, findfirst(==(n), cols)])
t, c, cz = col("t_mid"), col("c"), col("cz")
blk = floor.(Int, (t .- minimum(t)) ./ BLOCK); istest = blk .% HOLD .== FOLD
# cells (rows are sorted by cell): keep cells with ≥ MINVIS training visits and ≥ 1 test visit for scoring
starts = [1; findall(diff(cell) .!= 0) .+ 1]; stops = [starts[2:end] .- 1; length(cell)]
keepcell = [count(.!istest[a:b]) >= MINVIS for (a, b) in zip(starts, stops)]
@printf("%s: %d rows, %d cells (%d with ≥ %d training visits); test rows %d (%.1f%%)\n", name, length(c), length(starts),
        sum(keepcell), MINVIS, sum(istest), 100mean(istest))

X = reduce(hcat, [col(f) for f in FEATS])
tr_rows = reduce(vcat, [collect(a:b)[.!istest[a:b]] for (a, b, k) in zip(starts, stops, keepcell) if k])
μ = vec(median(X[tr_rows, :], dims=1)); σ = [(quantile(X[tr_rows, j], 0.75) - quantile(X[tr_rows, j], 0.25)) / 1.349 for j in axes(X, 2)]
σ[σ .== 0] .= 1
Xs = Float32.(((X .- μ') ./ σ')')                                          # features × rows
cdm = reduce(vcat, [c[g] .- mean(c[g]) for g in (collect(a:b)[.!istest[a:b]] for (a, b, k) in zip(starts, stops, keepcell) if k)])
sc = 1.4826 * median(abs.(cdm))                                            # target scale: spread of the change (MJy/sr)
y = Float32.(c ./ sc)
@printf("features %s; target scale %.5f MJy/sr\n", join(FEATS, ", "), sc)
# training groups: each kept cell's training rows
groups = [collect(a:b)[.!istest[a:b]] for (a, b, k) in zip(starts, stops, keepcell) if k]

Random.seed!(SEED)
model = Chain(Dense(length(FEATS) => 64, gelu), Dense(64 => 64, gelu), Dense(64 => 32, gelu), Dense(32 => 16, gelu), Dense(16 => 1))
huber(x, δ=3f0) = ifelse(abs(x) <= δ, 0.5f0 * x^2, δ * (abs(x) - 0.5f0 * δ))
"""Loss on one batch of whole cells: rows `rows`, group index `gid` (1..G), visits per group `cnt`."""
function closs(m, xb, yb, gid, cnt)
    r = yb .- vec(m(xb))
    mr = Flux.NNlib.scatter(+, r, gid; dstsize=(length(cnt),)) ./ cnt
    mean(huber.(r .- mr[gid]))
end
function batches(rng)
    order = shuffle(rng, eachindex(groups)); out = Vector{Vector{Int}}(); cur = Int[]; n = 0
    for g in order
        push!(cur, g); n += length(groups[g])
        n >= BATCH && (push!(out, cur); cur = Int[]; n = 0)
    end
    isempty(cur) || push!(out, cur); out
end
"""Per-cell offset = median of r over the cell's training visits; returns the test residuals for a prediction p (MJy/sr)."""
function test_resid(p)
    rt = fill(NaN, length(c))
    for (a, b, k) in zip(starts, stops, keepcell)
        k || continue
        r = c[a:b] .- p[a:b]; tr = .!istest[a:b]; te = istest[a:b]
        any(te) || continue
        rt[(a:b)[te]] .= r[te] .- median(r[tr])
    end
    rt
end
rrms(v) = (w = filter(isfinite, v); 1.4826 * median(abs.(w .- median(w))))
predict(m) = Float64.(vec(m(Xs))) .* sc
rZ = test_resid(cz); rZn = rrms(rZ)
r0 = test_resid(zeros(length(c))); r0n = rrms(r0)
@printf("baselines on the test visits (robust rms, MJy/sr): no change %.5f, SPHEREx ZODI %.5f\n", r0n, rZn)

opt = Flux.setup(Adam(2f-3), model); rng = MersenneTwister(SEED)
hist = NamedTuple[]; t0 = time()
for ep in 1:EPOCHS
    lr = ep <= ceil(Int, 0.05EPOCHS) ? 2f-3 * ep / ceil(Int, 0.05EPOCHS) : 2f-3 * Float32(0.5 * (1 + cos(π * (ep - 0.05EPOCHS) / (0.95EPOCHS)))) + 1f-6
    Flux.adjust!(opt, lr)
    tl = 0.0; nb = 0
    for bg in batches(rng)
        rows = reduce(vcat, groups[bg]); gid = reduce(vcat, [fill(i, length(groups[g])) for (i, g) in enumerate(bg)])
        cnt = Float32[length(groups[g]) for g in bg]
        xb, yb = Xs[:, rows], y[rows]
        l, gr = Flux.withgradient(m -> closs(m, xb, yb, gid, cnt), model)
        Flux.update!(opt, model, gr[1]); tl += l; nb += 1
    end
    if ep % 25 == 0 || ep == EPOCHS
        rN = test_resid(predict(model)); push!(hist, (ep=ep, train=tl / nb, test=rrms(rN)))
        @printf("ep %4d  lr %.2e  train loss %.4f  test robust rms %.5f MJy/sr (ZODI %.5f)  %.0f s\n", ep, lr, tl / nb, rrms(rN), rZn, time() - t0)
    end
end
p = predict(model); rN = test_resid(p)
ok = isfinite.(rN) .& isfinite.(rZ)
beat = mean(abs.(rN[ok]) .< abs.(rZ[ok]))
@printf("DONE %s: test robust rms network %.5f, ZODI %.5f, no change %.5f MJy/sr; median |r| %.5f vs %.5f; network closer on %.1f%% of test rows\n",
        name, rrms(rN[ok]), rrms(rZ[ok]), rrms(r0[ok]), median(abs.(rN[ok])), median(abs.(rZ[ok])), 100beat)
res = (name=name, arm=ARM, fold=FOLD, seed=SEED, epochs=EPOCHS, feats=FEATS, μ=μ, σ=σ, sc=sc, state=Flux.state(model), hist=hist,
       rms_net=rrms(rN[ok]), rms_zodi=rrms(rZ[ok]), rms_none=rrms(r0[ok]), beat=beat, minutes=(time() - t0) / 60)
tmp = joinpath(outdir, "$name.jls.part"); serialize(tmp, res); mv(tmp, joinpath(outdir, "$name.jls"); force=true)
# test rows: cell, t, c, network residual, ZODI residual, prediction (Float32 except the cell)
k = findall(ok)
open(joinpath(outdir, "$name.test.f32"), "w") do io
    write(io, Float32.(hcat(t[k], c[k], rN[k], rZ[k], p[k], col("elat")[k], col("elon")[k], col("f5")[k])'))
end
println("wrote ", length(k), " test rows")
