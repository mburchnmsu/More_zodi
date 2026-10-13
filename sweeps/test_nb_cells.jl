# Exercise the new notebook cells using saved sweep results instead of retraining.
using LinearAlgebra; BLAS.set_num_threads(2)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
include(joinpath(@__DIR__, "mb_train.jl"))
include(joinpath(@__DIR__, "nb_verify_fns.jl"))
using Serialization
RES = joinpath(@__DIR__, "results")
# stand-in for train_mb: load the saved run with the same seed (seeds 42–46 of 64-64-32-16)
saved = Dict(42 => "p1_onecycle_1e-3", 43 => "p1s_onecycle_1e-3_s43", 44 => "p1s_onecycle_1e-3_s44",
             45 => "p3_mlp_64-64-32-16_s45", 46 => "p3_mlp_64-64-32-16_s46")
function train_mb(feats; seed, kw...)
    r = deserialize(joinpath(RES, saved[seed] * ".jls"))
    # old phase-1 results predate mse_null/mse_lin → add them
    haskey(r, :mse_null) && return r
    tr, te = r.tr_idx, r.te_idx
    cols = [findfirst(==(nm), dot_names_all) for nm in r.feature_names]
    A = hcat(ones(N), (Fd_raw[:, cols] .- r.μ') ./ r.σ')
    merge(r, (; mse_null=mean(abs2, y[te] .- mean(y[tr])), mse_lin=mean(abs2, y[te] .- (A * (A[tr, :] \ y[tr]))[te])))
end
include(joinpath(@__DIR__, "nb_ensemble_cell.jl"))
include(joinpath(@__DIR__, "nb_mbplot_cell.jl"))
mb_labels = [ens_lbl, seed_labels...]
verify_integrity(runs_mb, [ens_lbl])
verify_metrics(runs_mb, mb_labels[1:3]; tag="_minibatch")
verify_residuals(runs_mb, mb_labels[1:3]; tag="_minibatch")
println("nb cells OK")
