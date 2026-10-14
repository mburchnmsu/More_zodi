# One SLURM array task = one "lane" of training runs (the same runs the laptop sweeps did, split across nodes).
#   julia --project=<More_zodi> pipeline/cluster/run_lane.jl <configs_vN.jl> [--dry-run]
# Reads SLURM_ARRAY_TASK_ID (1-based; the sbatch script uses --array=1-N) and SLURM_ARRAY_TASK_COUNT, takes its
# round-robin share of the config names that have no saved result yet, and trains them exactly like
# sweeps/run_configs.jl. Already-saved runs are skipped, so re-submitting a failed array is safe.
using LinearAlgebra; BLAS.set_num_threads(parse(Int, get(ENV, "OPENBLAS_NUM_THREADS", "2")))
const ROOT = normpath(joinpath(@__DIR__, "..", ".."))
include(joinpath(ROOT, "zodi_setup.jl"))
include(joinpath(ROOT, "sweeps", "mb_train.jl"))
include(joinpath(ROOT, "sweeps", "extra_features.jl"))
include(joinpath(ROOT, "pipeline", "ZodiPipeline.jl")); using .ZodiPipeline
include(abspath(ARGS[1]))                                   # defines CONFIGS
using Serialization
task   = parse(Int, get(ENV, "SLURM_ARRAY_TASK_ID", "1"))
ntasks = parse(Int, get(ENV, "SLURM_ARRAY_TASK_COUNT", "1"))
resdir = RESULTS_DIR                                       # sweeps/results, or sweeps/results_z115 (zodi_setup.jl)
todo = filter(n -> !isfile(joinpath(resdir, "$n.jls")), collect(keys(CONFIGS)))
mine = slurm_lane(todo, task, ntasks)
println("task $task/$ntasks: $(length(mine)) of $(length(todo)) pending runs ($(length(CONFIGS)) in config): ", join(mine, " "))
"--dry-run" in ARGS && exit(0)
for name in mine
    out = joinpath(resdir, "$name.jls")
    isfile(out) && continue                                  # another task may have finished it meanwhile
    kw = CONFIGS[name]
    r = train_mb(FEATURE_SETS[get(kw, :features, :look_dir)]; label=name, Base.structdiff(kw, NamedTuple{(:features,)})...)
    tmp = out * ".part"; serialize(tmp, r); mv(tmp, out; force=true)   # atomic: no half-written results on preemption
    @printf("DONE %s  test %.4e  train %.4e  %.0fs\n", name, r.te_hist[end], r.tr_hist[end], r.t_epoch[end])
end
