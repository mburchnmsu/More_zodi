# Run every CODE cell of 10062026.ipynb that comes after the mini-batch summary cell, in order,
# with training replaced by the saved final_base models. Figures returned by cells are saved.
using LinearAlgebra; BLAS.set_num_threads(2)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
include(joinpath(@__DIR__, "nbedit.jl"))
using Serialization
nbpath = joinpath(@__DIR__, "..", "10062026.ipynb")
nb = load_nb(nbpath)
start = cell_index(nb, "8ffbb5d6")
out = joinpath(@__DIR__, "results", "_test_10062026"); mkpath(out)
stub_installed = false
for (k, c) in enumerate(nb["cells"][start+1:end])
    c["cell_type"] == "code" || continue
    s = join(c["source"]); id = c["id"]
    println("\n######## cell $id  ", first(split(strip(s), '\n'), 2)[end])
    v = include_string(Main, s, nbpath)              # nbpath → @__DIR__ = project folder
    v isa Makie.FigureLike && save(joinpath(out, "cell_$id.png"), v)
    # after train_mb is defined, swap in a stand-in that loads the saved run for that seed
    if !stub_installed && occursin("function train_mb(", s)
        include_string(Main, """
            const _saved_train_mb = train_mb
            train_mb(feats; seed, split_name="80/20 Chronological", kw...) =
                split_name == "80/20 Chronological" ? deserialize(joinpath(PROJECT_DIR, "sweeps", "results", "final_base_s\$seed.jls")) :
                _saved_train_mb(feats; seed, split_name, kw...)
        """)
        global stub_installed = true
    end
end
println("\n10062026 NEW CELLS OK")
