# Our model at every row of the 7a extraction (realdata/ttx_merge.py → ttx_zodipy.py), as realdata/talltable_ours.jl does for
# one patch: the best model (parallax band layer, cos×exp 1000; 6 shifts × 5 seeds = 30 networks, averaged); SPHEREx's and
# Earth's positions from the nearest simulated exposure in time; pointing = the sub-pixel centre; moved from 5.0 μm to the
# row's wavelength with ZodiPy's spectral shape. Also writes the geometry inputs, for training on real data (task 7b).
#     julia --project=. realdata/ttx_ours.jl data/tt_train/ttx_L6_g2_sub9_zodipy.csv   → ..._ours.csv (+ _features.csv)
ENV["ZODI_DATA"] = "z500"; ENV["ZODI_HELIO"] = "1"
using LinearAlgebra; BLAS.set_num_threads(2)
redirect_stdout(devnull) do
    include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
    for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "shift_helpers.jl"); include(joinpath(@__DIR__, "..", "sweeps", f)); end
    include(joinpath(@__DIR__, "..", "sweeps", "configs_v24.jl"))
end
using DelimitedFiles, Serialization
src = ARGS[1]
tt, hdr = readdlm(src, ',', header=true); h = vec(hdr)
col(nm) = Float64.(tt[:, findfirst(==(nm), h)])
mjd, lam, ra, dec, zp_lam, zp_5 = col("t_mid_mjd"), col("wavelength"), col("ra"), col("dec"), col("zodipy_lam"), col("zodipy_5um")
M = length(mjd)
jd = mjd .+ 2400000.5; o = sortperm(times); ts = times[o]
idx = map(jd) do t
    k = clamp(searchsortedfirst(ts, t), 2, length(ts)); o[abs(ts[k] - t) < abs(ts[k-1] - t) ? k : k - 1]
end
dt_min = 1440 .* abs.(times[idx] .- jd)
@printf("%d rows; time match: median %.2f min, p99 %.1f min, max %.1f min\n", M, median(dt_min), quantile(dt_min, 0.99), maximum(dt_min))
ε = deg2rad(23.43929111)                                               # ICRS → ecliptic J2000 (the data's frame)
q = hcat(cosd.(dec) .* cosd.(ra), cosd.(dec) .* sind.(ra), sind.(dec))'
nT = vcat(q[1:1, :], cos(ε) .* q[2:2, :] .+ sin(ε) .* q[3:3, :], -sin(ε) .* q[2:2, :] .+ cos(ε) .* q[3:3, :])
F = hcat(dot_features(make_vectors(nT, idx))[2], extra_columns(nT, idx))
@assert size(F, 2) == length(dot_names_all)
runs = ["z500h_bandplx_cosexp1k_shift$(Δ)_s$s" for Δ in SHIFTS24 for s in 42:46]
P = zeros(M, length(runs))
for (k, nm) in enumerate(runs)
    r = deserialize(joinpath(RESULTS_DIR, nm * ".jls"))
    cols = [findfirst(==(c), dot_names_all) for c in r.feature_names]
    P[:, k] = predict_y(r, Float32.(((F[:, cols] .- r.μ') ./ r.σ')'))
    r = nothing; GC.gc()
end
ours5 = vec(mean(P, dims=2)); spread = vec(std(P, dims=2)); ours = ours5 .* zp_lam ./ zp_5
@printf("ours vs ZodiPy at 5 μm: median %+.4f%%, median |Δ| %.4f%%, p99 |Δ| %.3f%%; network spread median %.4f%%\n",
        median(100 .* (ours5 .- zp_5) ./ zp_5), median(100 .* abs.(ours5 .- zp_5) ./ zp_5),
        quantile(100 .* abs.(ours5 .- zp_5) ./ zp_5, 0.99), median(100 .* spread ./ ours5))
out = replace(src, ".csv" => "_ours.csv")
open(out, "w") do f
    println(f, join(h, ",") * ",ours_lam,ours_5um,ours_std,dt_match_min,sim_index")
    for i in 1:M
        println(f, join(string.(tt[i, :]), ",") * @sprintf(",%.6f,%.6f,%.6f,%.2f,%d", ours[i], ours5[i], spread[i], dt_min[i], idx[i]))
    end
end
# the network's geometry inputs at every row (all candidate features, named), for training on real data
open(replace(src, ".csv" => "_features.csv"), "w") do f
    println(f, join(dot_names_all, ","))
    for i in 1:M; println(f, join((@sprintf("%.8g", x) for x in F[i, :]), ",")); end
end
println("-> ", out)
