# How well does each model match the tall table's measured sky, in MJy/sr? Rows = exposure × level-9 sub-pixel in the 192
# grid-2 patches at 4.9–5.01 μm (data/tt_train, git-ignored), each at its own wavelength (no colour conversion):
#   SPHEREx zodi (the tall table's zodi column), ZodiPy/Kelsall, our simulation-trained emulator, and the network trained on
#   the star-masked measured sky (≥ 50% clean rows, Huber loss, wavelength input; each patch predicted by networks that never
#   saw it, sweeps/results_real) brought back from 5.0 μm with Kelsall's colour.
# Raw models are compared as they are; "+ b" / "× a + b" versions are fit on the measured sky of each CV fold's training patches.
#     julia --project=. realdata/tt_match_mjy.jl
using DelimitedFiles, Statistics, Printf
ROOT = normpath(joinpath(@__DIR__, "..")); TD = joinpath(ROOT, "data", "tt_train"); RES = joinpath(ROOT, "sweeps", "results_real")
T, h = readdlm(joinpath(TD, "ttx_L6_g2_sub9_zodipy_ours.csv"), ',', header=true); h = vec(h); c(n) = T[:, findfirst(==(n), h)]
flux, zcol, zl, z5, ol = Float64.(c("flux_median")), Float64.(c("zodi_median")), Float64.(c("zodipy_lam")), Float64.(c("zodipy_5um")), Float64.(c("ours_lam"))
ra, dec = Float64.(c("ra")), Float64.(c("dec")); patch = parse.(Int, last.(split.(string.(c("patch")), "_")))
gb = asind.(sind.(dec) .* sind(27.12825) .+ cosd.(dec) .* cosd(27.12825) .* cosd.(ra .- 192.85948)); hiB = abs.(gb) .> 15
# star-masked measured sky (pixels flagged SOURCE dropped), joined on (patch, imageid, subpix)
M, hm = readdlm(joinpath(TD, "ttx_L6_g2_sub9_mask.csv"), ',', header=true); hm = vec(hm); cm(n) = M[:, findfirst(==(n), hm)]
mp, mi, ms, mc, mn, mf = cm("patch"), cm("imageid"), cm("subpix"), cm("n_clean"), cm("n_pix"), cm("flux_med_clean")
idx = Dict((string(mp[k]), string(mi[k]), Int(ms[k])) => k for k in axes(M, 1))
tp, ti, ts = c("patch"), c("imageid"), c("subpix")
km = [get(idx, (string(tp[k]), string(ti[k]), Int(ts[k])), 0) for k in axes(T, 1)]
fm = [k == 0 || mc[k] == 0 ? NaN : Float64(mf[k]) for k in km]; clean = [k == 0 ? 0.0 : mc[k] / mn[k] for k in km]
# the network: seed-averaged held-out predictions, folds 0–4 (target was the masked sky at 5.0 μm → back to each row's λ)
net = fill(NaN, length(flux))
for f in 0:4
    fs = filter(x -> occursin(Regex("^real_flux5mL_hub_c50_e1000_s\\d+" * (f == 0 ? "" : "_f$f") * "\\.pred\\.csv\$"), x), readdir(RES))
    P = [readdlm(joinpath(RES, x), ',', header=true)[1] for x in fs]; rows = Int.(P[1][:, 1]); te = P[1][:, 3] .== 1
    net[rows[te]] .= vec(mean(hcat([p[:, 5] for p in P]...), dims=2))[te]
end
net .*= zl ./ z5
fold = patch .% 5
"""Fit on the training patches of each fold, predict its test patches (A = design matrix)."""
function cvfit(A, t, ok)
    p = fill(NaN, length(t))
    for f in 0:4
        tr = ok .& (fold .!= f); te = fold .== f
        p[te] = A[te, :] * (A[tr, :] \ t[tr])
    end
    p
end
function table(title, t, rowmask)
    ok = rowmask .& isfinite.(t) .& isfinite.(net)
    one = ones(length(t))
    models = [("SPHEREx zodi (their model)", zcol), ("ZodiPy / Kelsall", zl), ("our emulator", ol),
              ("SPHEREx zodi + b", cvfit(hcat(one, zcol), t, ok)), ("ZodiPy × a + b", cvfit(hcat(zl, one), t, ok)),
              ("our emulator × a + b", cvfit(hcat(ol, one), t, ok)), ("network (trained on masked sky)", net)]
    @printf("\n%s: %d rows, measured median %.4f MJy/sr (16–84%%: %.4f–%.4f)\n", title, sum(ok), median(t[ok]), quantile(t[ok], [0.16, 0.84])...)
    @printf("  %-32s %10s %10s %11s %10s %9s\n", "model", "median", "bias", "median |Δ|", "rms Δ", "|Δ| %")
    for (nm, p) in models
        d = p[ok] .- t[ok]
        @printf("  %-32s %10.4f %+10.4f %11.4f %10.4f %8.2f%%\n", nm, median(p[ok]), median(d), median(abs.(d)), sqrt(mean(abs2, d)),
                100median(abs.(d) ./ t[ok]))
    end
end
if abspath(PROGRAM_FILE) == @__FILE__   # tables only when run directly (realdata/tt_patch_values.jl includes this file)
    println("MJy/sr at each row's own wavelength (4.9–5.01 μm); bias = median(model − measured); |Δ| % = median |model − measured| / measured")
    table("star-masked measured sky, |b| > 15°, rows ≥ 50% clean (the network's rows)", fm, hiB .& (clean .>= 0.5))
    table("unmasked measured sky, |b| > 15°, same rows", flux, hiB .& (clean .>= 0.5))
end
