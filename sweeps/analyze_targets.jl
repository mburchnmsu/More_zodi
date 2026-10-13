# Step 1 analysis: output/target transforms — validation ranking, test ensembles, all-sky.
using LinearAlgebra; BLAS.set_num_threads(2)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl", "nb_verify_fns.jl", "summary_helpers.jl")
    include(joinpath(@__DIR__, f))
end
println("\n=== target transforms: validation (3 seeds, fit 0–100) and test (5 seeds, fit 0–111.4) ===")
show(stdout, MIME("text/plain"), target_table()); println()
println("\n=== all-sky (5-seed ensembles) ===")
show(stdout, MIME("text/plain"), target_allsky_table()); println()
# residuals vs time for each ensemble → where do the transforms differ?
D = Dict{String, Any}(lbl => as_ensemble(target_full_runs(t), lbl) for (lbl, t) in TARGETS)
save(joinpath(RES, "targets_residuals.png"), verify_residuals(D, first.(TARGETS); tag="_targets"))
println("\ntarget analysis done")
