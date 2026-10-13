using LinearAlgebra; BLAS.set_num_threads(4)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
include(joinpath(@__DIR__, "mb_train.jl")); include(joinpath(@__DIR__, "extra_features.jl"))
include(joinpath(@__DIR__, "configs_v9.jl"))
todo = sort([k for k in keys(CONFIGS) if !isfile(joinpath(@__DIR__, "results", "$k.jls"))])
println("configs: ", length(CONFIGS), "   still to run: ", length(todo))
for fs in (:season_bandsharp, :season_bandplx, :season_bandboth)
    println(fs, " → ", length(FEATURE_SETS[fs]), " features: ", join(FEATURE_SETS[fs], ", "))
end
for nm in ("b9_sharp_p1_s42", "b9_plx_blk_s42", "b9_both_ch_s42")
    kw = CONFIGS[nm]; kw2 = (; Base.structdiff(kw, NamedTuple{(:features,)})..., epochs=2, eval_every=1)
    r = train_mb(FEATURE_SETS[kw.features]; label=nm, kw2..., verbose=false)
    Xs = (Fd_raw[r.tr_idx, [findfirst(==(f), dot_names_all) for f in r.feature_names]] .- r.μ') ./ r.σ'
    @printf("  %-16s split %-22s test %.2e  finite=%s  max|x_std| = %.1f  σ(bands) = %s\n", nm, r.split_name, r.te_hist[end],
            all(isfinite, r.ypred), maximum(abs, Xs), join([@sprintf("%.3f", σ) for σ in r.σ[end-2:end]], " "))
end
