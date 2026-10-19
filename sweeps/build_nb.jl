# Build a notebook from a cell-text file.   julia build_nb.jl <cells_file.jl> <OUTNAME.ipynb>
# The cells file defines CELLS::Vector{Pair{String,String}} ("markdown"/"code" => source).
# Dated notebooks live in notebooks/ (since Oct 18): a bare OUTNAME is written there; setup cells must therefore load
# project files one folder up, e.g. include(joinpath(@__DIR__, "..", "zodi_setup.jl")).
include(joinpath(@__DIR__, "nbedit.jl"))
using Printf
const ROOT = joinpath(@__DIR__, "..")
src_nb = load_nb(joinpath(ROOT, "notebooks", "10062026.ipynb"))   # reuse the Julia kernel metadata
include(abspath(ARGS[1]))
nb = JSON.Object{String, Any}()
nb["cells"]    = [new_cell(t, s; id=@sprintf("c%03d", i)) for (i, (t, s)) in enumerate(CELLS)]
nb["metadata"] = src_nb["metadata"]
nb["nbformat"] = src_nb["nbformat"]; nb["nbformat_minor"] = src_nb["nbformat_minor"]
out = dirname(ARGS[2]) == "" ? joinpath(ROOT, "notebooks", ARGS[2]) : joinpath(ROOT, ARGS[2]); save_nb(out, nb)
println("wrote $out with $(length(CELLS)) cells")
