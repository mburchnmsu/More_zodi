# Pixel-level difference imaging on the real SPHEREx cutout frames (Nov 17), the images behind the October movies
# (realdata/extract_frames.py → data/spherex_real/<target>_d6.h5: every exposure resampled, nearest pixel, onto a common
# north-up 160 × 160 grid of 6.15″ pixels, ~16′ across; IMAGE, ZODI, per-pixel wavelength and FLAGS).
# Per frame, only pixels at 4.9–5.1 μm and without detector-defect flags (OVERFLOW, SUR_ERROR, NONFUNC, MISSING, HOT, COLD,
# PERSIST); TRANSIENT/OUTLIER/SOURCE pixels are kept, since moving objects and transients carry those flags.
#   S = IMAGE − ZODI (SPHEREx's zodi model removes the smooth, changing zodi)
#   reference = per-pixel median of S over the frames of the same release (qr2 and qr3 are calibrated differently)
#   difference = S − reference − the frame's median (any leftover zodi level)
# Noise per frame: 1.4826 × MAD of the difference. Events: groups of > 5σ pixels (8-connected) in a frame.
#     julia --project=. realdata/diffimg_frames.jl [target]   (nep default; ecl045, b30l210)
#   → figures/11172026_<target>_diffimg_montage.png, _diffimg_movie.mp4 (git-ignored), printed statistics
using HDF5, CairoMakie, Statistics, Printf, Dates
const R = joinpath(@__DIR__, ".."); tgt = isempty(ARGS) ? "nep" : ARGS[1]
f = h5open(joinpath(R, "data", "spherex_real", "$(tgt)_d6.h5"))
mjd, lam0 = read(f["mjd"]), read(f["lam0"]); coll = String.(read(f["collection"]))
IMG, ZOD, LAM, FLG = (read(f[k]) for k in ("img", "zodi", "lam", "flags")); close(f)
NG, nf = size(IMG, 1), size(IMG, 3)
const DEFECT = sum(1 << b for b in (1, 2, 6, 9, 10, 11, 17))
good = (LAM .>= 4.9) .& (LAM .<= 5.1) .& isfinite.(IMG) .& isfinite.(ZOD) .& (FLG .>= 0) .&
       ((round.(Int64, max.(FLG, 0)) .& DEFECT) .== 0)
S = ifelse.(good, IMG .- ZOD, NaN32)
rel = [occursin("qr3", c) ? "qr3" : "qr2" for c in coll]
nmed(v) = (w = filter(isfinite, v); length(w) >= 3 ? median(w) : NaN)
REF = Dict(r => [nmed(S[i, j, rel .== r]) for i in 1:NG, j in 1:NG] for r in unique(rel))
D = similar(S)
for k in 1:nf
    d = S[:, :, k] .- REF[rel[k]]; m = nmed(vec(d)); D[:, :, k] .= d .- m
end
# the plain version (user's choice, Nov 17): raw image − the per-pixel median of the raw images (same release), minus the
# frame's median; zodi is not removed, so its change across the field (wavelength varies across the detector) stays in
Iraw = ifelse.(good, IMG, NaN32)
REFP = Dict(r => [nmed(Iraw[i, j, rel .== r]) for i in 1:NG, j in 1:NG] for r in unique(rel))
DP = similar(S)
for k in 1:nf
    d = Iraw[:, :, k] .- REFP[rel[k]]; DP[:, :, k] .= d .- nmed(vec(d))
end
npix = [count(isfinite, D[:, :, k]) for k in 1:nf]
σ = [(w = filter(isfinite, vec(D[:, :, k])); length(w) > 200 ? 1.4826 * median(abs.(w .- median(w))) : NaN) for k in 1:nf]
use = findall((npix .>= 1500) .& isfinite.(σ))
date(m) = DateTime(1858, 11, 17) + Millisecond(round(Int, m * 86_400_000))
@printf("%s: %d frames (%s), %d with ≥ 1500 usable pixels; MJD %.1f–%.1f\n", tgt, nf,
        join(["$(count(==(r), rel)) $r" for r in sort(unique(rel))], ", "), length(use), extrema(mjd[use])...)
@printf("per-frame noise of the difference image (MAD): median %.4f MJy/sr (5–95%%: %.4f–%.4f)\n", median(σ[use]), quantile(σ[use], [0.05, 0.95])...)
Sref = filter(isfinite, vec(REF["qr2"])); @printf("reference image: median %.4f, 99.9th pct %.3f MJy/sr (bright stars)\n", median(Sref), quantile(Sref, 0.999))
# events: 8-connected groups of > 5σ pixels
function groups(mask)
    lab = zeros(Int, size(mask)); n = 0
    for I in CartesianIndices(mask)
        (mask[I] && lab[I] == 0) || continue
        n += 1; st = [I]; lab[I] = n
        while !isempty(st)
            J = pop!(st)
            for di in -1:1, dj in -1:1
                K = J + CartesianIndex(di, dj)
                checkbounds(Bool, mask, K) && mask[K] && lab[K] == 0 && (lab[K] = n; push!(st, K))
            end
        end
    end
    lab, n
end
ev = NamedTuple[]
for k in use
    d = D[:, :, k]; lab, n = groups(isfinite.(d) .& (d .> 5σ[k]))
    for g in 1:n
        idx = findall(lab .== g); pk = argmax(d[idx])
        fl = round.(Int64, max.(FLG[idx, k], 0))
        push!(ev, (k=k, n=length(idx), peak=d[idx[pk]], at=idx[pk], ext=maximum(abs(a[1] - b[1]) + abs(a[2] - b[2]) for a in idx, b in idx),
                   trans=count(x -> (x & 1) != 0 || (x & (1 << 19)) != 0, fl), src=count(x -> (x & (1 << 21)) != 0, fl)))
    end
end
nev = length(ev); big = filter(e -> e.n >= 3, ev)
@printf("> 5σ events: %d in %d frames (%.1f per frame); %d of ≥ 3 pixels; %d touch a TRANSIENT/OUTLIER pixel; %d sit on a SOURCE pixel\n",
        nev, length(use), nev / length(use), length(big), count(e -> e.trans > 0, ev), count(e -> e.src > 0, ev))
streaks = filter(e -> e.n >= 8 && e.ext >= 3 * sqrt(e.n), ev)
@printf("elongated (≥ 8 px, extent ≥ 3√n): %d (satellite/asteroid-trail candidates) in frames %s\n", length(streaks),
        join(unique(Dates.format.(date.(mjd[[e.k for e in streaks]]), "yyyy-mm-dd")), ", "))
# figure: reference + 5 frames spread in time (image in band, difference); frames whose whole field is at 4.9–5.1 μm
full = filter(k -> npix[k] >= 0.9NG^2, use); pool = isempty(full) ? use : full
@printf("frames with ≥ 90%% of the field usable: %d\n", length(full))
sel = pool[unique(round.(Int, range(1, length(pool), length=min(5, length(pool)))))]
# include the frame with the largest elongated event
if !isempty(streaks)
    kb = argmax(e -> e.n, streaks).k; kb in sel || (sel[3] = kb); sort!(sel, by=k -> mjd[k])
end
inb(k) = ifelse.(good[:, :, k], IMG[:, :, k], NaN32)
allimg = filter(isfinite, reduce(vcat, vec(inb(k)) for k in sel)); lo, hi = quantile(allimg, 0.01), quantile(allimg, 0.99)
dl = 4 * median(σ[use])
dlp = quantile(abs.(filter(isfinite, reduce(vcat, vec(DP[:, :, k]) for k in sel))), 0.99)
mad(v) = (w = filter(isfinite, v); 1.4826 * median(abs.(w .- median(w))))
σp = [mad(vec(DP[:, :, k])) for k in use]
@printf("robust spread (1.4826 MAD) per frame, median over frames: image − median image %.4f MJy/sr; zodi removed %.4f\n",
        median(σp), median(σ[use]))
set_theme!(merge(Theme(fontsize=16), theme_black()))
fig = Figure()
ext = NG * 6.15 / 60
panel(pos; kw...) = (a = Axis(pos; aspect=DataAspect(), width=260, height=260, titlesize=15, kw...); hidedecorations!(a); a)
for (j, k) in enumerate(sel)
    heatmap!(panel(fig[1, j + 1], title=@sprintf("%s  %s", Dates.format(date(mjd[k]), "yyyy-mm-dd"), rel[k])), inb(k),
             colormap=:inferno, colorrange=(lo, hi), nan_color=(:grey20, 1.0))
    heatmap!(panel(fig[2, j + 1]), DP[:, :, k], colormap=Reverse(:RdBu_9), colorrange=(-dlp, dlp), nan_color=(:grey20, 1.0))
    heatmap!(panel(fig[3, j + 1]), D[:, :, k], colormap=Reverse(:RdBu_9), colorrange=(-dl, dl), nan_color=(:grey20, 1.0))
end
# column 1: the two median images that are subtracted
P2 = filter(isfinite, vec(REFP["qr2"])); plo, phi = quantile(P2, 0.01), quantile(P2, 0.99)
heatmap!(panel(fig[1, 1], title="median image (qr2)"), REFP["qr2"], colormap=:inferno, colorrange=(plo, phi), nan_color=(:grey20, 1.0))
rlo, rhi = quantile(Sref, 0.01), quantile(Sref, 0.99)
heatmap!(panel(fig[3, 1], title="median of image − zodi (qr2)"), REF["qr2"], colormap=:inferno, colorrange=(rlo, rhi), nan_color=(:grey20, 1.0))
Colorbar(fig[1, 0], colormap=:inferno, colorrange=(plo, phi), label="median image (MJy/sr)", flipaxis=false)
Colorbar(fig[3, 0], colormap=:inferno, colorrange=(rlo, rhi), label="median of image − zodi", flipaxis=false)
Label(fig[2, 1], "row 1: image (4.9–5.1 μm pixels)\nrow 2: image − median image\nrow 3: (image − zodi) −\n  median of (image − zodi)\neach difference minus its own\nmedian level; grey: other λ",
      tellwidth=false, fontsize=15, justification=:left)
Colorbar(fig[1, length(sel) + 2], colormap=:inferno, colorrange=(lo, hi), label="image (MJy/sr)")
Colorbar(fig[2, length(sel) + 2], colormap=Reverse(:RdBu_9), colorrange=(-dlp, dlp), label="image − median (MJy/sr)")
Colorbar(fig[3, length(sel) + 2], colormap=Reverse(:RdBu_9), colorrange=(-dl, dl), label="zodi removed (MJy/sr)")
name = Dict("nep" => "north ecliptic pole", "ecl045" => "the ecliptic at longitude 45°", "b30l210" => "30° above the ecliptic")
Label(fig[0, :], @sprintf("Difference imaging of real SPHEREx frames: %s, %.0f′ field, north up, 6.15″ pixels; median images from the same release",
                          get(name, tgt, tgt), ext), fontsize=18)
resize_to_layout!(fig)
save(joinpath(R, "figures", "11172026_$(tgt)_diffimg_montage.png"), fig, px_per_unit=1.5)
println("-> figures/11172026_$(tgt)_diffimg_montage.png")
# movie (only with MOVIE=1): image and difference side by side, every usable frame in time order
get(ENV, "MOVIE", "0") == "1" || exit(0)
fig = Figure(size=(1300, 650)); kk = Observable(use[1])
a1 = Axis(fig[1, 1], aspect=DataAspect(), title=lift(k -> @sprintf("%s UTC  %s  image", Dates.format(date(mjd[k]), "yyyy-mm-dd HH:MM"), rel[k]), kk))
heatmap!(a1, lift(inb, kk), colormap=:inferno, colorrange=(lo, hi), nan_color=(:grey20, 1.0))
a2 = Axis(fig[1, 2], aspect=DataAspect(), title="difference (image − zodi − reference)")
heatmap!(a2, lift(k -> D[:, :, k], kk), colormap=Reverse(:RdBu_9), colorrange=(-dl, dl), nan_color=(:grey20, 1.0))
for a in (a1, a2); hidedecorations!(a); end
Colorbar(fig[1, 3], colormap=Reverse(:RdBu_9), colorrange=(-dl, dl), label="MJy/sr")
record(fig, joinpath(R, "figures", "11172026_$(tgt)_diffimg_movie.mp4"), sort(use, by=k -> mjd[k]); framerate=clamp(length(use) ÷ 8, 2, 15), compression=32) do k
    kk[] = k
end
println("-> figures/11172026_$(tgt)_diffimg_movie.mp4")
