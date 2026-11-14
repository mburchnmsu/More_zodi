# Week 14 task 2: the real-sky residual maps (realdata/realsky2d.jl). Is the behind − ahead signal Earth's motion (v_e, the
# trailing cloud) or a seasonal effect leaking in (the ahead and behind views of a patch are ~6 months apart)?
# Per patch d = mean residual seen behind − seen ahead (% of ours). Fit across patches d = c0 + c1·cos λ + c2·sin λ:
#   c0 = the part that is the same at every ecliptic longitude (what a trailing cloud would give near the ecliptic);
#   (c1, c2) = a yearly term: behind and ahead fall in different seasons, and which season depends on λ.
# Variants: all exposures; without the 4.98–5.01 μm edge; without the NEP-burst dates (MJD 61145–61195); both cuts.
#     julia --project=. realdata/residual_leak.jl   → figures/11132026_residual_leak.png
using DelimitedFiles, Statistics, Printf, CairoMakie
D = joinpath(@__DIR__, "..", "data", "spherex_real")
O, ho = readdlm(joinpath(D, "ttbin_L6_grid2_offsets.csv"), ',', header=true); ho = vec(ho)
col(n) = findfirst(==(n), ho)
sunlon(mjd) = (d = mjd - 51544.5; g = deg2rad(mod(357.528 + 0.9856003d, 360)); mod(280.460 + 0.9856474d + 1.915sin(g) + 0.020sin(2g), 360))
cuts = [("all exposures", (w, t) -> trues(length(w))), ("no 4.98–5.01 μm edge", (w, t) -> w .< 4.98),
        ("no MJD 61145–61195", (w, t) -> .!(61145 .<= t .< 61195)), ("both cuts", (w, t) -> (w .< 4.98) .& .!(61145 .<= t .< 61195))]
function patches(cut)
    P = NamedTuple[]
    for i in axes(O, 1)
        abs(O[i, col("b")]) > 15 || continue
        f = joinpath(D, "ttbin_L6_$(O[i, 1])_ours.csv"); isfile(f) || continue
        T, h = readdlm(f, ',', header=true); h = vec(h); c(n) = Float64.(T[:, findfirst(==(n), h)])
        t, w, fl, zs, ou = c("t_mid_mjd"), c("wavelength"), c("flux_median"), c("zodi_spherex"), c("ours_lam")
        ok = isfinite.(fl) .& isfinite.(ou) .& isfinite.(zs) .& cut(w, t); sum(ok) >= 4 || continue
        t, fl, zs, ou = t[ok], fl[ok], zs[ok], ou[ok]
        λp, βp = Float64(O[i, col("λ")]), Float64(O[i, col("β")])
        φ = mod.(λp .- (sunlon.(t) .- 90), 360); bh = 90 .<= φ .< 270
        (any(bh) && any(.!bh)) || continue
        e(r) = 100 .* (r .- median(r)) ./ ou
        ba(x) = mean(x[bh]) - mean(x[.!bh])
        e1, e2, e3 = e(fl .- ou), e(fl .- zs), e(zs .- ou)
        # scale-corrected: Kelsall is ~18% too faint (offset fit 0.036 + 0.181·ours) and SPHEREx's zodi ≈ 1.165 × Kelsall;
        # a median-subtracted additive residual turns that scale error into a fake behind − ahead signal
        push!(P, (λ=λp, β=βp, d1=ba(e1), d2=ba(e2), d3=ba(e3), dk=ba(e(ou)), dm=ba(e(fl)),
                  d4=ba(e(fl .- 1.181 .* ou)), d5=ba(e(zs .- 1.165 .* ou)), m1=mean(e1), tb=mean(t[bh]) - mean(t[.!bh])))
    end
    P
end
function fitλ(P, key, k)
    d = [getfield(p, key) for p in P][k]; λ = [p.λ for p in P][k]
    A = [ones(length(d)) cosd.(λ) sind.(λ)]; c = A \ d; r = d .- A * c
    se = sqrt.(diag(inv(A' * A)) .* sum(abs2, r) / (length(d) - 3))
    (c=c, se=se, amp=hypot(c[2], c[3]), ph=mod(atand(c[3], c[2]), 360), n=length(d), med=median(d))
end
using LinearAlgebra
res = Dict()
for (lbl, cut) in cuts
    P = patches(cut); res[lbl] = P
    @printf("\n%s: %d patches seen both behind and ahead; mean of the median-subtracted residual %+.3f%%\n", lbl, length(P), mean(p.m1 for p in P))
    for (kl, kf) in (("|β| < 30°", p -> abs(p.β) < 30), ("|β| ≥ 30°", p -> abs(p.β) >= 30))
        k = [kf(p) for p in P]
        for (key, nm) in ((:d1, "measured − ours"), (:d2, "measured − SPHEREx"), (:d3, "SPHEREx − ours"),
                          (:dk, "ours (= Kelsall)"), (:dm, "measured"),
                          (:d4, "measured − 1.181·ours"), (:d5, "SPHEREx − 1.165·ours"))
            f = fitλ(P, key, k)
            @printf("  %-9s %-19s n %3d  median %+.2f%%  c0 %+.2f ± %.2f%%  yearly amp %.2f%% (peak at λ %3.0f°)", kl, nm, f.n, f.med, f.c[1], f.se[1], f.amp, f.ph)
            # a slow drift in time would also give a constant: behind is seen before or after ahead by tb days, depending on λ
            d = [getfield(p, key) for p in P][k]; λ = [p.λ for p in P][k]; tb = [p.tb for p in P][k]
            A = [ones(length(d)) cosd.(λ) sind.(λ) tb ./ 100]; c = A \ d
            @printf("  | + drift: c0 %+.2f%%, drift %+.2f%% per 100 d\n", c[1], c[4])
        end
    end
end

# The leak: near the ecliptic SPHEREx sees "behind" at larger solar elongation than "ahead", so behind − ahead mixes Earth's
# motion with elongation. Compare at MATCHED elongation: per exposure (|β| < 30°), residual minus its patch median, in 5° bins.
EL = Float64[]; BH = Bool[]; E1 = Float64[]; E2 = Float64[]; E3 = Float64[]; E4 = Float64[]
for i in axes(O, 1)
    abs(O[i, col("b")]) > 15 || continue
    βp = Float64(O[i, col("β")]); abs(βp) < 30 || continue
    f = joinpath(D, "ttbin_L6_$(O[i, 1])_ours.csv"); isfile(f) || continue
    T, h = readdlm(f, ',', header=true); h = vec(h); c(n) = Float64.(T[:, findfirst(==(n), h)])
    t, fl, zs, ou = c("t_mid_mjd"), c("flux_median"), c("zodi_spherex"), c("ours_lam")
    ok = isfinite.(fl) .& isfinite.(ou) .& isfinite.(zs); sum(ok) >= 4 || continue
    t, fl, zs, ou = t[ok], fl[ok], zs[ok], ou[ok]
    λp = Float64(O[i, col("λ")]); ls = sunlon.(t)
    append!(EL, acosd.(clamp.(cosd(βp) .* cosd.(λp .- ls), -1, 1))); append!(BH, 90 .<= mod.(λp .- (ls .- 90), 360) .< 270)
    e(r) = 100 .* (r .- median(r)) ./ ou
    append!(E1, e(fl .- ou)); append!(E2, e(fl .- zs)); append!(E3, e(zs .- ou)); append!(E4, e(fl .- 1.181 .* ou))
end
@printf("\n|β| < 30°: solar elongation behind median %.1f°, ahead median %.1f°\n", median(EL[BH]), median(EL[.!BH]))
bins = 87.5:5:122.5; mid = collect(bins[1:end-1]) .+ 2.5
binmean(E, k) = [(kk = k .& (a .<= EL .< a + 5); sum(kk) >= 20 ? mean(E[kk]) : NaN) for a in bins[1:end-1]]
println("matched elongation, behind − ahead (% of ours), bins with ≥ 20 exposures on both sides:")
for (E, nm) in ((E1, "measured − ours"), (E2, "measured − SPHEREx"), (E3, "SPHEREx − ours"), (E4, "measured − 1.181·ours"))
    b, a = binmean(E, BH), binmean(E, .!BH); d = b .- a; ok = isfinite.(d)
    nb = [sum(BH .& (x .<= EL .< x + 5)) for x in bins[1:end-1]]; na = [sum(.!BH .& (x .<= EL .< x + 5)) for x in bins[1:end-1]]
    w = (nb .* na ./ (nb .+ na))[ok]
    @printf("  %-19s %s | weighted mean %+.2f%%\n", nm, join([@sprintf("%.0f°: %+.2f", m, x) for (m, x) in zip(mid[ok], d[ok])], ", "), sum(w .* d[ok]) / sum(w))
end

# joint fit per exposure (|β| < 30°, patch medians already removed): residual = v·[behind] + s·(elongation − 95°)/10 + season
LSx = Float64[]
for i in axes(O, 1)
    abs(O[i, col("b")]) > 15 || continue
    abs(Float64(O[i, col("β")])) < 30 || continue
    f = joinpath(D, "ttbin_L6_$(O[i, 1])_ours.csv"); isfile(f) || continue
    T, h = readdlm(f, ',', header=true); h = vec(h); c(n) = Float64.(T[:, findfirst(==(n), h)])
    ok = isfinite.(c("flux_median")) .& isfinite.(c("ours_lam")) .& isfinite.(c("zodi_spherex")); sum(ok) >= 4 || continue
    append!(LSx, sunlon.(c("t_mid_mjd")[ok]))
end
@assert length(LSx) == length(EL)
println("joint fit per exposure, |β| < 30°: residual = const + v·behind + s·(elong − 95°)/10° + a·cos λsun + b·sin λsun")
for (E, nm) in ((E1, "measured − ours"), (E2, "measured − SPHEREx"), (E3, "SPHEREx − ours"), (E4, "measured − 1.181·ours"))
    A = [ones(length(E)) Float64.(BH) (EL .- 95) ./ 10 cosd.(LSx) sind.(LSx)]; cf = A \ E; r = E .- A * cf
    se = sqrt.(diag(inv(A' * A)) .* sum(abs2, r) / (length(E) - 5))
    @printf("  %-22s v (behind) %+.2f ± %.2f%%   s (per 10° elongation) %+.2f ± %.2f%%   season amp %.2f%%\n", nm, cf[2], se[2], cf[3], se[3], hypot(cf[4], cf[5]))
end

P = res["all exposures"]
set_theme!(merge(Theme(fontsize=18), theme_black()))
fig = Figure(size=(2300, 650))
ax = Axis(fig[1, 3], xlabel="solar elongation (°)", ylabel="exposures (|β| < 30°)", title="Where behind and ahead are seen")
hist!(ax, EL[BH], bins=86:2:132, color=(:orange, 0.6), label="behind Earth"); hist!(ax, EL[.!BH], bins=86:2:132, color=(:deepskyblue, 0.6), label="ahead of Earth")
axislegend(ax, position=:rt)
ax = Axis(fig[1, 4], xlabel="solar elongation (°)", ylabel="measured − our model, minus patch median (%)", title="Matched elongation (|β| < 30°)")
for (k, cl, lb) in ((BH, :orange, "behind Earth"), (.!BH, :deepskyblue, "ahead of Earth"))
    y = binmean(E1, k); ok = isfinite.(y); scatterlines!(ax, mid[ok], y[ok], color=cl, markersize=12, label=lb)
end
hlines!(ax, [0], color=(:grey, 0.6)); axislegend(ax, position=:lb)
for (j, (key, nm)) in enumerate(((:d1, "measured − our model"), (:d4, "measured − 1.181 × our model (scale fixed first)")))
    ax = Axis(fig[1, j], xlabel="patch ecliptic longitude λ (°)", ylabel="behind − ahead (% of our model)", title=nm, xticks=0:90:360)
    for (k, cl, lb) in ((p -> abs(p.β) < 30, :orange, "|β| < 30°"), (p -> abs(p.β) >= 30, :deepskyblue, "|β| ≥ 30°"))
        kk = [k(p) for p in P]; scatter!(ax, [p.λ for p in P][kk], [getfield(p, key) for p in P][kk], color=cl, markersize=11, label=lb)
        f = fitλ(P, key, kk); xx = 0:2:360
        lines!(ax, xx, f.c[1] .+ f.c[2] .* cosd.(xx) .+ f.c[3] .* sind.(xx), color=cl, linewidth=2)
    end
    hlines!(ax, [0], color=(:grey, 0.6)); axislegend(ax, position=:rb)
end
save(joinpath(@__DIR__, "..", "figures", "11132026_residual_leak.png"), fig, px_per_unit=1.5)
println("ok")
