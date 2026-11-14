# Week 14 task 1: the jump near MJD 61,200 in the tall table. Per exposure (grid G level-6 patches, 4.9–5.1 μm), against time:
# measured / ours, SPHEREx zodi / ZodiPy, and (measured − SPHEREx zodi) / ours. A single step is fitted to each (best split
# time by least squares on log ratios, each patch's own median removed so the fixed sky drops out).
#     julia --project=. realdata/release_jump.jl [LEVEL G bmin]   → figures/11132026_release_jump_L<L>_grid<G>.png
using DelimitedFiles, Statistics, Printf, CairoMakie
LEVEL, G = length(ARGS) >= 2 ? parse.(Int, ARGS[1:2]) : (6, 2); bmin = length(ARGS) >= 3 ? parse(Float64, ARGS[3]) : 15.0
D = joinpath(@__DIR__, "..", "data", "spherex_real")
O, ho = readdlm(joinpath(D, "ttbin_L$(LEVEL)_grid$(G)_offsets.csv"), ',', header=true); ho = vec(ho)
col(n) = findfirst(==(n), ho)
t = Float64[]; pid = Int[]; img = Int[]; fl = Float64[]; zs = Float64[]; kp = Float64[]; ou = Float64[]
for i in axes(O, 1)
    abs(O[i, col("b")]) > bmin || continue
    f = joinpath(D, "ttbin_L$(LEVEL)_$(O[i, 1])_ours.csv"); isfile(f) || continue
    T, h = readdlm(f, ',', header=true); h = vec(h); c(n) = T[:, findfirst(==(n), h)]
    x = Float64.(c("flux_median")), Float64.(c("zodi_spherex")), Float64.(c("zodipy_lam")), Float64.(c("ours_lam"))
    ok = reduce(.&, (isfinite.(v) for v in x)); sum(ok) >= 4 || continue
    append!(t, Float64.(c("t_mid_mjd"))[ok]); append!(pid, fill(i, sum(ok))); append!(img, Int.(c("imageid"))[ok])
    append!(fl, x[1][ok]); append!(zs, x[2][ok]); append!(kp, x[3][ok]); append!(ou, x[4][ok])
end
@printf("%d exposures, %d patches with |b| > %g°, MJD %.1f – %.1f\n", length(t), length(unique(pid)), bmin, extrema(t)...)
"""log ratio minus each patch's median (in %)."""
function demed(r)
    out = similar(r)
    for p in unique(pid); k = pid .== p; out[k] = 100 .* (log.(r[k]) .- median(log.(r[k]))); end
    out
end
series = [("measured / ours", demed(fl ./ ou)), ("SPHEREx zodi / ZodiPy", demed(zs ./ kp)), ("(measured − SPHEREx zodi) / ours", 100 .* ((fl .- zs) ./ ou .- 0))]
# the last one is not a ratio: remove each patch's median directly
let r = series[3][2]; for p in unique(pid); k = pid .== p; r[k] .-= median(r[k]); end; end
"""Best single step: split time minimising the squared error of a two-level fit."""
function step(y)
    o = sortperm(t); ts, ys = t[o], y[o]; n = length(ys); cs = cumsum(ys); cq = cumsum(ys .^ 2)
    best = (Inf, 0)
    for k in 50:n-50
        ts[k] == ts[k+1] && continue
        s1 = cq[k] - cs[k]^2 / k; s2 = (cq[n] - cq[k]) - (cs[n] - cs[k])^2 / (n - k)
        s1 + s2 < best[1] && (best = (s1 + s2, k))
    end
    k = best[2]; tj = (ts[k] + ts[k+1]) / 2
    a = ys[1:k]; b = ys[k+1:end]
    (tj=tj, gap=(ts[k], ts[k+1]), before=median(a), after=median(b), n=(k, n - k))
end
for (lbl, y) in series
    s = step(y)
    @printf("%-34s step at MJD %.1f (last before %.2f, first after %.2f; %d / %d exposures): median %+.2f%% → %+.2f%% (jump %+.2f%%)\n",
            lbl, s.tj, s.gap..., s.n..., s.before, s.after, s.after - s.before)
end
# time gaps longer than 5 days (survey/release boundaries)
ts = sort(unique(t)); gaps = findall(diff(ts) .> 5)
println("gaps > 5 days: ", join([@sprintf("%.1f–%.1f (%.0f d)", ts[g], ts[g+1], ts[g+1] - ts[g]) for g in gaps], ", "))
# imageid looks like YYYYDDD...: report its prefix on each side of the main step
s = step(series[2][2]); pre = img[t .< s.tj]; post = img[t .> s.tj]
@printf("imageid range before: %d – %d; after: %d – %d\n", extrema(pre)..., extrema(post)...)

set_theme!(merge(Theme(fontsize=18), theme_black()))
fig = Figure(size=(1500, 1000))
for (r, (lbl, y)) in enumerate(series)
    ax = Axis(fig[r, 1], ylabel="%", title="$lbl, each patch minus its own median", xlabel=r == 3 ? "MJD" : "")
    scatter!(ax, t, y, markersize=3, color=(:white, 0.4))
    s = step(y); vlines!(ax, [s.tj], color=:orange, linestyle=:dash)
    text!(ax, s.tj + 3, s.after, text=@sprintf("step at MJD %.0f: %+.1f%%", s.tj, s.after - s.before), color=:orange, fontsize=17)
    ylims!(ax, quantile(y, 0.005) - 2, quantile(y, 0.995) + 2)
end
save(joinpath(@__DIR__, "..", "figures", "11132026_release_jump_L$(LEVEL)_grid$(G).png"), fig, px_per_unit=1.5)
println("ok")
