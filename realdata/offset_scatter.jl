# The 5 μm offset fit as a scatter: per patch (|b| > bmin), offset = median(measured − model) against the model's median, for our
# model (= Kelsall) and SPHEREx's zodi model, with straight-line fits. From the offsets table of realdata/talltable_offsetmap.jl.
#     julia --project=. realdata/offset_scatter.jl [tag [LEVEL G bmin]]   → figures/<tag>_offset_scatter_L<L>_grid<G>.png
using DelimitedFiles, Statistics, Printf, CairoMakie
tag = length(ARGS) >= 1 ? ARGS[1] : "offset"
LEVEL, G = length(ARGS) >= 3 ? parse.(Int, ARGS[2:3]) : (6, 2); bmin = length(ARGS) >= 4 ? parse(Float64, ARGS[4]) : 15.0
D = joinpath(@__DIR__, "..", "data", "spherex_real")
O, h = readdlm(joinpath(D, "ttbin_L$(LEVEL)_grid$(G)_offsets.csv"), ',', header=true); h = vec(h)
c(n) = Float64.(O[:, findfirst(==(n), h)])
k = abs.(c("b")) .> bmin
xo, yo = c("ours_med")[k], c("b1")[k]
xs, ys = (c("flux_med") .- c("b1_spheres"))[k], c("b1_spheres")[k]        # SPHEREx model's median ≈ measured − its offset
fit(x, y) = [ones(length(x)) x] \ y
r2(x, y, p) = 1 - sum(abs2, y .- (p[1] .+ p[2] .* x)) / sum(abs2, y .- mean(y))
po, ps = fit(xo, yo), fit(xs, ys)
@printf("%d patches: ours c0 %.4f c1 %.4f R² %.2f; SPHEREx c0 %.4f c1 %.4f R² %.2f\n", sum(k), po..., r2(xo, yo, po), ps..., r2(xs, ys, ps))
set_theme!(merge(Theme(fontsize=20), theme_black()))
fig = Figure(size=(1100, 750))
ax = Axis(fig[1, 1], xlabel="zodi model, median over the patch's exposures (MJy/sr)", ylabel="offset: measured − model (MJy/sr)",
          title="4.9–5.1 μm, $(sum(k)) patches with |b| > $(round(Int, bmin))°")
scatter!(ax, xo, yo, color=:white, markersize=10, label=@sprintf("our model (= Kelsall): %.3f + %.3f × model, R² %.2f", po..., r2(xo, yo, po)))
scatter!(ax, xs, ys, color=:orange, markersize=10, marker=:diamond, label=@sprintf("SPHEREx zodi model: %.3f + %.3f × model, R² %.2f", ps..., r2(xs, ys, ps)))
xx = range(0, maximum(vcat(xo, xs)) * 1.05, length=2)
lines!(ax, xx, po[1] .+ po[2] .* xx, color=:white); lines!(ax, xx, ps[1] .+ ps[2] .* xx, color=:orange)
hlines!(ax, [0], color=(:grey, 0.6)); ylims!(ax, -0.02, max(maximum(yo), maximum(ys)) * 1.35)
axislegend(ax, position=:lt, labelsize=17)
save(joinpath(@__DIR__, "..", "figures", "$(tag)_offset_scatter_L$(LEVEL)_grid$(G).png"), fig, px_per_unit=1.5)
println("ok")
