# Week 14 task 7b report: the emulator architecture trained on REAL tall-table data (sweeps/train_real.jl), judged on whole
# held-out patches. Per target (zodi5 = SPHEREx's zodi column, flux5 = measured sky, kel5 = ZodiPy control; all at 5.0 μm):
# the seed-averaged network vs the target, against simple baselines whose 1–2 numbers are fit on the TRAINING patches only:
#   Kelsall × a (ZodiPy scaled), Kelsall × a + b, our Kelsall emulator × a + b, and (for flux5) SPHEREx zodi + b.
# Cross-validation: folds 0–4 (test = patches with index % 5 == f) give a held-out prediction for every patch.
#     julia --project=. sweeps/report_real.jl   (needs sweeps/results_real/*.pred.csv fetched from the cluster)
#     → figures/11142026_real_maps.png, figures/11142026_real_compare.png; prints the tables
using DelimitedFiles, Statistics, Printf, CairoMakie
include(joinpath(@__DIR__, "plot_sky_common.jl"))
ROOT = normpath(joinpath(@__DIR__, ".."))
RES = joinpath(ROOT, "sweeps", "results_real")
T, h = readdlm(joinpath(ROOT, "data", "tt_train", "ttx_L6_g2_sub9_zodipy_ours.csv"), ',', header=true); h = vec(h)
c(n) = T[:, findfirst(==(n), h)]
zcol, flux, zl, z5, o5 = Float64.(c("zodi_median")), Float64.(c("flux_median")), Float64.(c("zodipy_lam")), Float64.(c("zodipy_5um")), Float64.(c("ours_5um"))
ra, dec = Float64.(c("ra")), Float64.(c("dec"))
patch = parse.(Int, last.(split.(string.(c("patch")), "_")))
# Galactic latitude (J2000 north Galactic pole at RA 192.85948°, Dec 27.12825°)
gb = asind.(sind.(dec) .* sind(27.12825) .+ cosd.(dec) .* cosd(27.12825) .* cosd.(ra .- 192.85948))
hiB = abs.(gb) .> 15
targets = Dict("zodi5" => zcol .* z5 ./ zl, "flux5" => flux .* z5 ./ zl, "kel5" => z5)
zodi5 = targets["zodi5"]
rel(a, b) = 100 .* (a .- b) ./ b
stats(p, t) = (d = rel(p, t); (med=median(abs.(d)), rms=sqrt(mean(abs2, d)), bias=median(d)))

"""Seed-averaged prediction for one target and fold: (rows, prediction, test mask, number of seeds)."""
function ensemble(target, fold)
    fs = filter(f -> occursin(Regex("^real_$(target)_e1000_s\\d+" * (fold == 0 ? "" : "_f$fold") * "\\.pred\\.csv\$"), f), readdir(RES))
    isempty(fs) && return nothing
    P = [readdlm(joinpath(RES, f), ',', header=true)[1] for f in fs]
    rows = Int.(P[1][:, 1]); @assert all(Int.(p[:, 1]) == rows for p in P)
    (rows=rows, pred=vec(mean(hcat([p[:, 5] for p in P]...), dims=2)), test=P[1][:, 3] .== 1, n=length(fs))
end
"""Baselines fit on the training rows only: Kelsall·a, Kelsall·a + b, ours·a + b, (SPHEREx zodi + b)."""
function baselines(t, tr)
    a1 = median(t[tr] ./ z5[tr])
    A2 = [z5 ones(length(z5))]; p2 = A2[tr, :] \ t[tr]
    A3 = [o5 ones(length(o5))]; p3 = A3[tr, :] \ t[tr]
    b4 = median(t[tr] .- zodi5[tr])
    [("Kelsall × $(round(a1, digits=3))", z5 .* a1), (@sprintf("Kelsall × %.3f %+.3f", p2...), A2 * p2),
     (@sprintf("our emulator × %.3f %+.3f", p3...), A3 * p3), (@sprintf("SPHEREx zodi %+.3f", b4), zodi5 .+ b4)]
end

println("== fold 0 (39 held-out patches), seed-averaged network vs baselines (fit on the 153 training patches) ==")
for tg in ("zodi5", "kel5", "flux5")
    e = ensemble(tg, 0); e === nothing && (println("$tg: no results yet"); continue)
    t = targets[tg][e.rows]; tr, te = .!e.test, e.test
    s = stats(e.pred[te], t[te]); st = stats(e.pred[tr], t[tr])
    @printf("\n%s (%d seeds): NETWORK  test median |Δ| %.3f%%, rms %.3f%%, bias %+.3f%% | train median |Δ| %.3f%%\n", tg, e.n, s.med, s.rms, s.bias, st.med)
    trmask = in.(1:length(z5), Ref(Set(e.rows[tr])))
    for (nm, b) in baselines(targets[tg], trmask)
        sb = stats(b[e.rows][te], t[te]); @printf("    %-34s test median |Δ| %.3f%%, rms %.3f%%, bias %+.3f%%\n", nm, sb.med, sb.rms, sb.bias)
    end
    # off the Galactic plane only (starlight dominates the measured sky near the plane)
    hb = hiB[e.rows]; s = stats(e.pred[te .& hb], t[te .& hb])
    @printf("  |b| > 15° only: NETWORK test median |Δ| %.3f%%, rms %.3f%% (%d rows)\n", s.med, s.rms, sum(te .& hb))
    for (nm, b) in baselines(targets[tg], trmask .& hiB)
        sb = stats(b[e.rows][te .& hb], t[te .& hb]); @printf("    %-34s test median |Δ| %.3f%%, rms %.3f%%\n", nm * " (fit |b|>15°)", sb.med, sb.rms)
    end
end

# cross-validated held-out predictions for every patch (folds 0–4)
cv = Dict{String, Vector{Float64}}()
for tg in ("zodi5", "flux5")
    p = fill(NaN, length(z5)); nf = 0
    pb = [fill(NaN, length(z5)) for _ in 1:4]   # the same baselines, each fit on that fold's training patches (all rows)
    nb = ["Kelsall × a", "Kelsall × a + b", "our emulator × a + b", "SPHEREx zodi + b"]
    for f in 0:4
        e = ensemble(tg, f); e === nothing && continue
        p[e.rows[e.test]] .= e.pred[e.test]; nf += 1
        trm = in.(1:length(z5), Ref(Set(e.rows[.!e.test]))); tem = in.(1:length(z5), Ref(Set(e.rows[e.test])))
        for (j, (_, b)) in enumerate(baselines(targets[tg], trm)); pb[j][tem] .= b[tem]; end
    end
    nf == 5 || (println("$tg: only $nf/5 folds — skipping the cross-validated maps"); continue)
    cv[tg] = p; k = isfinite.(p)
    for (lab, m) in (("all rows", k), ("|b| > 15°", k .& hiB))
        s = stats(p[m], targets[tg][m])
        @printf("\n%s cross-validated over all 192 patches, %s: network median |Δ| %.3f%%, rms %.3f%%\n", tg, lab, s.med, s.rms)
        for j in 1:4
            sb = stats(pb[j][m], targets[tg][m]); @printf("    %-28s median |Δ| %.3f%%, rms %.3f%%\n", nb[j], sb.med, sb.rms)
        end
    end
end

if haskey(cv, "zodi5")
    set_theme!(merge(Theme(fontsize=18), theme_black()))
    pm(v) = [median(v[patch .== q]) for q in 0:191]
    lonlat = [(mod(median(ra[patch .== q]) + 180, 360) - 180, median(dec[patch .== q])) for q in 0:191]
    xy = [Point2f(moll_fwd(l, b)...) for (l, b) in lonlat]
    a1 = median(zodi5 ./ z5)
    panels = [("network (held out) − SPHEREx zodi", pm(rel(cv["zodi5"], zodi5))),
              ("Kelsall × $(round(a1, digits=3)) − SPHEREx zodi", pm(rel(z5 .* a1, zodi5)))]
    haskey(cv, "flux5") && push!(panels, ("network on measured sky (held out) − measured", pm(rel(cv["flux5"], targets["flux5"]))))
    fig = Figure()
    for (j, (ttl, v)) in enumerate(panels)
        ax = Axis(fig[1, j], aspect=DataAspect(), title=ttl, titlesize=20, width=720, height=360); hidedecorations!(ax); hidespines!(ax)
        lim = j == 3 ? 10.0 : 3.0
        sc = scatter!(ax, xy, color=v, colormap=Reverse(:RdBu_9), colorrange=(-lim, lim), markersize=26, strokecolor=:grey60, strokewidth=0.5)
        Colorbar(fig[2, j], sc, vertical=false, label="per-patch median (%)", width=Relative(0.7))
        Label(fig[3, j], @sprintf("median |value| %.2f%%", median(abs.(filter(isfinite, v)))), fontsize=16)
    end
    Label(fig[0, :], "per-patch median residual at 5.0 μm, equatorial (RA, Dec) Mollweide (each patch predicted by a network that never saw it)", fontsize=20)
    resize_to_layout!(fig)
    save(joinpath(ROOT, "figures", "11142026_real_maps.png"), fig, px_per_unit=1.5)
    println("-> figures/11142026_real_maps.png")
end
