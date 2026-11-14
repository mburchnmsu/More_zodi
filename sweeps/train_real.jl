# Week 14 task 7b: train our emulator's best architecture on REAL tall-table data instead of Kelsall (ZodiPy) targets.
# Data: the 7a extraction (192 grid-2 patches × exposures × level-9 sub-pixels, 4.9–5.01 μm; realdata/ttx_*.{py,jl}),
# with the network's geometry inputs from realdata/ttx_ours.jl. Same architecture and schedule as the best simulated model
# (parallax band layer, cos×exp, rounds 37–38); the simulated-data globals (Fd_raw, y, N, t_rel, splits) are replaced by
# the real ones before train_mb runs.
#   julia --project=. -t K sweeps/train_real.jl TARGET EPOCHS SEED [HOLDOUT]
#     TARGET  = zodi5   SPHEREx's zodi column moved to 5.0 μm with ZodiPy's spectral shape ("recreate the zodi column")
#             | flux5   the measured sky moved to 5.0 μm the same way (includes stars, galaxies and any constant)
#             | kel5    ZodiPy at 5.0 μm at the same rows (control: the same rows and split, but Kelsall targets)
#             | flux5m  flux5 with the star mask: medians over pixels without MP_SOURCE (realdata/ttx_mask_merge.py)
#             + "L" suffix (zodi5L, flux5mL, ...): the row's wavelength (within 4.9–5.01 μm) is a network input, put
#               before the band layer's 6 inputs (Week 14: SPHEREx zodi / Kelsall changes −1.4% per 0.05 μm)
#     HOLDOUT = k: test set = every k-th patch (default 5 → 39 of 192 patches held out across the sky)
#     FOLD    = f in 0:k−1: test set = patches with index % k == f (default 0), so k runs cover every patch once
#   → sweeps/results_real/real_<TARGET>_e<EPOCHS>_s<SEED>[_f<FOLD>].jls (+ predictions on every row in a CSV beside it)
#   A run whose result file already exists is skipped, so a resubmitted (e.g. preempted) array only redoes missing runs.
ENV["ZODI_DATA"] = "z500"; ENV["ZODI_HELIO"] = "1"
using LinearAlgebra; BLAS.set_num_threads(parse(Int, get(ENV, "OPENBLAS_NUM_THREADS", "2")))
const ROOT = normpath(joinpath(@__DIR__, ".."))
include(joinpath(ROOT, "zodi_setup.jl"))
include(joinpath(ROOT, "sweeps", "mb_train.jl"))
include(joinpath(ROOT, "sweeps", "extra_features.jl"))
include(joinpath(ROOT, "pipeline", "ZodiPipeline.jl")); using .ZodiPipeline
include(joinpath(ROOT, "sweeps", "configs_v24.jl"))
using DelimitedFiles, Serialization, Printf, Statistics
TARGET, EPOCHS, SEED = ARGS[1], parse(Int, ARGS[2]), parse(Int, ARGS[3]); HOLD = length(ARGS) >= 4 ? parse(Int, ARGS[4]) : 5
FOLD = length(ARGS) >= 5 ? parse(Int, ARGS[5]) : 0
name = "real_$(TARGET)_e$(EPOCHS)_s$(SEED)" * (HOLD == 5 ? "" : "_h$HOLD") * (FOLD == 0 ? "" : "_f$FOLD")
outdir = joinpath(ROOT, "sweeps", "results_real"); mkpath(outdir)
isfile(joinpath(outdir, "$name.jls")) && (println("$name: already done"); exit(0))
D = joinpath(ROOT, "data", "tt_train")
T, h = readdlm(joinpath(D, "ttx_L6_g2_sub9_zodipy_ours.csv"), ',', header=true); h = vec(h)
c(n) = T[:, findfirst(==(n), h)]
Fr, hf = readdlm(joinpath(D, "ttx_L6_g2_sub9_zodipy_features.csv"), ',', Float64, header=true)
@assert vec(hf) == dot_names_all "feature columns differ from this code's dot_names_all"
zcol, flux, zl, z5 = Float64.(c("zodi_median")), Float64.(c("flux_median")), Float64.(c("zodipy_lam")), Float64.(c("zodipy_5um"))
patch = parse.(Int, last.(split.(string.(c("patch")), "_"))); mjd = Float64.(c("t_mid_mjd"))
LAMIN = endswith(TARGET, "L"); TG = LAMIN ? TARGET[1:end-1] : TARGET
if TG == "flux5m"   # join the star-masked medians on (patch, imageid, subpix)
    M, hm = readdlm(joinpath(D, "ttx_L6_g2_sub9_mask.csv"), ',', header=true); hm = vec(hm)
    cm(n) = M[:, findfirst(==(n), hm)]
    key(p, i, s) = (string(p), string(i), Int(s))
    mp, mi, ms, mc, mf = cm("patch"), cm("imageid"), cm("subpix"), cm("n_clean"), cm("flux_med_clean")   # columns hoisted:
    tp, ti, ts = c("patch"), c("imageid"), c("subpix")                                                  # c() copies
    idx = Dict(key(mp[k], mi[k], ms[k]) => k for k in axes(M, 1))
    km = [get(idx, key(tp[k], ti[k], ts[k]), 0) for k in axes(T, 1)]
    fm = [k == 0 || mc[k] == 0 ? NaN : Float64(mf[k]) for k in km]
    @printf("star mask: %d of %d rows matched, %d with no clean pixels\n", count(>(0), km), length(km), count(isnan, fm))
end
yreal = TG == "zodi5" ? zcol .* z5 ./ zl : TG == "flux5" ? flux .* z5 ./ zl : TG == "kel5" ? z5 :
        TG == "flux5m" ? fm .* z5 ./ zl : error("TARGET?")
feats = copy(FEATURE_SETS[:sunseason_learnband_plx])
if LAMIN
    push!(dot_names_all, "λμm"); Fr = hcat(Fr, Float64.(c("wavelength"))); insert!(feats, length(feats) - 5, "λμm")
end
ok = isfinite.(yreal) .& (yreal .> 0) .& vec(all(isfinite.(Fr), dims=2))
@printf("%s: %d rows, %d usable; target median %.4f MJy/sr\n", TARGET, length(yreal), sum(ok), median(yreal[ok]))
# replace the simulated-data globals used by train_mb
global Fd_raw = Fr[ok, :]; global y = yreal[ok]; global N = length(y); global t_rel = mjd[ok] .- minimum(mjd[ok])
pk = patch[ok]; te = findall(pk .% HOLD .== FOLD); tr = findall(pk .% HOLD .!= FOLD)
splits["real patches"] = (tr, te)
@printf("split: %d train rows (%d patches), %d test rows (%d patches)\n", length(tr), length(unique(pk[tr])), length(te), length(unique(pk[te])))
kw = (; R24..., epochs=EPOCHS, arch=:bandplx, schedule=:cosexpw, lr_max=2e-3, sched_kw=(; decay=3.0, warm=0.05),
      split_name="real patches", seed=SEED, progress_every=25)
r = train_mb(feats; label=name, Base.structdiff(kw, NamedTuple{(:features,)})...)
tmp = joinpath(outdir, "$name.jls.part"); serialize(tmp, r); mv(tmp, joinpath(outdir, "$name.jls"); force=true)
cols = [findfirst(==(nm), dot_names_all) for nm in r.feature_names]
p = predict_y(r, Float32.(((Fd_raw[:, cols] .- r.μ') ./ r.σ')'))
rel(a, b) = 100 .* (a .- b) ./ b
for (lbl, k) in (("train", tr), ("test (held-out patches)", te))
    @printf("%-24s NN vs target: median |Δ| %.3f%%, rms %.3f%% | ZodiPy×median-scale vs target: median |Δ| %.3f%%\n", lbl,
            median(abs.(rel(p[k], y[k]))), sqrt(mean(abs2, rel(p[k], y[k]))),
            median(abs.(rel(z5[ok][k] .* median(y[tr] ./ z5[ok][tr]), y[k]))))
end
open(joinpath(outdir, "$name.pred.csv"), "w") do f
    println(f, "row,patch,test,target,pred")
    rows = findall(ok)
    for i in 1:N; @printf(f, "%d,%d,%d,%.6f,%.6f\n", rows[i], pk[i], pk[i] % HOLD == FOLD, y[i], p[i]); end
end
@printf("DONE %s test %.4e train %.4e\n", name, r.te_hist[end], r.tr_hist[end])
