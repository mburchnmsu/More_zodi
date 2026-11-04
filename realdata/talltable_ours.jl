# Our model on real SPHEREx data: the best model (parallax band layer, cos×exp 1000; rounds 37–38, all 6 shifts × 5 seeds =
# 30 networks, averaged) at each exposure of a tall-table per-exposure table, compared with the measured brightness, SPHEREx's
# own zodi model (the tall table's zodi column) and ZodiPy (Kelsall).
# Geometry: the 500-day simulated data uses SPHEREx's real exposure times, so each real exposure takes SPHEREx's and Earth's
# positions and velocities from the nearest simulated exposure in time; the pointing is the target. Wavelength: our model
# is 5.0 μm; it is moved to each exposure's wavelength with ZodiPy's spectral shape (realdata/talltable_zodipy.py).
#     julia --project=. realdata/talltable_ours.jl [tag]
#         reads data/spherex_real/tt_nep_per_image_zodipy.csv → tt_nep_ours.csv, figures/<tag>_talltable_nep_ours.png
ENV["ZODI_DATA"] = "z500"; ENV["ZODI_HELIO"] = "1"
using LinearAlgebra; BLAS.set_num_threads(2)
redirect_stdout(devnull) do
    include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
    for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "shift_helpers.jl"); include(joinpath(@__DIR__, "..", "sweeps", f)); end
    include(joinpath(@__DIR__, "..", "sweeps", "configs_v24.jl"))
end
using DelimitedFiles, Serialization, CairoMakie
tag = isempty(ARGS) ? "talltable" : ARGS[1]
D = joinpath(@__DIR__, "..", "data", "spherex_real")
tt, hdr = readdlm(joinpath(D, "tt_nep_per_image_zodipy.csv"), ',', header=true); h = vec(hdr)
col(nm) = Float64.(tt[:, findfirst(==(nm), h)])
mjd, lam, flux, zcol, zp_lam, zp_5 = col("t_mid_mjd"), col("wavelength_median"), col("flux_median"), col("zodi_median"),
                                     col("zodipy_lam"), col("zodipy_5um")
M = length(mjd)

# nearest simulated exposure in time (sim times are Julian Dates)
jd = mjd .+ 2400000.5; o = sortperm(times); ts = times[o]
idx = map(jd) do t
    k = clamp(searchsortedfirst(ts, t), 2, length(ts)); o[abs(ts[k] - t) < abs(ts[k-1] - t) ? k : k - 1]
end
dt_min = 1440 .* abs.(times[idx] .- jd)
@printf("time match: median %.2f min, max %.1f min (sim covers MJD %.1f–%.1f; real %.1f–%.1f)\n", median(dt_min), maximum(dt_min),
        extrema(times .- 2400000.5)..., extrema(mjd)...)

# the target direction in the data's frame: the north ecliptic pole = ecliptic +z
nT = repeat([0.0, 0.0, 1.0], 1, M)
F = hcat(dot_features(make_vectors(nT, idx))[2], extra_columns(nT, idx))
Fsim = hcat(dot_features(make_vectors(nvec_unit_cartesian[:, idx], idx))[2], extra_columns(nvec_unit_cartesian[:, idx], idx))
@assert size(F, 2) == length(dot_names_all)

runs = ["z500h_bandplx_cosexp1k_shift$(Δ)_s$s" for Δ in SHIFTS24 for s in 42:46]
P = zeros(M, length(runs)); chk = 0.0
for (k, nm) in enumerate(runs)
    r = deserialize(joinpath(RESULTS_DIR, nm * ".jls"))
    cols = [findfirst(==(c), dot_names_all) for c in r.feature_names]
    X(Fm) = Float32.(((Fm[:, cols] .- r.μ') ./ r.σ')')
    P[:, k] = predict_y(r, X(F))
    global chk = max(chk, maximum(abs.(predict_y(r, X(Fsim)) .- Float32.(r.ypred[idx]))))   # pipeline check
    r = nothing; GC.gc()
end
@printf("pipeline check: refeaturized sim exposures reproduce the saved predictions to %.1e MJy/sr\n", chk)
ours5 = vec(mean(P, dims=2)); spread = vec(std(P, dims=2))
ours = ours5 .* zp_lam ./ zp_5
rel(a, b) = 100 .* (a .- b) ./ b
@printf("\nours vs ZodiPy at 5 μm (the model's job — emulate Kelsall): median %+.3f%%, median |Δ| %.3f%%, max |Δ| %.2f%%\n",
        median(rel(ours5, zp_5)), median(abs.(rel(ours5, zp_5))), maximum(abs.(rel(ours5, zp_5))))
@printf("network spread (std over 30): median %.4f%% of the prediction\n", median(100 .* spread ./ ours5))
for (lbl, m) in (("ours (λ)", ours), ("ZodiPy (λ)", zp_lam), ("SPHEREx zodi column", zcol))
    d = flux .- m
    @printf("measured − %-20s median %+.4f MJy/sr (%+.1f%%), scatter (1.4826·MAD) %.4f MJy/sr\n", lbl, median(d),
            median(rel(flux, m)), 1.4826median(abs.(d .- median(d))))
end
open(joinpath(D, "tt_nep_ours.csv"), "w") do f
    println(f, "t_mid_mjd,wavelength_median,flux_median,zodi_median,zodipy_lam,ours_lam,ours_5um,ours_std,zodipy_5um,dt_match_min")
    for i in 1:M
        @printf(f, "%.6f,%.4f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.2f\n", mjd[i], lam[i], flux[i], zcol[i], zp_lam[i], ours[i],
                ours5[i], spread[i], zp_5[i], dt_min[i])
    end
end

set_theme!(merge(Theme(fontsize=17), theme_black()))
fig = Figure(size=(1700, 1250))
ax = Axis(fig[1, 1], title="North ecliptic pole, 4.9–5.0 μm (tall table, 811 exposures): measured vs zodi models", ylabel="MJy/sr")
scatter!(ax, mjd, flux, markersize=6, color=:white, label="measured (median over ~3.2')")
scatter!(ax, mjd, zcol, markersize=5, color=:orange, label="SPHEREx zodi model")
scatter!(ax, mjd, zp_lam, markersize=5, color=:lime, label="ZodiPy (Kelsall)")
scatter!(ax, mjd, ours, markersize=3, color=:magenta, label="our model (moved to each wavelength)")
axislegend(ax, position=:rt, labelsize=15)
ax2 = Axis(fig[2, 1], ylabel="measured − model (MJy/sr)")
for (m, c, l) in ((zcol, :orange, "SPHEREx zodi model"), (zp_lam, :lime, "ZodiPy"), (ours, :magenta, "our model"))
    scatter!(ax2, mjd, flux .- m, markersize=5, color=c, label=l)
end
hlines!(ax2, [0], color=(:grey, 0.6)); axislegend(ax2, position=:lt, labelsize=15)
ax3 = Axis(fig[3, 1], ylabel="ours − ZodiPy (%)", xlabel="MJD (60800 = 2025-05-11, 61000 = 2025-11-27, 61200 = 2026-06-15)")
scatter!(ax3, mjd, rel(ours5, zp_5), markersize=5, color=:magenta); hlines!(ax3, [0], color=(:grey, 0.6))
linkxaxes!(ax, ax2, ax3); rowsize!(fig.layout, 2, Relative(0.28)); rowsize!(fig.layout, 3, Relative(0.18))
save(joinpath(@__DIR__, "..", "figures", "$(tag)_talltable_nep_ours.png"), fig, px_per_unit=1.5)
println("ok")
