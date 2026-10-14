# Train every pending run of a config file with K trainings at once in ONE Julia process (threads), sharing one copy
# of the data. Same results as the separate-process lanes (pipeline/cluster/run_lane.jl), ~1/3 of the memory:
# 4 lanes ≈ 4 × 2.2 GB; this ≈ 2–3 GB total for the 423k-exposure data.
#   julia -t 4 --project=. sweeps/run_threaded.jl <configs_vN.jl> [--dry-run] [--only name1,name2]
# ZODI_DATA chooses the data/results folder as everywhere else. BLAS threads per training: ENV["BLAS_THREADS"] (default 1,
# so K trainings × 1 BLAS thread fill K cores). Finished runs are skipped; saves are atomic (.part → rename).
using LinearAlgebra; BLAS.set_num_threads(parse(Int, get(ENV, "BLAS_THREADS", "1")))
const ROOT = normpath(joinpath(@__DIR__, ".."))
include(joinpath(ROOT, "zodi_setup.jl"))
include(joinpath(ROOT, "sweeps", "mb_train.jl"))
include(joinpath(ROOT, "sweeps", "extra_features.jl"))
include(abspath(ARGS[1]))                                   # defines CONFIGS
using Serialization, Dates
resdir = get(ENV, "RESULTS_OVERRIDE", RESULTS_DIR); mkpath(resdir)   # override only for tests
only = let i = findfirst(==("--only"), ARGS); i === nothing ? nothing : split(ARGS[i+1], ',') end
todo = sort(filter(n -> !isfile(joinpath(resdir, "$n.jls")) && (only === nothing || n in only), collect(keys(CONFIGS))))
K = Threads.nthreads()
println("$(length(todo)) of $(length(CONFIGS)) runs pending; $K trainings at a time, $(BLAS.get_num_threads()) BLAS thread(s) each → $resdir")
"--dry-run" in ARGS && (foreach(println, todo); exit(0))

jobs = Channel{String}(length(todo)); foreach(n -> put!(jobs, n), todo); close(jobs)
const PRINT = ReentrantLock()
logmsg(msg) = lock(() -> (println(Dates.format(now(), "HH:MM:SS"), "  ", msg); flush(stdout)), PRINT)
workers = map(1:K) do w
    Threads.@spawn for name in jobs
        out = joinpath(resdir, "$name.jls"); isfile(out) && continue
        kw = CONFIGS[name]
        try
            t = @elapsed r = train_mb(FEATURE_SETS[get(kw, :features, :look_dir)]; label=name, verbose=false,
                                      Base.structdiff(kw, NamedTuple{(:features,)})...)
            tmp = out * ".part"; serialize(tmp, r); mv(tmp, out; force=true)
            logmsg(@sprintf("DONE %-28s test %.4e  train %.4e  %4.0fs  (worker %d)", name, r.te_hist[end], r.tr_hist[end], t, w))
        catch err
            logmsg("FAILED $name: " * sprint(showerror, err))
        end
    end
end
foreach(wait, workers)
logmsg("all workers finished")
