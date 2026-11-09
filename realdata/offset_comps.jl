# Which part of Kelsall is too faint? The measured sky against Kelsall's components (realdata/talltable_zodipy_comps.py):
#   measured − Kelsall = constant + Σ_g k_g · component_g,  groups g = smooth cloud, dust bands (1+2+3), ring, trailing feature
# so k_g is how much too faint (k > 0) or too bright (k < 0) that component is. Two independent ways:
#   (A) across the sky: per patch the median over exposures, patches with |b| > bmin, one constant;
#   (B) over time within each patch: one constant per patch (absorbs any fixed sky: stars, the Galaxy, extragalactic light),
#       the k_g from how the components change over the year; all patches pooled, 4σ clipping.
# Uncertainties: bootstrap over patches. Kelsall = ZodiPy here (our model equals it to ≤ 0.06% on these exposures).
#     julia --project=. realdata/offset_comps.jl [tag [LEVEL G wtag bmin]]     (default 6 1 "-" 15; wtag "-" = 4.9–5.1 μm)
#       → figures/<tag>_offset_comps_L<LEVEL>_grid<G><wtag>.png, data/spherex_real/ttbin_L<LEVEL>_grid<G><wtag>_comps_fit.csv
using DelimitedFiles, Statistics, Printf, LinearAlgebra, Random, CairoMakie
tag = length(ARGS) >= 1 ? ARGS[1] : "talltable"
LEVEL, G = length(ARGS) >= 3 ? parse.(Int, ARGS[2:3]) : (6, 1)
wtag = length(ARGS) >= 4 && ARGS[4] != "-" ? ARGS[4] : ""; bmin = length(ARGS) >= 5 ? parse(Float64, ARGS[5]) : 15.0
D = joinpath(@__DIR__, "..", "data", "spherex_real")
C, _ = readdlm(joinpath(D, "ttbin_L$(LEVEL)_grid$(G)_centres.csv"), ',', header=true)
const RG = [-0.0548755604162154 -0.8734370902348850 -0.4838350155487132    # ICRS → Galactic (Hipparcos)
             0.4941094278755837 -0.4448296299600112  0.7469822444972189
            -0.8676661490190047 -0.1980763734312015  0.4559837761750669]
icrs(ra, dec) = [cosd(dec) * cosd(ra), cosd(dec) * sind(ra), sind(dec)]
GROUPS = ["cloud" => ["comp_cloud"], "bands" => ["comp_band1", "comp_band2", "comp_band3"], "ring" => ["comp_ring"],
          "feature" => ["comp_feature"]]
P = []
for i in axes(C, 1)
    f = joinpath(D, "ttbin_L$(LEVEL)_$(C[i, 1])$(wtag)_comps.csv"); isfile(f) || continue
    T, h = readdlm(f, ',', header=true); h = vec(h); size(T, 1) < 3 && continue
    col(c) = Float64.(T[:, findfirst(==(c), h)])
    X = reduce(hcat, [sum(col(c) for c in cs) for (_, cs) in GROUPS])
    push!(P, (; name=C[i, 1], b=asind((RG * icrs(C[i, 2], C[i, 3]))[3]), y=col("flux_median") .- col("zodipy_total"), X,
                total=col("zodipy_total"), ysp=col("zodi_median") .- col("zodipy_total")))
end
ng = length(GROUPS); gnames = first.(GROUPS)

fitA(ps) = (A = [ones(length(ps)) reduce(vcat, [median(p.X, dims=1) for p in ps])]; A \ [median(p.y) for p in ps])
function fitB(ps; total=false)
    Y = Float64[]; Xs = Matrix{Float64}[]
    for p in ps
        X = total ? reshape(p.total, :, 1) : p.X
        push!(Y, (p.y .- mean(p.y))...); push!(Xs, X .- mean(X, dims=1))
    end
    X = reduce(vcat, Xs); k = trues(length(Y)); c = zeros(size(X, 2))
    for _ in 1:5
        c = X[k, :] \ Y[k]; r = Y .- X * c; k = abs.(r) .< 4 * 1.4826median(abs.(r[k] .- median(r[k])))
    end
    X[k, :] \ Y[k]
end
boot(f, ps; n=1000) = (rng = MersenneTwister(1); reduce(hcat, [f(ps[rand(rng, 1:length(ps), length(ps))]) for _ in 1:n]))

offp = [p for p in P if abs(p.b) > bmin]
cA = fitA(offp); sA = vec(std(boot(fitA, offp), dims=2))
cB = fitB(P); sB = vec(std(boot(fitB, P), dims=2))
cT = fitB(P; total=true)[1]; sT = std(boot(ps -> fitB(ps; total=true), P))
# the same (B) fit with SPHEREx's own zodi model in place of the measured sky: does their model share the pattern?
Psp = [merge(p, (; y=p.ysp)) for p in P]
cS = fitB(Psp); sS = vec(std(boot(fitB, Psp), dims=2))
share = median(reduce(vcat, [p.X ./ p.total for p in offp]), dims=1)
cmat = cor(reduce(vcat, [p.X .- mean(p.X, dims=1) for p in P]))

lam = isempty(wtag) ? "4.9–5.1 μm" : "$(wtag[3:end]) μm window"
@printf("%s: %d patches (%d with |b| > %.0f°), %d exposures\n", lam, length(P), length(offp), bmin, sum(length(p.y) for p in P))
@printf("median share of Kelsall's total (|b| > %.0f°): %s\n", bmin, join((@sprintf("%s %.3f", g, s) for (g, s) in zip(gnames, share)), ", "))
println("k = fractional amount each component is too faint (measured − Kelsall = const + Σ k·component):")
@printf("  %-8s %-18s %-18s %s\n", "", "(A) across the sky", "(B) over time", "(B) SPHEREx zodi model instead of the sky")
for g in 1:ng
    @printf("  %-8s %+7.3f ± %.3f    %+7.3f ± %.3f    %+7.3f ± %.3f\n", gnames[g], cA[g+1], sA[g+1], cB[g], sB[g], cS[g], sS[g])
end
@printf("  (A) constant %.4f ± %.4f MJy/sr; (B) one scale for the whole of Kelsall: k = %+.3f ± %.3f\n", cA[1], sA[1], cT, sT)
println("correlation of the components' time variations (pooled): ")
for g in 1:ng; @printf("  %-8s %s\n", gnames[g], join((@sprintf("%+.2f", x) for x in cmat[g, :]), " ")); end

open(joinpath(D, "ttbin_L$(LEVEL)_grid$(G)$(wtag)_comps_fit.csv"), "w") do f
    println(f, "component,share,kA,kA_err,kB,kB_err,kB_spherex,kB_spherex_err")
    for g in 1:ng; @printf(f, "%s,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f\n", gnames[g], share[g], cA[g+1], sA[g+1], cB[g], sB[g], cS[g], sS[g]); end
    @printf(f, "constant_or_total,,%.4f,%.4f,%.4f,%.4f,,\n", cA[1], sA[1], cT, sT)
end

set_theme!(merge(Theme(fontsize=18), theme_black()))
fig = Figure(size=(1500, 650))
ax = Axis(fig[1, 1], xticks=(1:ng, ["smooth cloud", "dust bands", "ring", "trailing feature"]), ylabel="k (fraction too faint)",
          title="how much each Kelsall component is too faint")
x = 1:ng
errorbars!(ax, x .- 0.1, cA[2:end], sA[2:end], color=:white); scatter!(ax, x .- 0.1, cA[2:end], color=:white, markersize=14, label="(A) across the sky, |b| > $(round(Int, bmin))°")
errorbars!(ax, x .+ 0.1, cB, sB, color=:deepskyblue); scatter!(ax, x .+ 0.1, cB, color=:deepskyblue, markersize=14, label="(B) over time, per-patch constants")
errorbars!(ax, x .+ 0.3, cS, sS, color=:orange); scatter!(ax, x .+ 0.3, cS, color=:orange, marker=:diamond, markersize=14, label="(B) with SPHEREx's zodi model as the 'sky'")
hlines!(ax, [0], color=(:grey, 0.6))
hi = maximum(vcat(cA[2:end] .+ sA[2:end], cB .+ sB, cS .+ sS)); lo = minimum(vcat(cA[2:end] .- sA[2:end], cB .- sB, cS .- sS))
ylims!(ax, lo - 0.1(hi - lo), hi + 0.45(hi - lo)); axislegend(ax, position=:lt)    # room for the legend above the data
ax2 = Axis(fig[1, 2], xticks=(1:ng, ["cloud", "bands", "ring", "feature"]), ylabel="share of Kelsall's total", yscale=log10,
           title="median share of the total (|b| > $(round(Int, bmin))°)")
barplot!(ax2, x, vec(share), fillto=1e-4, color=:steelblue)
Label(fig[0, 1:2], "Tall table, $lam, $(length(P)) patches: measured − Kelsall = const + Σ k · component", font=:bold, fontsize=20)
colsize!(fig.layout, 2, Relative(0.32))
save(joinpath(@__DIR__, "..", "figures", "$(tag)_offset_comps_L$(LEVEL)_grid$(G)$(wtag).png"), fig, px_per_unit=1.5)
println("ok")
