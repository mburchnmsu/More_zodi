# Week 14 task 7b report: the emulator architecture trained on REAL tall-table data (sweeps/train_real.jl), judged on whole
# held-out patches. Per target (zodi5 = SPHEREx's zodi column, flux5 = measured sky, kel5 = ZodiPy control; flux5m = measured
# sky with the star mask; an "L" suffix = the same target with the wavelength as a network input; all at 5.0 μm):
# the seed-averaged network vs the target, against simple baselines whose numbers are fit on the TRAINING patches only:
#   Kelsall × a (ZodiPy scaled), Kelsall × a + b, our Kelsall emulator × a + b, Kelsall × f(λ) (median ratio in 0.005 μm
#   wavelength bins), and SPHEREx zodi + b.
# Cross-validation: folds 0–4 (test = patches with index % 5 == f) give a held-out prediction for every patch.
#     julia --project=. sweeps/report_real.jl   (needs sweeps/results_real/*.pred.csv fetched from the cluster)
#     → figures/11142026_real_maps.png; prints the tables
using DelimitedFiles, Statistics, Printf, CairoMakie
include(joinpath(@__DIR__, "plot_sky_common.jl"))
ROOT = normpath(joinpath(@__DIR__, ".."))
RES = joinpath(ROOT, "sweeps", "results_real")
TD = joinpath(ROOT, "data", "tt_train")
T, h = readdlm(joinpath(TD, "ttx_L6_g2_sub9_zodipy_ours.csv"), ',', header=true); h = vec(h)
c(n) = T[:, findfirst(==(n), h)]
zcol, flux, zl, z5, o5 = Float64.(c("zodi_median")), Float64.(c("flux_median")), Float64.(c("zodipy_lam")), Float64.(c("zodipy_5um")), Float64.(c("ours_5um"))
ra, dec, wl = Float64.(c("ra")), Float64.(c("dec")), Float64.(c("wavelength"))
patch = parse.(Int, last.(split.(string.(c("patch")), "_")))
# Galactic latitude (J2000 north Galactic pole at RA 192.85948°, Dec 27.12825°)
gb = asind.(sind.(dec) .* sind(27.12825) .+ cosd.(dec) .* cosd(27.12825) .* cosd.(ra .- 192.85948))
hiB = abs.(gb) .> 15
zodi5 = zcol .* z5 ./ zl
targets = Dict("zodi5" => zodi5, "zodi5L" => zodi5, "flux5" => flux .* z5 ./ zl, "kel5" => z5)
mfile = joinpath(TD, "ttx_L6_g2_sub9_mask.csv")
if isfile(mfile)   # star-masked measured sky, joined as in train_real.jl
    M, hm = readdlm(mfile, ',', header=true); hm = vec(hm); cm(n) = M[:, findfirst(==(n), hm)]
    key(p, i, s) = (string(p), string(i), Int(s))
    mp, mi, ms, mc, mn, mf = cm("patch"), cm("imageid"), cm("subpix"), cm("n_clean"), cm("n_pix"), cm("flux_med_clean")
    tp, ti, ts = c("patch"), c("imageid"), c("subpix")
    idx = Dict(key(mp[k], mi[k], ms[k]) => k for k in axes(M, 1))
    km = [get(idx, key(tp[k], ti[k], ts[k]), 0) for k in axes(T, 1)]
    fm = [k == 0 || mc[k] == 0 ? NaN : Float64(mf[k]) for k in km]
    fclean = [k == 0 ? NaN : mc[k] / mn[k] for k in km]
    targets["flux5m"] = targets["flux5mL"] = fm .* z5 ./ zl
    @printf("star mask: %.1f%% of pixels kept (row median %.1f%%); |b| > 15°: %.1f%%, |b| < 15°: %.1f%%\n",
            100sum(mc) / sum(mn), 100median(filter(isfinite, fclean)),
            100median(filter(isfinite, fclean[hiB])), 100median(filter(isfinite, fclean[.!hiB])))
end
rel(a, b) = 100 .* (a .- b) ./ b
stats(p, t) = (k = isfinite.(p) .& isfinite.(t); d = rel(p[k], t[k]); (med=median(abs.(d)), rms=sqrt(mean(abs2, d)), bias=median(d)))

"""Seed-averaged prediction for one target and fold: (rows, prediction, test mask, number of seeds)."""
function ensemble(target, fold)
    fs = filter(f -> occursin(Regex("^real_$(target)_e1000_s\\d+" * (fold == 0 ? "" : "_f$fold") * "\\.pred\\.csv\$"), f), readdir(RES))
    isempty(fs) && return nothing
    P = [readdlm(joinpath(RES, f), ',', header=true)[1] for f in fs]
    rows = Int.(P[1][:, 1]); @assert all(Int.(p[:, 1]) == rows for p in P)
    (rows=rows, pred=vec(mean(hcat([p[:, 5] for p in P]...), dims=2)), test=P[1][:, 3] .== 1, n=length(fs))
end
const BNAMES = ["Kelsall × a", "Kelsall × a + b", "our emulator × a + b", "Kelsall × f(λ)", "SPHEREx zodi + b"]
"""Baselines fit on the training rows only (tr: mask over all rows), as predictions for every row."""
function baselines(t, tr)
    tr = tr .& isfinite.(t)
    a1 = median(t[tr] ./ z5[tr])
    A2 = [z5 ones(length(z5))]; p2 = A2[tr, :] \ t[tr]
    A3 = [o5 ones(length(o5))]; p3 = A3[tr, :] \ t[tr]
    bin = clamp.(floor.(Int, (wl .- 4.9) ./ 0.005), 0, 22)
    fb = Dict(b => median(t[tr .& (bin .== b)] ./ z5[tr .& (bin .== b)]) for b in unique(bin[tr]))
    b5 = median(t[tr] .- zodi5[tr])
    [z5 .* a1, A2 * p2, A3 * p3, z5 .* [get(fb, b, a1) for b in bin], zodi5 .+ b5]
end
report(nm, p, t) = (s = stats(p, t); @printf("    %-24s median |Δ| %.3f%%, rms %.3f%%, bias %+.3f%%\n", nm, s.med, s.rms, s.bias))

println("\n== fold 0 (39 held-out patches), seed-averaged network vs baselines (fit on the 153 training patches) ==")
for tg in ("zodi5", "zodi5L", "kel5", "flux5", "flux5m", "flux5mL")
    haskey(targets, tg) || continue
    e = ensemble(tg, 0); e === nothing && continue
    t = targets[tg][e.rows]; tr, te = .!e.test, e.test
    st = stats(e.pred[tr], t[tr])
    @printf("\n%s (%d seeds), train median |Δ| %.3f%%; held out:\n", tg, e.n, st.med)
    report("NETWORK", e.pred[te], t[te])
    trmask = in.(1:length(z5), Ref(Set(e.rows[tr])))
    for (nm, b) in zip(BNAMES, baselines(targets[tg], trmask)); report(nm, b[e.rows][te], t[te]); end
end

# cross-validated held-out predictions for every patch (folds 0–4)
cv = Dict{String, Vector{Float64}}()
for tg in ("zodi5", "zodi5L", "flux5", "flux5m", "flux5mL")
    haskey(targets, tg) || continue
    p = fill(NaN, length(z5)); nf = 0
    pb = [fill(NaN, length(z5)) for _ in BNAMES]   # the same baselines, each fit on that fold's training patches (all rows)
    for f in 0:4
        e = ensemble(tg, f); e === nothing && continue
        p[e.rows[e.test]] .= e.pred[e.test]; nf += 1
        trm = in.(1:length(z5), Ref(Set(e.rows[.!e.test]))); tem = in.(1:length(z5), Ref(Set(e.rows[e.test])))
        for (j, b) in enumerate(baselines(targets[tg], trm)); pb[j][tem] .= b[tem]; end
    end
    nf == 5 || (nf > 0 && println("$tg: only $nf/5 folds — skipped"); continue)
    cv[tg] = p
    for (lab, m) in (("all rows", trues(length(p))), ("|b| > 15°", hiB))
        @printf("\n%s cross-validated over all 192 patches, %s:\n", tg, lab)
        report("NETWORK", p[m], targets[tg][m])
        for j in eachindex(BNAMES); report(BNAMES[j], pb[j][m], targets[tg][m]); end
    end
end
# masked vs unmasked measured sky on the same rows
if haskey(cv, "flux5") && haskey(cv, "flux5m")
    k = isfinite.(targets["flux5m"]) .& hiB
    println("\nmeasured sky, |b| > 15°, rows with clean pixels: each network against its own target")
    for tg in ("flux5", "flux5m", "flux5mL"); haskey(cv, tg) && report(tg, cv[tg][k], targets[tg][k]); end
end

if haskey(cv, "zodi5")
    set_theme!(merge(Theme(fontsize=18), theme_black()))
    pm(v) = [median(filter(isfinite, v[patch .== q])) for q in 0:191]
    lonlat = [(mod(median(ra[patch .== q]) + 180, 360) - 180, median(dec[patch .== q])) for q in 0:191]
    xy = [Point2f(moll_fwd(l, b)...) for (l, b) in lonlat]
    a1 = median(zodi5 ./ z5)
    panels = [("Kelsall × $(round(a1, digits=3)) − SPHEREx zodi", pm(rel(z5 .* a1, zodi5)), 3.0),
              ("network (held out) − SPHEREx zodi", pm(rel(cv["zodi5"], zodi5)), 3.0)]
    haskey(cv, "zodi5L") && push!(panels, ("network + wavelength input − SPHEREx zodi", pm(rel(cv["zodi5L"], zodi5)), 3.0))
    fsky = haskey(cv, "flux5mL") ? "flux5mL" : haskey(cv, "flux5m") ? "flux5m" : haskey(cv, "flux5") ? "flux5" : nothing
    fsky === nothing || push!(panels, ("network on measured sky ($fsky) − measured", pm(rel(cv[fsky], targets[fsky])), 10.0))
    fig = Figure()
    for (j, (ttl, v, lim)) in enumerate(panels)
        r_, c_ = fldmod1(j, 2)
        ax = Axis(fig[2r_ - 1, c_], aspect=DataAspect(), title=ttl, titlesize=20, width=720, height=360); hidedecorations!(ax); hidespines!(ax)
        sc = scatter!(ax, xy, color=v, colormap=Reverse(:RdBu_9), colorrange=(-lim, lim), markersize=26, strokecolor=:grey60, strokewidth=0.5)
        Colorbar(fig[2r_, c_], sc, vertical=false, label=@sprintf("per-patch median (%%); median |value| %.2f%%", median(abs.(filter(isfinite, v)))), width=Relative(0.7))
    end
    Label(fig[0, :], "per-patch median residual at 5.0 μm, equatorial (RA, Dec) Mollweide (each patch predicted by a network that never saw it)", fontsize=20)
    resize_to_layout!(fig)
    save(joinpath(ROOT, "figures", "11142026_real_maps.png"), fig, px_per_unit=1.5)
    println("-> figures/11142026_real_maps.png")
end
