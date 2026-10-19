# Execute the ACTUAL notebook cells (read from 10062026.ipynb) in order, with training
# replaced by loading the saved final_<set>_s* models, to verify the cells end-to-end.
#   julia test_nb_cells_v2.jl base|dhat
using LinearAlgebra; BLAS.set_num_threads(2)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
using JSON, Serialization
cells = Dict(c["id"] => join(c["source"]) for c in
             JSON.parse(read(joinpath(@__DIR__, "..", "notebooks", "10062026.ipynb"), String))["cells"])
run_cell(id) = (println("\n######## cell $id"); include_string(Main, cells[id], "cell_$id"))

which = isempty(ARGS) ? "base" : ARGS[1]
run_cell("7bf2c399")   # train_mb
run_cell("7e51abba")   # verification functions
run_cell("3ad89c95")   # n·δ̂ + feature sets
# stand-in for training: return the saved final model for that seed
const RES = joinpath(@__DIR__, "results")
train_mb(feats; seed, kw...) = deserialize(joinpath(RES, "final_$(which)_s$seed.jls"))
src = cells["e9281818"]
which == "dhat" && (src = replace(src, "ENS_FEATURES = :look_dir\n" => "ENS_FEATURES = :look_dir_dhat\n"))
println("\n######## cell e9281818 ($which)"); include_string(Main, src, "cell_ens")
run_cell("c519bc68")   # loss curves
run_cell("fb97d7c8")   # verify integrity + metrics
run_cell("93000427")   # residuals
run_cell("96679c8c")   # all-sky
cp(joinpath(PROJECT_DIR, "figures", "allsky_ensemble_maps.png"),
   joinpath(RES, "nbtest_allsky_$(which).png"), force=true)
println("\nNOTEBOOK CELLS OK ($which)")
