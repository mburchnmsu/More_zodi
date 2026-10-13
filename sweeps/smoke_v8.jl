using LinearAlgebra; BLAS.set_num_threads(4)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
include(joinpath(@__DIR__, "mb_train.jl")); include(joinpath(@__DIR__, "extra_features.jl"))
include(joinpath(@__DIR__, "configs_v8.jl"))
println("new runs: ", length(CONFIGS))
for (L, sp) in BLOCK_LENGTHS
    tr, te = splits[sp]; @printf("  %-20s train %6d test %6d (%.0f%% test)\n", sp, length(tr), length(te), 100length(te) / N)
end
for (nm, lo, la) in PATCHES
    tr, te = splits["patch $nm"]
    @assert isempty(intersect(tr, te)) && length(tr) + length(te) == N
    @printf("  patch %-16s (%3.0f°, %+3.0f°): test %6d — disjoint & complete ✓\n", nm, lo, la, length(te))
end
for f in LC_FRACTIONS
    tr, te = splits[lc_split(f)]; @printf("  learning curve f=%-5s train %6d test %6d\n", f, length(tr), length(te))
end
for nm in ("bl1_season_s42", "patch1_base_s42", "lc0.01_season_s42")
    kw = CONFIGS[nm]; kw2 = (; Base.structdiff(kw, NamedTuple{(:features,)})..., epochs=min(kw.epochs, 4), eval_every=2)
    r = train_mb(FEATURE_SETS[kw.features]; label=nm, kw2..., verbose=false)
    @printf("  %-18s split %-24s %d evals, test %.2e, %.0fs\n", nm, r.split_name, length(r.te_hist), r.te_hist[end], r.t_epoch[end])
end
