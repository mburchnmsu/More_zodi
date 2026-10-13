using LinearAlgebra; BLAS.set_num_threads(2)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
include(joinpath(@__DIR__, "mb_train.jl"))
include(joinpath(@__DIR__, "extra_features.jl"))
include(joinpath(@__DIR__, "configs_v2.jl"))
println(FEATURE_SETS)
@printf("n·δ̂ range %s  iqr %.3f\n", extrema(Fd_raw[:, end]), iqr(Fd_raw[:, end]))
for name in ("v_dhat_s42", "v_wd1e-5_s42", "blk_base_s42")
    kw = CONFIGS[name]
    r = train_mb(FEATURE_SETS[get(kw, :features, :look_dir)]; label=name,
                 Base.structdiff(kw, NamedTuple{(:features,)})..., epochs=1)
    @printf("%s: fit %d  val %d  test %d  feats %d  val %.3e test %.3e\n", name, length(r.tr_idx),
            length(r.val_idx), length(r.te_idx), length(r.feature_names), r.va_hist[end], r.te_hist[end])
    if !isempty(r.val_idx)
        @assert maximum(t_rel[r.tr_idx]) < minimum(t_rel[r.val_idx]) <= maximum(t_rel[r.val_idx]) <= minimum(t_rel[r.te_idx])
        @assert isempty(intersect(r.tr_idx, r.val_idx)) && length(r.tr_idx) + length(r.val_idx) + length(r.te_idx) == N
        println("  PASS fit < val < test, disjoint, complete")
    end
end
