# How well do our model and SPHEREx's zodi model reproduce the tall table's measured sky at 4.9–5.1 μm? One summary table over the
# patches with |b| > bmin (grid G, level-6 patches), from the per-exposure files of realdata/talltable_offsetmap.jl.
#     julia --project=. realdata/repro_table.jl [LEVEL G bmin]   → prints the table and writes data/spherex_real/repro_table_L<L>_grid<G>.csv
using DelimitedFiles, Statistics, Printf
LEVEL, G = length(ARGS) >= 2 ? parse.(Int, ARGS[1:2]) : (6, 2); bmin = length(ARGS) >= 3 ? parse(Float64, ARGS[3]) : 15.0
D = joinpath(@__DIR__, "..", "data", "spherex_real")
O, ho = readdlm(joinpath(D, "ttbin_L$(LEVEL)_grid$(G)_offsets.csv"), ',', header=true); ho = vec(ho)
col(n) = findfirst(==(n), ho)
sunlon(mjd) = (d = mjd - 51544.5; g = deg2rad(mod(357.528 + 0.9856003d, 360)); mod(280.460 + 0.9856474d + 1.915sin(g) + 0.020sin(2g), 360))

fl_all, ou_all, zs_all, kp_all = Float64[], Float64[], Float64[], Float64[]
pm = NamedTuple[]                                        # per patch medians, time rms, seasonal range, behind − ahead
for i in axes(O, 1)
    abs(O[i, col("b")]) > bmin || continue
    f = joinpath(D, "ttbin_L$(LEVEL)_$(O[i, 1])_ours.csv"); isfile(f) || continue
    T, h = readdlm(f, ',', header=true); h = vec(h); c(n) = Float64.(T[:, findfirst(==(n), h)])
    t, fl, zs, ou, kp = c("t_mid_mjd"), c("flux_median"), c("zodi_spherex"), c("ours_lam"), c("zodipy_lam")
    ok = isfinite.(fl) .& isfinite.(ou) .& isfinite.(zs) .& isfinite.(kp); sum(ok) >= 4 || continue
    t, fl, zs, ou, kp = t[ok], fl[ok], zs[ok], ou[ok], kp[ok]
    append!(fl_all, fl); append!(ou_all, ou); append!(zs_all, zs); append!(kp_all, kp)
    dm(x) = x .- median(x)
    φ = mod.(Float64(O[i, col("λ")]) .- (sunlon.(t) .- 90), 360); bh = 90 .<= φ .< 270
    ba(r) = any(bh) && any(.!bh) ? mean(r[bh]) - mean(r[.!bh]) : NaN    # as realdata/realsky2d.jl: % of ours per exposure
    push!(pm, (fl=O[i, col("flux_med")], ou=O[i, col("ours_med")], o1=O[i, col("b1")], o2=O[i, col("b1_spheres")],
               tou=sqrt(mean(abs2, dm(fl .- ou))), tzs=sqrt(mean(abs2, dm(fl .- zs))),
               rfl=maximum(fl) - minimum(fl), rou=maximum(ou) - minimum(ou), rzs=maximum(zs) - minimum(zs),
               bou=ba(100 .* dm(fl .- ou) ./ ou), bzs=ba(100 .* dm(fl .- zs) ./ ou)))
end
g(k) = Float64[getfield(p, k) for p in pm]
fit(x, y) = [ones(length(x)) x] \ y
r2(x, y, p) = 1 - sum(abs2, y .- (p[1] .+ p[2] .* x)) / sum(abs2, y .- mean(y))
# per-patch medians and offsets exactly as the offsets table (and realdata/offset_scatter.jl) define them
fl, ou, o1, o2 = g(:fl), g(:ou), g(:o1), g(:o2); zs = fl .- o2
po, ps = fit(ou, o1), fit(zs, o2)
so = std(o1 .- (po[1] .+ po[2] .* ou)); ss = std(o2 .- (ps[1] .+ ps[2] .* zs))
# brightness range over time (max − min within each patch), model over measured, median across patches
rr(k) = median(g(k) ./ g(:rfl))
fin(v) = v[isfinite.(v)]
rows = [
 ("Median sky brightness (MJy/sr)", @sprintf("%.3f", median(fl)), @sprintf("%.3f", median(ou)), @sprintf("%.3f", median(zs))),
 ("Median model / measured", "1", @sprintf("%.3f", median(ou ./ fl)), @sprintf("%.3f", median(zs ./ fl))),
 ("Median offset, measured − model (MJy/sr)", "—", @sprintf("%.3f", median(o1)), @sprintf("%.3f", median(o2))),
 ("Offset fit across patches: c0 + c1·model", "—", @sprintf("%.3f + %.3f·model", po...), @sprintf("%.3f + %.3f·model", ps...)),
 ("  R² of that fit", "—", @sprintf("%.2f", r2(ou, o1, po)), @sprintf("%.2f", r2(zs, o2, ps))),
 ("Scatter left after the fit (MJy/sr)", "—", @sprintf("%.3f", so), @sprintf("%.3f", ss)),
 ("Brightness change within a patch, model / measured (median)", "1", @sprintf("%.2f", rr(:rou)), @sprintf("%.2f", rr(:rzs))),
 ("Time residual after each patch's median, rms (MJy/sr)", "—", @sprintf("%.4f", median(g(:tou))), @sprintf("%.4f", median(g(:tzs)))),
 ("Behind − ahead of Earth, per patch median (%)", "—", @sprintf("%+.2f", median(fin(g(:bou)))), @sprintf("%+.2f", median(fin(g(:bzs))))),
]
@printf("%d patches with |b| > %g°, %d exposures; our model vs ZodiPy (Kelsall): median |diff| %.3f%%\n", length(pm), bmin,
        length(fl_all), 100 * median(abs.(ou_all .- kp_all) ./ kp_all))
for r in rows; @printf("%-62s | %-10s | %-22s | %s\n", r...); end
open(joinpath(D, "repro_table_L$(LEVEL)_grid$(G).csv"), "w") do io
    println(io, "quantity,measured,ours,spherex_model"); for r in rows; println(io, join(("\"" * strip(x) * "\"" for x in r), ",")); end
end
