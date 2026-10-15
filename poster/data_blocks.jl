# Poster numbers for the harder test: the poster's model inputs (Sun frame + season = emulator v2 inputs) trained with
# whole 30-day blocks of the mission held out (z115_sunseason_blk_*), vs the random 10% hold-out (z115_sunseason_r90_*).
# Also: which days are held out.     julia --project=. poster/data_blocks.jl
ENV["ZODI_DATA"] = "z115"
using LinearAlgebra; BLAS.set_num_threads(2)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl", "extra_splits.jl", "summary_helpers.jl"); include(joinpath(@__DIR__, "..", "sweeps", f)); end
using Serialization

d = times .- minimum(times)                        # mission day of each exposure
for pre in ("z115_sunseason_r90", "z115_sunseason_blk", "z115_season_blk", "z115_season_ch")
    rs = [deserialize(joinpath(RESULTS_DIR, "$(pre)_s$s.jls")) for s in 42:46 if isfile(joinpath(RESULTS_DIR, "$(pre)_s$s.jls"))]
    isempty(rs) && continue
    te = rs[1].te_idx; e = ensemble_pred(rs); fe = 100abs.(e[te] .- y[te]) ./ y[te]
    @printf("%-20s %d seeds  test %6d (%.0f%%)  median %.4f%%  p95 %.3f%%  within 0.1%%: %.1f%%  features: %s\n", pre, length(rs),
            length(te), 100length(te) / N, median(fe), quantile(fe, 0.95), 100mean(fe .< 0.1), join(rs[1].feature_names, " "))
    if occursin("blk", pre) || occursin("ch", pre)            # held-out day ranges (merge consecutive days)
        days = sort(unique(floor.(Int, d[te]))); runs = []; s = days[1]; p = s
        for x in days[2:end]; x == p + 1 ? (p = x) : (push!(runs, (s, p)); s = p = x); end; push!(runs, (s, p))
        println("    held-out mission days: ", join(["$(a)–$(b+1)" for (a, b) in runs], ", "), "   (mission length $(round(maximum(d), digits=1)) d)")
    end
end
