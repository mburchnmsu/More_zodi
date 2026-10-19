# Poster data, part 5: train/test MSE curves of the poster's split (shift 0) and the shifted 30-day timeline.
# Poster v6 (Oct 18): the 750-epoch runs (round 21, z115_m750_shift*); the curves are epoch-averaged (mean of the 10
# in-epoch evaluations, round-18 logging). v1–v5 used the 100-epoch runs (round 16, raw end-of-epoch values).
#   julia --project=. poster/data_training.jl  → poster/fig_training.jld2
ENV["ZODI_DATA"] = "z115"
using LinearAlgebra; BLAS.set_num_threads(2)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "configs_v16.jl", "shift_helpers.jl", "r17_20_helpers.jl")
    include(joinpath(@__DIR__, "..", "sweeps", f))
end
using JLD2

const FAM = get(ENV, "POSTER_FAM", "z115_m750_shift")
fam(Δ) = "$(FAM)$Δ"
blk = runs16(fam(0))
epavg(rs, j) = reduce(hcat, [epoch_avg(r)[j] for r in rs])                # epochs × seeds
grid = collect(0:0.25:span_days)
status = zeros(Int, length(SHIFTS16), length(grid))                        # 0 train, 1 tested between, 2 tested at an end
med_in = fill(NaN, length(SHIFTS16)); med_edge = fill(NaN, length(SHIFTS16))
for (row, Δ) in enumerate(SHIFTS16)
    k = floor.(Int, (grid .- Δ) ./ 30); test = isodd.(k)
    edge = (30 .* k .+ Δ .<= 0) .| (30 .* (k .+ 1) .+ Δ .>= span_days)
    status[row, :] = ifelse.(.!test, 0, ifelse.(edge, 2, 1))
    te, e = relerr(runs16(fam(Δ))); inn = is_interior(Δ, te)
    any(inn) && (med_in[row] = median(abs.(e[inn]))); any(.!inn) && (med_edge[row] = median(abs.(e[.!inn])))
end
TR, TE = epavg(blk, 1), epavg(blk, 2)
jldsave(joinpath(@__DIR__, "fig_training.jld2"); blk_tr=TR, blk_te=TE, shifts=collect(SHIFTS16), grid, status, med_in,
        med_edge, span=span_days, epochs=blk[1].epochs)
@printf("%d seeds, %d epochs; final epoch-averaged train/test MSE %.2e / %.2e (%.1f×)\n", length(blk), blk[1].epochs,
        mean(TR[end, :]), mean(TE[end, :]), mean(TE[end, :]) / mean(TR[end, :]))
println("interior medians ", round.(med_in, digits=4), "\nedge medians ", round.(med_edge, digits=4))
