using LinearAlgebra; BLAS.set_num_threads(2)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
include(joinpath(@__DIR__, "mb_train.jl"))
look_dir = filter(nm -> startswith(nm, "n·") && nm != "n·n", dot_names_all)
for (lbl, kw) in [("mlp64 bs1024", (; arch=:mlp, hidden=(64,64,32,16), batchsize=1024)),
                  ("mlp64 bs512",  (; arch=:mlp, hidden=(64,64,32,16), batchsize=512)),
                  ("mlp256 bs1024", (; arch=:mlp, hidden=(256,256,128,64), batchsize=1024)),
                  ("res128x4 bs1024", (; arch=:resmlp, width=128, blocks=4, batchsize=1024))]
    r = train_mb(look_dir; label=lbl, epochs=2, schedule=:onecycle, lr_max=3e-3, verbose=false, kw...)
    @printf("%-16s params %6d  epoch times %s  test after 2 ep %.3e\n", lbl, r.n_params, round.(diff(vcat(0, r.t_epoch)), digits=1), r.te_hist[end])
end
