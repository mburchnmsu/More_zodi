# Real SPHEREx data: the north ecliptic pole at 4.9–5.1 μm over time (detector D6, whose band ends at ~5.01 μm).
# Reads data/spherex_real/nep_d6.h5 (realdata/extract_frames.py) and writes
#   figures/<tag>_nep_movie.mp4      — one frame per exposure with the pole at 4.9–5.1 μm: the image on a common north-up
#                                      grid (only pixels at 4.9–5.1 μm shown) + the pole's brightness vs time
#   figures/<tag>_nep_lightcurve.png — the pole's brightness vs time: image, SPHEREx's own zodi model, ZodiPy
#   figures/<tag>_nep_montage.png    — 12 frames spread over the 17 months
#     julia --project=. realdata/make_movie.jl [tag]
using HDF5, CairoMakie, Statistics, Printf, Dates
const R = joinpath(@__DIR__, ".."); tag = isempty(ARGS) ? "nep" : ARGS[1]
f = h5open(joinpath(R, "data", "spherex_real", "nep_d6.h5"))
mjd, lam0, img0, zodi0, zp, var0 = (read(f[k]) for k in ("mjd", "lam0", "img0", "zodi0", "zodipy", "var0"))
coll = String.(read(f["collection"]))
keep = (lam0 .>= 4.9) .& (lam0 .<= 5.1) .& isfinite.(img0)
idx = findall(keep)
date(m) = DateTime(1858, 11, 17) + Millisecond(round(Int, m * 86_400_000))
d = date.(mjd); t = mjd .- mjd[idx[1]]
@printf("%d frames, %d with the pole at 4.9–5.1 μm (%s → %s); pole wavelength %.3f–%.3f μm\n", length(mjd), length(idx),
        Date(d[idx[1]]), Date(d[idx[end]]), extrema(lam0[idx])...)
@printf("pole, median over frames (MJy/sr): image %.4f   SPHEREx zodi %.4f   ZodiPy %.4f\n", median(img0[idx]), median(zodi0[idx]), median(zp[idx]))
@printf("SPHEREx zodi / ZodiPy: median %.4f, range %.4f–%.4f; image − SPHEREx zodi: median %.4f MJy/sr (spread %.4f)\n",
        median(zodi0[idx] ./ zp[idx]), extrema(zodi0[idx] ./ zp[idx])..., median(img0[idx] .- zodi0[idx]), std(img0[idx] .- zodi0[idx]))
@printf("frame-to-frame noise of the pole median (from VARIANCE, 961 px): ~%.5f MJy/sr\n", median(sqrt.(var0[idx] ./ 961)))
for (c, m) in (("qr2", occursin.("qr2", coll)), ("qr3", occursin.("qr3", coll))), (l1, l2) in ((4.9, 4.95), (4.95, 5.1))
    k = idx[m[idx] .& (l1 .<= lam0[idx] .< l2)]; length(k) < 5 && continue
    A = [zp[k] ones(length(k))]; a, b = A \ img0[k]
    @printf("  %s, pole at %.2f–%.2f μm: %3d frames; image = %.3f·ZodiPy + %.4f MJy/sr (rms %.4f); SPHEREx zodi / ZodiPy %.4f ± %.4f\n",
            c, l1, l2, length(k), a, b, sqrt(mean(abs2, img0[k] .- A * [a, b])), mean(zodi0[k] ./ zp[k]), std(zodi0[k] ./ zp[k]))
end

IMG = read(f["img"]); LAM = read(f["lam"]); close(f)        # (frames, 160, 160) in h5py order → Julia (160, 160, frames)
IMG = ndims(IMG) == 3 && size(IMG, 3) == length(mjd) ? IMG : permutedims(IMG, (3, 2, 1))
LAM = size(LAM, 3) == length(mjd) ? LAM : permutedims(LAM, (3, 2, 1))
inband(k) = (a = Float32.(IMG[:, :, k]); a[.!((LAM[:, :, k] .>= 4.9) .& (LAM[:, :, k] .<= 5.1))] .= NaN; a)
allpix = filter(isfinite, reduce(vcat, vec(inband(k)) for k in idx[1:max(1, length(idx) ÷ 60):end]))
lo, hi = quantile(allpix, 0.01), quantile(allpix, 0.995)
@printf("colour range %.3f–%.3f MJy/sr\n", lo, hi)
NG = size(IMG, 1); ext = (NG / 2) * 6.15 / 60          # arcmin

set_theme!(merge(Theme(fontsize=16), theme_black()))
cols = (img=:white, zodi=:orange, zp=:deepskyblue)
# the pole lands at two wavelengths (~4.93 and ~4.97 μm); zodi at 5 μm brightens ~1.5–2% per 0.01 μm, so they form two
# tracks: filled markers = 4.90–4.95 μm, open = 4.95–5.0 μm. Dashed line = start of the qr3 release (recalibrated).
lo_l = idx[lam0[idx] .< 4.95]; hi_l = idx[lam0[idx] .>= 4.95]
t_qr3 = minimum(t[i] for i in idx if occursin("qr3", coll[i]); init=Inf)
function lc_axes!(pos; title="", ms=6)
    ax = Axis(pos, xlabel="days since $(Date(d[idx[1]]))", ylabel="brightness at the pole (MJy/sr)", title=title)
    for (v, c, l) in ((img0, cols.img, "SPHEREx image (median, 3′ box)"), (zodi0, cols.zodi, "SPHEREx's zodi model (ZODI layer)"),
                      (zp, cols.zp, "ZodiPy (Kelsall), same time and wavelength"))
        scatter!(ax, t[lo_l], v[lo_l], color=(c, 0.8), markersize=ms, label=l)
        scatter!(ax, t[hi_l], v[hi_l], color=:transparent, strokecolor=(c, 0.8), strokewidth=1, markersize=ms)
    end
    isfinite(t_qr3) && vlines!(ax, [t_qr3 - 1], color=(:grey70, 0.8), linestyle=:dash)
    ax
end

# light curve figure
fig = Figure(size=(1500, 900))
ax = lc_axes!(fig[1, 1], title="North ecliptic pole at 4.9–5.01 μm, real SPHEREx data ($(length(idx)) exposures)")
axislegend(ax, position=:lt, labelsize=13)
ax2 = Axis(fig[2, 1], xlabel="days since $(Date(d[idx[1]]))", ylabel="ratio to ZodiPy")
scatter!(ax2, t[idx], img0[idx] ./ zp[idx], color=(cols.img, 0.7), markersize=5, label="image / ZodiPy")
scatter!(ax2, t[idx], zodi0[idx] ./ zp[idx], color=(cols.zodi, 0.8), markersize=5, label="SPHEREx zodi / ZodiPy")
hlines!(ax2, [1], color=:grey60); isfinite(t_qr3) && vlines!(ax2, [t_qr3 - 1], color=(:grey70, 0.8), linestyle=:dash)
text!(ax2, t_qr3 + 3, 1.02, text="qr3 release →", color=:grey70, fontsize=13)
axislegend(ax2, position=:lt, labelsize=13); linkxaxes!(ax, ax2)
text!(ax, 0.99, 0.02, space=:relative, align=(:right, :bottom), fontsize=13, color=:grey80,
      text="filled: pole at 4.90–4.95 μm · open: 4.95–5.0 μm · dashed: qr3 release starts (recalibrated)")
rowsize!(fig.layout, 2, Relative(0.35))
save(joinpath(R, "figures", "$(tag)_nep_lightcurve.png"), fig, px_per_unit=2)

# montage of 12 frames
fig = Figure(size=(1800, 1000)); sel = idx[round.(Int, range(1, length(idx), length=12))]
for (j, k) in enumerate(sel)
    a = Axis(fig[(j - 1) ÷ 6 + 1, (j - 1) % 6 + 1], aspect=DataAspect(), title=@sprintf("%s  %.3f μm", Date(d[k]), lam0[k]), titlesize=14)
    hidedecorations!(a); heatmap!(a, inband(k), colormap=:inferno, colorrange=(lo, hi), nan_color=(:grey20, 1.0))
    scatter!(a, [NG / 2 + 0.5], [NG / 2 + 0.5], marker=:circle, color=:transparent, strokecolor=:cyan, strokewidth=1.5, markersize=18)
end
Colorbar(fig[1:2, 7], colormap=:inferno, colorrange=(lo, hi), label="MJy/sr")
Label(fig[0, 1:6], "North ecliptic pole, $(round(Int, 2ext))′ × $(round(Int, 2ext))′, north up; only pixels at 4.9–5.1 μm shown (grey = other wavelengths); stars not masked; cyan circle = pole",
      fontsize=17)
save(joinpath(R, "figures", "$(tag)_nep_montage.png"), fig, px_per_unit=1.5)

# movie
fig = Figure(size=(1400, 620)); k_obs = Observable(idx[1])
a = Axis(fig[1, 1], aspect=DataAspect(), title=lift(k -> @sprintf("%s UTC   pole at %.3f μm", Dates.format(d[k], "yyyy-mm-dd HH:MM"), lam0[k]), k_obs))
hidedecorations!(a); heatmap!(a, lift(inband, k_obs), colormap=:inferno, colorrange=(lo, hi), nan_color=(:grey20, 1.0))
scatter!(a, [NG / 2 + 0.5], [NG / 2 + 0.5], marker=:circle, color=:transparent, strokecolor=:cyan, strokewidth=1.5, markersize=22)
Colorbar(fig[1, 2], colormap=:inferno, colorrange=(lo, hi), label="MJy/sr")
ax = lc_axes!(fig[1, 3], title="The pole's brightness over time"); axislegend(ax, position=:lt, labelsize=11)
vlines!(ax, lift(k -> [t[k]], k_obs), color=(:cyan, 0.6))
scatter!(ax, lift(k -> [Point2f(t[k], img0[k])], k_obs), color=:cyan, markersize=12)
colsize!(fig.layout, 3, Relative(0.5))
Label(fig[0, 1:3], "Real SPHEREx images of the north ecliptic pole at 4.9–5.1 μm ($(round(Int, 2ext))′ field, north up; grey = other wavelengths; stars not masked)", fontsize=17)
record(fig, joinpath(R, "figures", "$(tag)_nep_movie.mp4"), idx; framerate=15, compression=32) do k
    k_obs[] = k
end
println("ok")
