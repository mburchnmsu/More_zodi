# Week 15 task 4 (local check, Nov 20): the median of the zodi-cleaned difference image per exposure, against time, on the
# real NEP / ecliptic cutouts (data/spherex_real/<target>_d6.h5, as realdata/diffimg_frames.jl). Same recipe as the
# sky-wide version on Colibrí (realdata/tt_diffmed.py):
#   1. pixels at 4.9–5.1 μm with no flag at all (sources, transients, outliers and detector defects all masked)
#   2. S = IMAGE − ZODI, so the reference does not depend on each pixel's wavelength
#   3. reference = per-pixel median of S over time (per release here: these IRSA files carry qr2 and qr3 calibrations)
#   4. d = S − reference; per frame, 3σ clipping with σ = 1.4826 × MAD about the median, then the median of what is kept
#   → empirical zodi = median(ZODI) + median(d)
#     julia --project=. realdata/diffimg_timeseries.jl [target]  → figures/11202026_<target>_diffmed_time.png
using HDF5, CairoMakie, Statistics, Printf, Dates
const R = joinpath(@__DIR__, ".."); tgt = isempty(ARGS) ? "nep" : ARGS[1]
f = h5open(joinpath(R, "data", "spherex_real", "$(tgt)_d6.h5"))
mjd = read(f["mjd"]); coll = String.(read(f["collection"]))
IMG, ZOD, LAM, FLG = (read(f[k]) for k in ("img", "zodi", "lam", "flags")); close(f)
NG, nf = size(IMG, 1), size(IMG, 3)
good = (LAM .>= 4.9) .& (LAM .<= 5.1) .& isfinite.(IMG) .& isfinite.(ZOD) .& (FLG .== 0)
S = ifelse.(good, IMG .- ZOD, NaN32)
rel = [occursin("qr3", c) ? "qr3" : "qr2" for c in coll]
nmed(v) = (w = filter(isfinite, v); length(w) >= 5 ? median(w) : NaN)
REF = Dict(r => [nmed(S[i, j, rel .== r]) for i in 1:NG, j in 1:NG] for r in unique(rel))
rows = NamedTuple[]
for k in 1:nf
    d = vec(S[:, :, k] .- REF[rel[k]]); ok = isfinite.(d)
    sum(ok) < 200 && continue
    w = d[ok]; m = median(w); mad = median(abs.(w .- m)); keep = abs.(w .- m) .<= 3 * 1.4826 * mad
    z = vec(ZOD[:, :, k])[ok]; fl = vec(IMG[:, :, k])[ok]
    push!(rows, (mjd=mjd[k], rel=rel[k], n=sum(ok), kept=sum(keep), med_d=median(w[keep]), σ=1.4826mad,
                 zodi=median(z), flux=median(fl), zemp=median(z) + median(w[keep])))
end
t = [r.mjd for r in rows]; zemp, zodi, flux = ([getfield(r, s) for r in rows] for s in (:zemp, :zodi, :flux))
md = [r.med_d for r in rows]; err = [r.σ / sqrt(r.kept) for r in rows]
@printf("%s: %d frames with ≥ 200 unflagged pixels at 4.9–5.1 μm (of %d); median kept %d pixels (%.1f%% clipped)\n", tgt,
        length(rows), nf, median([r.kept for r in rows]), 100 * (1 - sum(r.kept for r in rows) / sum(r.n for r in rows)))
for r in ("qr2", "qr3")
    k = [x.rel == r for x in rows]; any(k) || continue
    @printf("  %s: %3d frames; median(d) %+.4f MJy/sr (scatter %.4f); empirical / SPHEREx zodi: median %.4f, scatter %.4f\n",
            r, sum(k), median(md[k]), 1.4826median(abs.(md[k] .- median(md[k]))), median(zemp[k] ./ zodi[k]),
            std(zemp[k] ./ zodi[k]))
end
date(m) = DateTime(1858, 11, 17) + Millisecond(round(Int, m * 86_400_000))
set_theme!(merge(Theme(fontsize=17), theme_black()))
fig = Figure(size=(1500, 900))
ax1 = Axis(fig[1, 1], ylabel="MJy/sr", title="$(uppercase(tgt)) cutouts, 4.9–5.1 μm, unflagged pixels: per-exposure medians")
scatter!(ax1, t, flux, color=:white, markersize=5, label="measured sky (median image)")
scatter!(ax1, t, zodi, color=:orange, markersize=5, label="SPHEREx zodi model (ZODI layer)")
scatter!(ax1, t, zemp, color=:cyan, markersize=5, label="empirical zodi = zodi + median of the difference image")
axislegend(ax1, position=:lt, framevisible=false)
ax2 = Axis(fig[2, 1], xlabel="MJD", ylabel="median(d), MJy/sr",
           title="median of the zodi-cleaned difference image (3σ-clipped), ± its standard error")
errorbars!(ax2, t, md, err, color=(:grey70, 0.6)); scatter!(ax2, t, md, color=[r.rel == "qr3" ? :cyan : :orange for r in rows], markersize=5)
hlines!(ax2, [0.0], color=:grey50); linkxaxes!(ax1, ax2)
Label(fig[3, 1], "orange: qr2 frames, cyan: qr3 frames (each release has its own reference image, so each scatters about 0)",
      fontsize=14, tellwidth=false)
save(joinpath(R, "figures", "11202026_$(tgt)_diffmed_time.png"), fig, px_per_unit=1.5)
println("ok")
