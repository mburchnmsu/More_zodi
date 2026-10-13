# Run a list of named configs sequentially and save each result.
#   julia run_configs.jl <config_file.jl> <name1> <name2> ...
# The config file defines `CONFIGS::Dict{String,NamedTuple}` of train_mb keyword args,
# plus an optional `features` key (:look_dir [default], :look_dir_dhat, :look_dir_noJ).
using LinearAlgebra; BLAS.set_num_threads(2)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
include(joinpath(@__DIR__, "mb_train.jl"))
include(joinpath(@__DIR__, "extra_features.jl"))
include(abspath(ARGS[1]))
using Serialization
for name in ARGS[2:end]
    out = joinpath(@__DIR__, "results", "$name.jls")
    isfile(out) && (println("skip $name (exists)"); continue)
    kw    = CONFIGS[name]
    feats = FEATURE_SETS[get(kw, :features, :look_dir)]
    r = train_mb(feats; label=name, Base.structdiff(kw, NamedTuple{(:features,)})...)
    serialize(out, r)
    @printf("DONE %s  final val %.4e  test %.4e  train %.4e  %.0fs\n",
            name, r.va_hist[end], r.te_hist[end], r.tr_hist[end], r.t_epoch[end])
end
