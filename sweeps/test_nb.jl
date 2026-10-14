# Execute every code cell of a notebook in order (as a fresh session would), save the figures each cell returns,
# and time the whole run.     julia --project=.. test_nb.jl <MMDDYYYY.ipynb>      → results/_test_<MMDDYYYY>/
using LinearAlgebra; BLAS.set_num_threads(4)
include(joinpath(@__DIR__, "nbedit.jl"))
using Printf
nbname = ARGS[1]; tag = splitext(basename(nbname))[1]
nbpath = joinpath(@__DIR__, "..", nbname)
nb  = load_nb(nbpath)
out = joinpath(@__DIR__, "results", "_test_$tag"); rm(out, recursive=true, force=true); mkpath(out)
t0 = time(); n = 0
for c in nb["cells"]
    c["cell_type"] == "code" || continue
    global n += 1
    s = join(c["source"]); t1 = time()
    println("\n######## [$n] cell $(c["id"]): ", first(split(strip(s), '\n')))
    v = include_string(Main, s, nbpath)
    if v !== nothing && isdefined(Main, :Makie) && v isa Main.Makie.FigureLike
        Main.save(joinpath(out, "cell_$(c["id"]).png"), v)
    elseif v !== nothing
        show(stdout, MIME("text/plain"), v); println()
    end
    @printf("   (%.0f s)\n", time() - t1)
end
@printf("\n%s RAN TOP TO BOTTOM: %d code cells in %.1f min\n", tag, n, (time() - t0) / 60)
