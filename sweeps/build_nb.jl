# Build a notebook from a cell-text file.   julia build_nb.jl <cells_file.jl> <OUTNAME.ipynb>
# The cells file defines CELLS::Vector{Pair{String,String}} ("markdown"/"code" => source).
include(joinpath(@__DIR__, "nbedit.jl"))
using Printf
const ROOT = joinpath(@__DIR__, "..")
src_nb = load_nb(joinpath(ROOT, "10062026.ipynb"))          # reuse the Julia kernel metadata
include(abspath(ARGS[1]))
nb = JSON.Object{String, Any}()
nb["cells"]    = [new_cell(t, s; id=@sprintf("c%03d", i)) for (i, (t, s)) in enumerate(CELLS)]
nb["metadata"] = src_nb["metadata"]
nb["nbformat"] = src_nb["nbformat"]; nb["nbformat_minor"] = src_nb["nbformat_minor"]
out = joinpath(ROOT, ARGS[2]); save_nb(out, nb)
println("wrote $out with $(length(CELLS)) cells")
