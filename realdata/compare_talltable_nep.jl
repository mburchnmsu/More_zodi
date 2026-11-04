# Cross-check of the first tall-table query (realdata/talltable_pole.py, web service) against our own cutout series at
# the north ecliptic pole (realdata/extract_frames.py → data/spherex_real/nep_d6.h5): same target, 4.9–5.0 μm, median over
# ~3.2'. Exposures are matched by mid-exposure time (within 2 minutes).
#     julia --project=. realdata/compare_talltable_nep.jl [tag]   → figures/<tag>_talltable_nep.png
using HDF5, Statistics, Printf, DelimitedFiles, CairoMakie, Dates
tag = isempty(ARGS) ? "talltable" : ARGS[1]
D = joinpath(@__DIR__, "..", "data", "spherex_real")
tt, hdr = readdlm(joinpath(D, "tt_nep_per_image.csv"), ',', header=true); h = vec(hdr)
col(nm) = Float64.(tt[:, findfirst(==(nm), h)])
t_tt, f_tt, z_tt, n_tt, w_tt = col("t_mid_mjd"), col("flux_median"), col("zodi_median"), col("n_pix"), col("wavelength_median")
c = h5open(joinpath(D, "nep_d6.h5")) do f
    (; mjd=read(f["mjd"]), img=read(f["img0"]), zodi=read(f["zodi0"]), zodipy=read(f["zodipy"]), n=read(f["n_box"]),
       coll=read(f["collection"]), lam=read(f["lam0"]))
end
okc = (c.n .> 0) .& .!isnan.(c.img)
@printf("tall table: %d exposures, MJD %.1f–%.1f, median %d pixels each, wavelength %.3f–%.3f μm\n", length(t_tt),
        extrema(t_tt)..., median(n_tt), extrema(w_tt)...)
@printf("cutouts:    %d frames with the target at 4.9–5.1 μm, MJD %.1f–%.1f\n", sum(okc), extrema(c.mjd[okc])...)
# match by time
m = Int[]; for i in findall(okc)
    j = argmin(abs.(t_tt .- c.mjd[i])); abs(t_tt[j] - c.mjd[i]) < 2 / 1440 ? push!(m, j) : push!(m, 0)
end
ic = findall(okc)[m .> 0]; jt = m[m .> 0]
rel(a, b) = 100 .* (a .- b) ./ b
@printf("matched: %d of %d cutout frames\n", length(ic), sum(okc))
@printf("flux  (tall table − cutouts): median %+.3f%%, median |Δ| %.3f%%\n", median(rel(f_tt[jt], c.img[ic])), median(abs.(rel(f_tt[jt], c.img[ic]))))
@printf("zodi  (tall table − cutouts): median %+.3f%%, median |Δ| %.3f%%\n", median(rel(z_tt[jt], c.zodi[ic])), median(abs.(rel(z_tt[jt], c.zodi[ic]))))
for cl in unique(c.coll[ic])                      # the cutouts come from two SPHEREx releases (qr2, qr3)
    k = c.coll[ic] .== cl
    @printf("  %-18s n=%3d  flux %+.3f%%  zodi %+.3f%%  (cutout target wavelength %.3f–%.3f μm)\n", cl, sum(k),
            median(rel(f_tt[jt[k]], c.img[ic[k]])), median(rel(z_tt[jt[k]], c.zodi[ic[k]])), extrema(c.lam[ic[k]])...)
end
mjd2date(x) = Date(1858, 11, 17) + Day(floor(Int, x))
set_theme!(merge(Theme(fontsize=17), theme_black()))
fig = Figure(size=(1700, 1000))
ax = Axis(fig[1, 1], title="North ecliptic pole, 4.9–5.0 μm: median over ~3.2' per exposure", ylabel="MJy/sr",
          xlabel="MJD (60800 = 2025-05-11, 61000 = 2025-11-27, 61200 = 2026-06-15)")
scatter!(ax, t_tt, f_tt, markersize=6, color=:white, label="tall table: measured (flux)")
scatter!(ax, t_tt, z_tt, markersize=6, color=:orange, label="tall table: SPHEREx zodi model (zodi column)")
scatter!(ax, c.mjd[okc], c.img[okc], markersize=10, marker=:circle, color=(:cyan, 0.0), strokecolor=:cyan, strokewidth=1,
         label="our cutouts: measured")
scatter!(ax, c.mjd[okc], c.zodipy[okc], markersize=5, color=:lime, label="ZodiPy (Kelsall) at the cutout times")
axislegend(ax, position=:rt, labelsize=15)
ax2 = Axis(fig[2, 1], ylabel="tall table − cutouts (%)", xlabel="MJD")
scatter!(ax2, c.mjd[ic], rel(f_tt[jt], c.img[ic]), markersize=6, color=:white, label="measured")
scatter!(ax2, c.mjd[ic], rel(z_tt[jt], c.zodi[ic]), markersize=6, color=:orange, label="SPHEREx zodi model")
hlines!(ax2, [0], color=(:grey, 0.6)); axislegend(ax2, position=:rt, labelsize=15)
rowsize!(fig.layout, 2, Relative(0.3))
save(joinpath(@__DIR__, "..", "figures", "$(tag)_talltable_nep.png"), fig, px_per_unit=1.5)
println("ok")
