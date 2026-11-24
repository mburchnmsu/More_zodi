# Week 15 task 6 report: the change-only geometric network (sweeps/train_change.jl, Colibrí job 1274) against SPHEREx ZODI.
# Needs sweeps/results_change/*.jls (all 20 runs) and the seed-42 *.test.f32, plus data/tt_change_train.* (to recover each
# test row's wavelength, which the test files do not carry: the test rows are, in table order, the test visits of the
# cells with ≥ 3 training visits, exactly as train_change.jl selects them).
#   julia --project=. sweeps/report_change.jl   → figures/11232026_task6_{folds,maps,lambda}.png + printed summary
using Serialization, Statistics, Printf, CairoMakie, Flux
const R = normpath(joinpath(@__DIR__, "..")); RD = joinpath(R, "sweeps", "results_change"); D = joinpath(R, "data")
rrms(v) = (w = filter(isfinite, v); length(w) < 20 ? NaN : 1.4826 * median(abs.(w .- median(w))))

# 1. per-run table
runs = [deserialize(joinpath(RD, f)) for f in sort(readdir(RD)) if endswith(f, ".jls")]
println("arm fold seed   net      ZODI     none     closer")
for r in sort(runs, by=r -> (r.arm, r.fold, r.seed))
    @printf("%s   %d    %d   %.5f  %.5f  %.5f  %.1f%%\n", r.arm, r.fold, r.seed, r.rms_net, r.rms_zodi, r.rms_none, 100r.beat)
end
for a in ("A", "B")
    rs = filter(r -> r.arm == a, runs)
    @printf("arm %s: %d runs, net/ZODI %.3f (range %.3f–%.3f), closer on %.1f%% (%.1f–%.1f)\n", a, length(rs),
            mean(r.rms_net / r.rms_zodi for r in rs), extrema(r.rms_net / r.rms_zodi for r in rs)...,
            100mean(r.beat for r in rs), 100 .* extrema(r.beat for r in rs)...)
end

# 2. pooled test rows over the 5 folds (seed 42; each visit is a test row in exactly one fold)
cols = filter(!isempty, readlines(joinpath(D, "tt_change_train.cols"))); nc = length(cols)
M = permutedims(reshape(reinterpret(Float32, read(joinpath(D, "tt_change_train.f32"))), nc, :))
cell = collect(reinterpret(Int64, read(joinpath(D, "tt_change_train.cell"))))
col(n) = Float64.(M[:, findfirst(==(n), cols)])
t, lam = col("t_mid"), col("lam")
blk = floor.(Int, (t .- minimum(t)) ./ 30.0)
starts = [1; findall(diff(cell) .!= 0) .+ 1]; stops = [starts[2:end] .- 1; length(cell)]
P = Dict(k => Float64[] for k in (:t, :lam, :rB, :rA, :rZ, :elat, :elon))
for f in 0:4
    istest = blk .% 5 .== f
    k = reduce(vcat, [collect(a:b)[istest[a:b]] for (a, b) in zip(starts, stops) if count(.!istest[a:b]) >= 3])
    tb = [reshape(reinterpret(Float32, read(joinpath(RD, "chg_$(a)_f$(f)_s42_e300.test.f32"))), 8, :) for a in ("B", "A")]
    @assert size(tb[1], 2) == size(tb[2], 2) == length(k) "fold $f: $(size(tb[1], 2)) test rows vs $(length(k)) selected"
    @assert maximum(abs.(tb[1][1, :] .- t[k])) < 1e-3
    append!(P[:t], t[k]); append!(P[:lam], lam[k]); append!(P[:rB], tb[1][3, :]); append!(P[:rA], tb[2][3, :])
    append!(P[:rZ], tb[1][4, :]); append!(P[:elat], tb[1][6, :]); append!(P[:elon], tb[1][7, :])
end
rB, rA, rZ = P[:rB], P[:rA], P[:rZ]
@printf("pooled %d test visits: robust rms B %.5f, A %.5f, ZODI %.5f; B closer than ZODI on %.1f%%\n",
        length(rB), rrms(rB), rrms(rA), rrms(rZ), 100mean(abs.(rB) .< abs.(rZ)))

# 3. figure: per fold
fig = Figure(size=(900, 420))
ax = Axis(fig[1, 1], xlabel="held-out fold (30-day blocks, index mod 5)", ylabel="robust rms of the change residual (MJy/sr)",
          title="Task 6: change-only network vs SPHEREx ZODI, held-out visits")
for (a, c, m, o) in (("A", :gray50, :circle, -0.12), ("B", :firebrick, :diamond, 0.12))
    rs = filter(r -> r.arm == a, runs)
    scatter!(ax, [r.fold + o for r in rs], [r.rms_net for r in rs], color=c, marker=m, markersize=12,
             label=a == "A" ? "arm A: n·S, n·z, S·z, S·S" : "arm B: A + n·v, S·v, z·v")
end
z = sort(unique([(r.fold, r.rms_zodi) for r in runs]))
scatter!(ax, first.(z), last.(z), color=:royalblue, marker=:hline, markersize=28, label="SPHEREx ZODI")
ylims!(ax, 0, nothing); axislegend(ax, position=:rt)
save(joinpath(R, "figures", "11232026_task6_folds.png"), fig, px_per_unit=1.5)

# 4. figure: sky maps (ecliptic, 6° bins)
eb, lb = -90:6:90, 0:6:360
function binmap(fun)
    G = fill(NaN, length(lb) - 1, length(eb) - 1)
    il = clamp.(floor.(Int, P[:elon] ./ 6) .+ 1, 1, length(lb) - 1); ib = clamp.(floor.(Int, (P[:elat] .+ 90) ./ 6) .+ 1, 1, length(eb) - 1)
    idx = Dict{Tuple{Int,Int},Vector{Int}}()
    for i in eachindex(il); push!(get!(idx, (il[i], ib[i]), Int[]), i); end
    for ((i, j), v) in idx; length(v) >= 50 && (G[i, j] = fun(v)); end
    G
end
GB, GZ = binmap(v -> rrms(rB[v])), binmap(v -> rrms(rZ[v]))
GW = binmap(v -> mean(abs.(rB[v]) .< abs.(rZ[v])))
fig = Figure(size=(1300, 820))
lc, bc = collect(lb[1:end-1] .+ 3), collect(eb[1:end-1] .+ 3)
for (k, (G, ttl, cm, cr)) in enumerate(((GB, "arm B: robust rms (MJy/sr)", :viridis, (0, 0.03)),
                                        (GZ, "SPHEREx ZODI: robust rms (MJy/sr)", :viridis, (0, 0.03)),
                                        (log2.(GB ./ GZ), "log₂(arm B / ZODI): blue = network better", :RdBu, (1, -1)),
                                        (GW, "fraction of visits where arm B is closer", :RdBu, (0.2, 0.8))))
    local ax = Axis(fig[(k - 1) ÷ 2 + 1, 2((k - 1) % 2) + 1], title=ttl, xlabel="ecliptic longitude (°)", ylabel="ecliptic latitude (°)",
              xreversed=true, aspect=DataAspect())
    cmap = cr[1] > cr[2] ? Reverse(cm) : cm
    hm = heatmap!(ax, lc, bc, G, colormap=cmap, colorrange=(min(cr...), max(cr...)), nan_color=:white)
    Colorbar(fig[(k - 1) ÷ 2 + 1, 2((k - 1) % 2) + 2], hm)
end
save(joinpath(R, "figures", "11232026_task6_maps.png"), fig, px_per_unit=1.2)
@printf("6° bins with ≥ 50 visits: arm B better (lower rms) in %.1f%% of bins; B closer on > 50%% of visits in %.1f%%\n",
        100mean(filter(isfinite, GB) .< filter(isfinite, GZ)), 100mean(filter(isfinite, GW) .> 0.5))

# 5. figure: residual vs wavelength and vs time (checks the single (5/λ)^6.1 scaling and the time blocks)
fig = Figure(size=(1200, 440))
for (k, (x, xl, w)) in enumerate(((P[:lam], "median wavelength of the visit's pixels (μm)", 0.01),
                                  (P[:t], "time (MJD − 60000)", 10.0)))
    e = minimum(x):w:maximum(x) + w; xc = Float64[]; mb = Float64[]; mz = Float64[]; sb = Float64[]; sz = Float64[]
    for i in 1:length(e) - 1
        v = findall(e[i] .<= x .< e[i + 1]); length(v) < 200 && continue
        push!(xc, (e[i] + e[i + 1]) / 2); push!(mb, median(rB[v])); push!(mz, median(rZ[v])); push!(sb, rrms(rB[v])); push!(sz, rrms(rZ[v]))
    end
    local ax = Axis(fig[1, k], xlabel=xl, ylabel="change residual (MJy/sr)", title=k == 1 ? "residual vs wavelength" : "residual vs time")
    band!(ax, xc, mb .- sb, mb .+ sb, color=(:firebrick, 0.15)); lines!(ax, xc, mb, color=:firebrick, label="arm B median ± robust rms")
    lines!(ax, xc, mz, color=:royalblue, label="ZODI median"); lines!(ax, xc, mz .- sz, color=:royalblue, linestyle=:dash)
    lines!(ax, xc, mz .+ sz, color=:royalblue, linestyle=:dash, label="ZODI ± robust rms"); hlines!(ax, 0, color=:black, linewidth=0.5)
    k == 1 && axislegend(ax, position=:lb)
    k == 1 && @printf("vs λ (%.2f–%.2f μm): |median| arm B ≤ %.5f, ZODI ≤ %.5f; robust rms B %.5f–%.5f, ZODI %.5f–%.5f MJy/sr\n",
                      extrema(xc)..., maximum(abs.(mb)), maximum(abs.(mz)), extrema(sb)..., extrema(sz)...)
end
save(joinpath(R, "figures", "11232026_task6_lambda.png"), fig, px_per_unit=1.5)
println("wrote figures/11232026_task6_{folds,maps,lambda}.png")
