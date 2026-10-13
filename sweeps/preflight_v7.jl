using LinearAlgebra; BLAS.set_num_threads(4)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
include(joinpath(@__DIR__, "mb_train.jl"))
include(joinpath(@__DIR__, "extra_features.jl"))
include(joinpath(@__DIR__, "configs_v7.jl"))
println("runs: ", length(CONFIGS))
o = sortperm(t_rel)
@printf("Earth's ecliptic longitude: day 0 → %.1f°, day 139.7 → %.1f° (%.1f° of orbit covered)\n",
        λE_deg[o[1]], λE_deg[o[end]], mod(λE_deg[o[end]] - λE_deg[o[1]], 360))
@printf("check: λ⊕ vs Sun direction from SPHEREx (should differ by ≈180°): median |Δ − 180| = %.2f°\n",
        median(abs.(mod.(λE_deg .- mod.(atand.(-spherex_positions[2, :], -spherex_positions[1, :]), 360), 360) .- 180)))
s_, c_ = Fd_raw[:, findfirst(==("sinλE"), dot_names_all)], Fd_raw[:, findfirst(==("cosλE"), dot_names_all)]
@printf("sin²+cos² = 1 everywhere: %s\n", all(abs.(s_ .^ 2 .+ c_ .^ 2 .- 1) .< 1e-12))
for sp in ("30 day split", "random split", "80/20 Chronological")
    tr, te = splits[sp]
    if sp == "80/20 Chronological"; tr = tr[t_rel[tr] .< 100]; end            # validation protocol fits days 0–100
    out(v) = begin lo, hi = extrema(v[tr]); 100mean((v[te] .< lo) .| (v[te] .> hi)) end
    @printf("  %-20s season features: test outside training range sinλ %.1f%%, cosλ %.1f%%\n", sp, out(s_), out(c_))
end
println("\nsmoke test, 1 epoch each:")
for nm in ("se_blk_s42", "t_mix025_full_s42", "t_mix1_full_s42")
    kw = CONFIGS[nm]
    r = train_mb(FEATURE_SETS[get(kw, :features, :look_dir)]; label=nm, Base.structdiff(kw, NamedTuple{(:features,)})..., epochs=1, verbose=false)
    @printf("  %-18s target %-7s feats %d  test %.3e  min pred %.3f\n", nm, r.target, length(r.feature_names), r.te_hist[end], minimum(r.ypred))
end
