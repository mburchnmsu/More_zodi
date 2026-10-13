# Minimal .ipynb editor (no Python needed): replace / insert cells by id, preserving
# everything else. Cell sources are stored as a vector of lines (ipynb convention).
using JSON, Random
load_nb(path) = JSON.parse(read(path, String))
to_lines(src) = (ls = split(src, '\n'; keepempty=true); [i < length(ls) ? ls[i] * "\n" : ls[i] for i in eachindex(ls) if !(i == length(ls) && isempty(ls[i]))])
cell_index(nb, id) = findfirst(c -> get(c, "id", "") == id, nb["cells"])
function set_source!(nb, id, src)
    i = cell_index(nb, id); i === nothing && error("no cell $id")
    nb["cells"][i]["source"] = to_lines(src)
    if nb["cells"][i]["cell_type"] == "code"; nb["cells"][i]["outputs"] = []; nb["cells"][i]["execution_count"] = nothing; end
    nb
end
function new_cell(type, src; id=randstring(['0':'9'; 'a':'f'], 8))
    c = Dict{String,Any}("cell_type" => type, "id" => id, "metadata" => Dict{String,Any}(), "source" => to_lines(src))
    type == "code" && (c["outputs"] = []; c["execution_count"] = nothing)
    c
end
function insert_after!(nb, after_id, cell)
    i = after_id === nothing ? 0 : cell_index(nb, after_id)
    insert!(nb["cells"], i + 1, cell); cell["id"]
end
save_nb(path, nb) = open(io -> JSON.json(io, nb; pretty=true), path, "w")
