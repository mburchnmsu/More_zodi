# Speed benchmark, emulator side (for the poster's speed claim). Pair: poster/bench_zodipy.py (run that first: it
# writes bench_idx.txt = the exposures to time, and bench_zodipy_y.npy is not needed here).
#   julia --project=. -t 1 poster/bench_emulator.jl
# Times emulator v2 (5-network ensemble, features computed from raw geometry inside predict_zodi) on the same
# exposures, after a warm-up call (Julia compiles on first use).
using LinearAlgebra, Statistics, Printf, HDF5
include(joinpath(@__DIR__, "..", "emulator", "ZodiEmulator.jl")); using .ZodiEmulator
BLAS.set_num_threads(1)
const ROOT = joinpath(@__DIR__, "..")
idx = parse.(Int, readlines(joinpath(@__DIR__, "bench_idx.txt")))
em = load_emulator(joinpath(ROOT, "emulator", "zodi_emulator_v2.jld2"))
eph = load_ephemeris(joinpath(ROOT, "data", "d140", "spherex_vectors_bore_interpolated.h5"), idx)
nvec = h5open(f -> read(f["pointing/nvec_unit_cartesian"])[:, idx], joinpath(ROOT, "data", "d140", "boresight_pointing.h5"))
ytrue = h5open(f -> read(f["emission"])[idx], joinpath(ROOT, "data", "zodipy115_5um_boresight.h5"))

f(k) = predict_zodi(em, nvec[:, k]; S=eph.S[:, k], E=eph.E[:, k], vS=eph.vS[:, k], vE=eph.vE[:, k])
f(1:100)                                             # warm-up / compile
tb = minimum(@elapsed(f(1:length(idx))) for _ in 1:3)
@printf("emulator batch: %d exposures, best of 3 = %.3f s -> %.1f us per exposure (threads=%d)\n",
        length(idx), tb, 1e6tb / length(idx), Threads.nthreads())
f(1:1)
ts = [@elapsed(f(k:k)) for k in 1:200]
@printf("emulator single exposure: median %.1f us per call\n", 1e6median(ts))
o = f(1:length(idx)); fe = abs.(o.mean .- ytrue) ./ ytrue
@printf("accuracy on these exposures vs ZodiPy: median %.4f%%, p95 %.3f%%, in-domain %.1f%%\n",
        100median(fe), 100quantile(fe, 0.95), 100mean(o.in_domain))
