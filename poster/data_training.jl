# Poster data, part 5: train/test MSE curves (the poster's split = shift 0, and a random 10% hold-out) and the shifted
# 30-day timeline (round 16, 10152026 notebook).   julia --project=. poster/data_training.jl  → poster/fig_training.jld2
ENV["ZODI_DATA"] = "z115"
using LinearAlgebra; BLAS.set_num_threads(2)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "configs_v16.jl", "shift_helpers.jl")
    include(joinpath(@__DIR__, "..", "sweeps", f))
end
using JLD2

hist(rs, f) = reduce(hcat, [Float64.(getfield(r, f)) for r in rs])      # epochs × seeds
blk, rnd = runs16(0), runs16("z115_sunseason_r90")
grid = collect(0:0.25:span_days)
status = zeros(Int, length(SHIFTS16), length(grid))                        # 0 train, 1 tested between, 2 tested at an end
med_in = fill(NaN, length(SHIFTS16)); med_edge = fill(NaN, length(SHIFTS16))
for (row, Δ) in enumerate(SHIFTS16)
    k = floor.(Int, (grid .- Δ) ./ 30); test = isodd.(k)
    edge = (30 .* k .+ Δ .<= 0) .| (30 .* (k .+ 1) .+ Δ .>= span_days)
    status[row, :] = ifelse.(.!test, 0, ifelse.(edge, 2, 1))
    te, e = relerr(runs16(Δ)); inn = is_interior(Δ, te)
    any(inn) && (med_in[row] = median(abs.(e[inn]))); any(.!inn) && (med_edge[row] = median(abs.(e[.!inn])))
end
jldsave(joinpath(@__DIR__, "fig_training.jld2"); blk_tr=hist(blk, :tr_hist), blk_te=hist(blk, :te_hist),
        rnd_tr=hist(rnd, :tr_hist), rnd_te=hist(rnd, :te_hist), shifts=collect(SHIFTS16), grid, status, med_in, med_edge,
        span=span_days)
@printf("seeds %d / %d; final mean train/test MSE blk %.2e / %.2e, random %.2e / %.2e\n", length(blk), length(rnd),
        mean(hist(blk, :tr_hist)[end, :]), mean(hist(blk, :te_hist)[end, :]), mean(hist(rnd, :tr_hist)[end, :]), mean(hist(rnd, :te_hist)[end, :]))
println("interior medians ", round.(med_in, digits=4), "\nedge medians ", round.(med_edge, digits=4))
