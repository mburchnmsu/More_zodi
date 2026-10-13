# Builds C:\JuliaProjects\More_zodi\10072026.ipynb — the presentation summary notebook.
#   julia build_10072026.jl
include(joinpath(@__DIR__, "nbedit.jl"))
using Printf
const ROOT = joinpath(@__DIR__, "..")
src_nb = load_nb(joinpath(ROOT, "10062026.ipynb"))          # reuse kernel metadata
include(joinpath(@__DIR__, "summary_text.jl"))               # defines CELLS::Vector{Pair{String,String}}
nb = JSON.Object{String, Any}()
nb["cells"]    = [new_cell(t, s; id=@sprintf("c%03d", i)) for (i, (t, s)) in enumerate(CELLS)]
nb["metadata"] = src_nb["metadata"]
nb["nbformat"] = src_nb["nbformat"]; nb["nbformat_minor"] = src_nb["nbformat_minor"]
out = joinpath(ROOT, "10072026.ipynb")
save_nb(out, nb)
println("wrote $out with $(length(CELLS)) cells")
