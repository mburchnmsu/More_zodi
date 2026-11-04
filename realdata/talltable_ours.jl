# Our model on real SPHEREx data: the best model (parallax band layer, cos×exp 1000; rounds 37–38, all 6 shifts × 5 seeds =
# 30 networks, averaged) at each exposure of a tall-table per-exposure table, compared with the measured brightness, SPHEREx's
# own zodi model (the tall table's zodi column) and ZodiPy (Kelsall).
# Geometry: the 500-day simulated data uses SPHEREx's real exposure times, so each real exposure takes SPHEREx's and Earth's
# positions and velocities from the nearest simulated exposure in time; the pointing is the target. Wavelength: our model
# is 5.0 μm; it is moved to each exposure's wavelength with ZodiPy's spectral shape (realdata/talltable_zodipy.py).
#     julia --project=. realdata/talltable_ours.jl [tag [name RA Dec csv]]
#         default: the pole, data/spherex_real/tt_nep_per_image_zodipy.csv → tt_nep_ours.csv, figures/<tag>_talltable_nep_ours.png
#         e.g. a binned patch (realdata/talltable_bins.py): ... 11042026 sep 90 -66.560708 ttbin_L8_sep_zodipy.csv
# The last panel subtracts each series' mean over all exposures (the mentor's step): what is left is the time-variable
# part, which a fixed sky (stars, galaxies, the Galaxy) cannot contribute to.
ENV["ZODI_DATA"] = "z500"; ENV["ZODI_HELIO"] = "1"
using LinearAlgebra; BLAS.set_num_threads(2)
redirect_stdout(devnull) do
    include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
    for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "shift_helpers.jl"); include(joinpath(@__DIR__, "..", "sweeps", f)); end
    include(joinpath(@__DIR__, "..", "sweeps", "configs_v24.jl"))
end
using DelimitedFiles, Serialization, CairoMakie
tag = isempty(ARGS) ? "talltable" : ARGS[1]
name, RA, DEC, csvname = length(ARGS) >= 5 ? (ARGS[2], parse(Float64, ARGS[3]), parse(Float64, ARGS[4]), ARGS[5]) :
                                            ("nep", 270.0, 66.560708, "tt_nep_per_image_zodipy.csv")
D = joinpath(@__DIR__, "..", "data", "spherex_real")
tt, hdr = readdlm(joinpath(D, csvname), ',', header=true); h = vec(hdr)
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

# the target direction in the data's frame (ecliptic J2000): rotate the ICRS unit vector by the obliquity
ε = deg2rad(23.43929111); q = [cosd(DEC) * cosd(RA), cosd(DEC) * sind(RA), sind(DEC)]
nT = repeat([q[1], cos(ε) * q[2] + sin(ε) * q[3], -sin(ε) * q[2] + cos(ε) * q[3]], 1, M)
@printf("%s: RA %.3f Dec %.3f → ecliptic latitude %.2f°\n", name, RA, DEC, asind(nT[3, 1]))
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
"""Robust fit flux = a·m + b (5 rounds of 4σ clipping on the MAD scatter): the scale and the constant offset."""
function fitab(m)
    A = [m ones(length(m))]; k = trues(length(m)); p = zeros(2)
    for _ in 1:5
        p = A[k, :] \ flux[k]; r = flux .- A * p; k = abs.(r) .< 4 * 1.4826median(abs.(r[k]))
    end
    p = A[k, :] \ flux[k]; r = flux .- A * p
    p[1], p[2], 1.4826median(abs.(r[k])), k
end
mad(v) = 1.4826median(abs.(v .- median(v)))
for (lbl, m) in (("ours (λ)", ours), ("ZodiPy (λ)", zp_lam), ("SPHEREx zodi column", zcol))
    d = flux .- m; a, b, s, k = fitab(m)
    @printf("measured − %-20s median %+.4f MJy/sr (%+.1f%%), scatter %.4f | fit: flux = %.3f·model %+.4f (scatter %.4f, %d/%d kept)\n",
            lbl, median(d), median(rel(flux, m)), mad(d), a, b, s, sum(k), M)
end
# the mentor's step: subtract each series' mean over all exposures (median, robust to the few outliers)
dflux = flux .- median(flux); dours = ours .- median(ours); dzcol = zcol .- median(zcol)
@printf("after subtracting each series' median over time: measured − ours scatter %.4f, measured − SPHEREx %.4f MJy/sr; time-variable amplitude (p95 − p5): measured %.4f, ours %.4f, SPHEREx %.4f\n",
        mad(dflux .- dours), mad(dflux .- dzcol),
        (quantile(dflux, 0.95) - quantile(dflux, 0.05)), (quantile(dours, 0.95) - quantile(dours, 0.05)),
        (quantile(dzcol, 0.95) - quantile(dzcol, 0.05)))
open(joinpath(D, "tt_$(name)_ours.csv"), "w") do f
    println(f, "t_mid_mjd,wavelength_median,flux_median,zodi_median,zodipy_lam,ours_lam,ours_5um,ours_std,zodipy_5um,dt_match_min")
    for i in 1:M
        @printf(f, "%.6f,%.4f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.2f\n", mjd[i], lam[i], flux[i], zcol[i], zp_lam[i], ours[i],
                ours5[i], spread[i], zp_5[i], dt_min[i])
    end
end

set_theme!(merge(Theme(fontsize=17), theme_black()))
fig = Figure(size=(2000, 1550))
ax = Axis(fig[1, 1], title=@sprintf("%s (RA %.2f, Dec %.2f; ecliptic latitude %.1f°), 4.9–5.0 μm, tall table, %d exposures: measured vs zodi models",
                                    name, RA, DEC, asind(nT[3, 1]), M), ylabel="MJy/sr")
scatter!(ax, mjd, flux, markersize=6, color=:white,
         label=startswith(csvname, "ttbin_L8") ? "measured (median over the 0.23° HEALPix patch)" : "measured (median over ~3.2')")
scatter!(ax, mjd, zcol, markersize=5, color=:orange, label="SPHEREx zodi model")
scatter!(ax, mjd, zp_lam, markersize=5, color=:lime, label="ZodiPy (Kelsall)")
scatter!(ax, mjd, ours, markersize=3, color=:magenta, label="our model (moved to each wavelength)")
Legend(fig[1:4, 2], ax, labelsize=15, framevisible=false, valign=:top)    # outside the panels: never hides data
ax2 = Axis(fig[2, 1], ylabel="measured − model (MJy/sr)")
for (m, c, l) in ((zcol, :orange, "SPHEREx zodi model"), (zp_lam, :lime, "ZodiPy"), (ours, :magenta, "our model"))
    scatter!(ax2, mjd, flux .- m, markersize=5, color=c, label=l)
end
hlines!(ax2, [0], color=(:grey, 0.6))
ax4 = Axis(fig[3, 1], ylabel="minus own median over time (MJy/sr)")
scatter!(ax4, mjd, dflux, markersize=6, color=:white, label="measured")
scatter!(ax4, mjd, dzcol, markersize=4, color=:orange, label="SPHEREx zodi model")
scatter!(ax4, mjd, dours, markersize=4, color=:magenta, label="our model")
hlines!(ax4, [0], color=(:grey, 0.6))
ax3 = Axis(fig[4, 1], ylabel="ours − ZodiPy (%)", xlabel="MJD (60800 = 2025-05-11, 61000 = 2025-11-27, 61200 = 2026-06-15)")
scatter!(ax3, mjd, rel(ours5, zp_5), markersize=5, color=:magenta); hlines!(ax3, [0], color=(:grey, 0.6))
linkxaxes!(ax, ax2, ax4, ax3)
rowsize!(fig.layout, 2, Relative(0.2)); rowsize!(fig.layout, 3, Relative(0.24)); rowsize!(fig.layout, 4, Relative(0.13))
save(joinpath(@__DIR__, "..", "figures", "$(tag)_talltable_$(name)_ours.png"), fig, px_per_unit=1.5)
println("ok")
