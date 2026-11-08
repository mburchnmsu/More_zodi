# What the grid offset (realdata/talltable_offsetmap.jl) is made of: away from the Galactic plane, fit
#     offset b1 = c0 + c1·(our model, median over the patch's exposures) [+ c2·csc|b|]
# c1 = how much Kelsall underestimates the zodi, in proportion; c0 = a constant sky; c2 = Galactic emission (csc|b| law).
# Run over all wavelength windows that have an offsets file, it gives the spectrum of c0 and c1.
#     julia --project=. realdata/offset_fit.jl [tag [LEVEL G bmin]]   (default 6 1 15)
#       → data/spherex_real/ttbin_L<LEVEL>_grid<G>_offset_fit.csv, figures/<tag>_offset_spectrum_L<LEVEL>_grid<G>.png
using DelimitedFiles, Statistics, Printf, LinearAlgebra, CairoMakie
tag = length(ARGS) >= 1 ? ARGS[1] : "talltable"
LEVEL, G = length(ARGS) >= 3 ? parse.(Int, ARGS[2:3]) : (6, 1); bmin = length(ARGS) >= 4 ? parse(Float64, ARGS[4]) : 15.0
D = joinpath(@__DIR__, "..", "data", "spherex_real")
function fit(X, y)
    c = X \ y; r = y .- X * c; s = sqrt(sum(abs2, r) / (length(y) - size(X, 2)))
    c, s .* sqrt.(diag(inv(X' * X))), s, 1 - sum(abs2, r) / sum(abs2, y .- mean(y))
end
files = filter(f -> occursin(Regex("^ttbin_L$(LEVEL)_grid$(G)(_w[0-9.]+)?_offsets\\.csv\$"), f), readdir(D))
rows = []
for f in files
    wtag = replace(f, "ttbin_L$(LEVEL)_grid$(G)" => "", "_offsets.csv" => "")
    A, h = readdlm(joinpath(D, f), ',', header=true); col(c) = Float64.(A[:, findfirst(==(c), vec(h))])
    b1, ours, bgal, β, bsp, a = col("b1"), col("ours_med"), col("b"), col("β"), col("b1_spheres"), col("a")
    lam = isempty(wtag) ? 4.95 : parse(Float64, wtag[3:end]) + 0.05
    k = abs.(bgal) .> bmin; csc = 1 ./ sind.(abs.(bgal[k]))
    @printf("\n%s (%.2f μm): %d of %d patches with |b| > %.0f°; offset %.3f–%.3f MJy/sr (median %.3f); per-patch time-fit scale a: median %.3f\n",
            isempty(wtag) ? "4.9–5.1 μm" : wtag, lam, sum(k), length(k), bmin, extrema(b1[k])..., median(b1[k]), median(filter(!isnan, a[k])))
    res = Dict()
    for (key, X) in (("ours", [ones(sum(k)) ours[k]]), ("ours+gal", [ones(sum(k)) ours[k] csc]), ("gal", [ones(sum(k)) csc]))
        c, se, s, R2 = fit(X, b1[k]); res[key] = (c, se, s, R2)
        @printf("  c0 + %-14s coefficients %s ± %s; rms left %.4f MJy/sr; R² %.2f\n", key, join((@sprintf("%.4f", x) for x in c), ", "),
                join((@sprintf("%.4f", x) for x in se), ", "), s, R2)
    end
    cs, ses, ss, R2s = fit([ones(sum(k)) ours[k]], bsp[k])
    @printf("  SPHEREx zodi model instead of ours: c0 %.4f ± %.4f, c1 %.4f ± %.4f, rms %.4f, R² %.2f\n", cs[1], ses[1], cs[2], ses[2], ss, R2s)
    @printf("  correlation of the offset with |β| %+.2f, with csc|b| %+.2f, with ours %+.2f\n", cor(b1[k], abs.(β[k])), cor(b1[k], csc), cor(b1[k], ours[k]))
    c, se, s, R2 = res["ours"]
    push!(rows, (; window=isempty(wtag) ? "4.9-5.1" : wtag[3:end], lam, n=sum(k), ours_med=median(ours[k]), offset_med=median(b1[k]),
                  c0=c[1], c0_err=se[1], c1=c[2], c1_err=se[2], rms=s, R2, a_med=median(filter(!isnan, a[k])),
                  c0_g=res["ours+gal"][1][1], c1_g=res["ours+gal"][1][2], c1_g_err=res["ours+gal"][2][2],
                  c2_gal=res["ours+gal"][1][3], c2_err=res["ours+gal"][2][3], R2_g=res["ours+gal"][4],
                  spherex_c0=cs[1], spherex_c1=cs[2]))
end
sort!(rows, by=r -> r.lam)
open(joinpath(D, "ttbin_L$(LEVEL)_grid$(G)_offset_fit.csv"), "w") do f
    println(f, join(keys(rows[1]), ","))
    for r in rows; println(f, join((v isa AbstractFloat ? @sprintf("%.5g", v) : string(v) for v in values(r)), ",")); end
end
if length(rows) > 1
    get(s) = [getfield(r, s) for r in rows]; lam = get(:lam)
    set_theme!(merge(Theme(fontsize=18), theme_black()))
    fig = Figure(size=(1800, 650))
    ax1 = Axis(fig[1, 1], xlabel="wavelength (μm)", ylabel="c1", title="proportional part: measured ≈ (1 + c1)·Kelsall")
    errorbars!(ax1, lam, get(:c1), get(:c1_err), color=:white); scatterlines!(ax1, lam, get(:c1), color=:white, label="vs our model (= Kelsall)")
    errorbars!(ax1, lam .+ 0.04, get(:c1_g), get(:c1_g_err), color=:deepskyblue)
    scatterlines!(ax1, lam .+ 0.04, get(:c1_g), color=:deepskyblue, label="vs our model, fit with a Galactic csc|b| term")
    scatterlines!(ax1, lam, get(:spherex_c1), color=:orange, label="vs SPHEREx zodi model"); hlines!(ax1, [0], color=(:grey, 0.6))
    ylims!(ax1, minimum(get(:spherex_c1)) - 0.03, 1.7maximum(get(:c1_g) .+ get(:c1_g_err)))   # room for the legend above the data
    axislegend(ax1, position=:lt)
    ax2 = Axis(fig[1, 2], xlabel="wavelength (μm)", ylabel="MJy/sr", title="constant part c0 (and the median offset)")
    errorbars!(ax2, lam, get(:c0), get(:c0_err), color=:white); scatterlines!(ax2, lam, get(:c0), color=:white, label="c0 vs our model")
    scatterlines!(ax2, lam, get(:spherex_c0), color=:orange, label="c0 vs SPHEREx zodi model")
    scatterlines!(ax2, lam, get(:offset_med), color=:magenta, linestyle=:dash, label="median offset (measured − ours)")
    hlines!(ax2, [0], color=(:grey, 0.6)); axislegend(ax2, position=:lt)
    ax3 = Axis(fig[1, 3], xlabel="wavelength (μm)", ylabel="MJy/sr", title="median brightness over the patches")
    scatterlines!(ax3, lam, get(:ours_med), color=:white, label="our model (= Kelsall)"); axislegend(ax3, position=:lt)
    Label(fig[0, 1:3], @sprintf("Tall table, %d patches with |b| > %.0f°: offset = c0 + c1·Kelsall at each wavelength", rows[1].n, bmin), font=:bold, fontsize=21)
    save(joinpath(@__DIR__, "..", "figures", "$(tag)_offset_spectrum_L$(LEVEL)_grid$(G).png"), fig, px_per_unit=1.5)
end
println("ok")
