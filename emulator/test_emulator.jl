# Verify the packaged emulator: (1) exact reproduction, (2) headline metrics, (3) physical behaviour vs the
# Kelsall truth, (4) speed. Writes emulator/emulator_checks.png and prints PASS/WARN lines.
#   julia --project=.. test_emulator.jl
using LinearAlgebra; BLAS.set_num_threads(2)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))                 # data + truth (independent of the emulator)
include(joinpath(@__DIR__, "ZodiEmulator.jl")); using .ZodiEmulator
using Serialization, Healpix
check(ok, msg) = (println(ok ? "  PASS  " : "  WARN  ", msg); ok)

em = load_emulator(joinpath(@__DIR__, "zodi_emulator_v1.jld2")); println(em)
eph_all = (; S=spherex_positions, E=earth_positions, vS=v_spherex, vE=v_earth, J=jupiter_positions)

println("\n(1) reproduction")
p = predict_zodi(em, nvec_unit_cartesian, eph_all)
runs = [deserialize(joinpath(@__DIR__, "..", "sweeps", "results", "final_base_s$s.jls")) for s in 42:46]
ens  = vec(mean(reduce(hcat, [r.ypred for r in runs]), dims=2))
check(maximum(abs.(p.mean .- ens)) < 1e-5, @sprintf("emulator == saved ensemble on all %d exposures (max |Δ| = %.1e MJy/sr)", N, maximum(abs.(p.mean .- ens))))
cols = [findfirst(==(nm), dot_names_all) for nm in ZodiEmulator.FEATURES]
check(maximum(abs.(p.features' .- Fd_raw[:, cols])) < 1e-12, "module's own feature computation == notebook features")

println("\n(2) headline metrics")
tr, te = splits["80/20 Chronological"]
mse_te = mean(abs2, p.mean[te] .- y[te])
check(isapprox(mse_te, 9.40e-5; rtol=0.01), @sprintf("80/20 test MSE %.3e (expected 9.40e-5); median |frac err| %.2f%%", mse_te, 100median(abs.(p.mean[te] .- y[te]) ./ y[te])))
check(all(p.in_domain[tr]), "every training exposure is in-domain")
@printf("        test exposures in-domain: %.1f%%\n", 100mean(p.in_domain[te]))

println("\n(3) all-sky physics at epoch TINDX = 13170 (model vs Kelsall truth)")
TINDX = 13170
sky = h5open(allsky_file) do f
    (; truth=read(f["emission"]), lon=read(f["ecliptic_longitude_deg"]), lat=read(f["ecliptic_latitude_deg"]),
       pix=read(f["pixels"]) .+ 1)
end
nsky = vcat((cosd.(sky.lat) .* cosd.(sky.lon))', (cosd.(sky.lat) .* sind.(sky.lon))', sind.(sky.lat)')
eph1 = (; S=spherex_positions[:, TINDX], E=earth_positions[:, TINDX], vS=v_spherex[:, TINDX],
          vE=v_earth[:, TINDX], J=jupiter_positions[:, TINDX])
t_sky = @elapsed (q = predict_zodi(em, nsky, eph1))
ind = q.in_domain; res = q.mean .- sky.truth
Ŝ = eph1.S ./ norm(eph1.S); elong = acosd.(clamp.(-(nsky' * Ŝ), -1, 1))
v̂E = eph1.vE ./ norm(eph1.vE); lead = nsky' * v̂E                          # > 0: looking along Earth's motion
@printf("        in-domain %.1f%% of sky, rms %.4f MJy/sr, median |frac err| %.2f%%\n",
        100mean(ind), sqrt(mean(abs2, res[ind])), 100median(abs.(res[ind]) ./ sky.truth[ind]))
check(minimum(q.mean) > 0, @sprintf("positive everywhere on the sky (min %.3f MJy/sr; truth min %.3f)", minimum(q.mean), minimum(sky.truth)))

# (a) brightness vs |ecliptic latitude| (in-domain)
lat_edges = 0:10:90
latprof = [(m = ind .& (abs.(sky.lat) .>= lat_edges[i]) .& (abs.(sky.lat) .< lat_edges[i+1]);
            count(m) > 100 ? (median(q.mean[m]), median(sky.truth[m])) : (NaN, NaN)) for i in 1:9]
pm = first.(latprof); tm = last.(latprof); ok = .!isnan.(pm)
check(maximum(abs.(pm[ok] .- tm[ok]) ./ tm[ok]) < 0.03 && argmax(pm[ok]) == argmax(tm[ok]) == 1,
      "latitude profile matches truth to <3% per band, brightest at the ecliptic (model/truth MJy/sr per 10° |β| band):\n        " *
      join([@sprintf("%.2f/%.2f", a, b) for (a, b) in zip(pm[ok], tm[ok])], "  "))
band_el = [(m = ind .& (abs.(sky.lat) .>= lat_edges[i]) .& (abs.(sky.lat) .< lat_edges[i+1]); count(m) > 100 ? median(elong[m]) : NaN) for i in 1:9]
println("        median solar elongation of the in-domain pixels in each band: ",
        join([@sprintf("%.0f°", e) for e in band_el[ok]], "  "))
println("        → the rise above |β| ≈ 60° (in BOTH model and truth) tracks the in-domain pixels there being closer to the Sun")

# (b) brightness vs solar elongation near the ecliptic (|β| < 15°, in-domain)
el_edges = 85:5:130
elprof = [(m = ind .& (abs.(sky.lat) .< 15) .& (elong .>= el_edges[i]) .& (elong .< el_edges[i+1]);
           count(m) > 50 ? (median(q.mean[m]), median(sky.truth[m])) : (NaN, NaN)) for i in 1:length(el_edges)-1]
pe = first.(elprof); tе = last.(elprof); oke = .!isnan.(pe)
check(cor(pe[oke], tе[oke]) > 0.95 && sign(pe[oke][end] - pe[oke][1]) == sign(tе[oke][end] - tе[oke][1]),
      @sprintf("elongation trend near the ecliptic matches truth (corr %.3f): fainter further from the Sun", cor(pe[oke], tе[oke])))

# (c) north/south mirror symmetry: pair each in-domain pixel with its β → −β mirror
res_hp = Healpix.Resolution(Healpix.npix2nside(length(sky.pix)))
lookup = zeros(Int, length(sky.pix)); lookup[sky.pix] .= 1:length(sky.pix)
mirror = [lookup[Healpix.ang2pixRing(res_hp, deg2rad(90 + sky.lat[i]), deg2rad(mod(sky.lon[i], 360)))] for i in eachindex(sky.lat)]
pair = ind .& ind[mirror] .& (sky.lat .> 5)
dN(v) = ((v .- v[mirror]) ./ ((v .+ v[mirror]) ./ 2))[pair]          # signed (north − south) / mean
dm, dt = dN(q.mean), dN(sky.truth)
check(sign(mean(dm)) == sign(mean(dt)) && cor(dm, dt) > 0.7,
      @sprintf("north/south asymmetry (tilted cloud): same sign and pattern as truth — north brighter by %+.1f%% (model) vs %+.1f%% (truth),\n        pattern corr %.2f over %d in-domain mirror pairs; model reproduces about %.0f%% of the amplitude",
               100mean(dm), 100mean(dt), cor(dm, dt), count(pair), 100(dt \ dm)))
println("        (shortfall is largest above |β| 60° — consistent with n·* features only partly encoding Earth's\n" *
        "         orbital phase relative to the tilted cloud)")

# (d) leading vs trailing (Earth-trailing dust feature): compare at MATCHED elongation, near the ecliptic,
#     only in elongation bins where both sides are in-domain (the in-domain mask is lopsided at this epoch)
println("        trailing (n·v̂E < −0.5) vs leading (n·v̂E > 0.5), |β| < 10°, matched elongation:")
for (lo, hi) in ((95, 100), (100, 110))
    base = ind .& (abs.(sky.lat) .< 10) .& (elong .>= lo) .& (elong .< hi)
    mL = base .& (lead .> 0.5); mT = base .& (lead .< -0.5)
    ratio(v) = median(v[mT]) / median(v[mL]) - 1
    check(ratio(sky.truth) > 0 && ratio(q.mean) > 0 && abs(ratio(q.mean) - ratio(sky.truth)) < 0.01,
          @sprintf("elong %d–%d°: trailing side brighter — truth %+.2f%%, model %+.2f%% (%d/%d pixels)",
                   lo, hi, 100ratio(sky.truth), 100ratio(q.mean), count(mT), count(mL)))
end

# (e) out-of-domain flag toward the Sun
near_sun = elong .< 60
check(!any(ind[near_sun]), @sprintf("every pixel within 60° of the Sun is flagged out-of-domain (%d pixels; their median |frac err| %.0f%%)",
      count(near_sun), 100median(abs.(res[near_sun]) ./ sky.truth[near_sun])))

println("\n(4) time behaviour at the ecliptic poles (deep-field exposures, |β| > 80°)")
pole = abs.(ecliptic_latitude_deg) .> 80
for (nm, idx) in (("train", intersect(findall(pole), tr)), ("test", intersect(findall(pole), te)))
    @printf("        %-5s %6d exposures: corr(model, truth) %.4f, rms %.4f MJy/sr (truth varies %.3f–%.3f)\n",
            nm, length(idx), cor(p.mean[idx], y[idx]), sqrt(mean(abs2, p.mean[idx] .- y[idx])), extrema(y[idx])...)
end

println("\n(5) speed")
t_sky2 = @elapsed predict_zodi(em, nsky, eph1)           # second call: no compilation
t1 = @elapsed for _ in 1:1000; predict_zodi(em, nsky[:, 1:1], eph1); end
@printf("        full sky (%d directions × 5 networks, CPU): %.1f s (%.0f μs/direction)  |  single direction: %.0f μs\n",
        length(sky.pix), t_sky2, 1e6t_sky2 / length(sky.pix), 1e3t1)

# ---------- figure: physical profiles, model vs truth ----------
fig = Figure(size=(1300, 760), fontsize=13)
ax1 = Axis(fig[1, 1], xlabel="|ecliptic latitude| (°)", ylabel="median MJy/sr (in-domain)", title="Brightness vs latitude")
mids = collect(5:10:85)
scatterlines!(ax1, mids[ok], tm[ok], color=:white, label="Kelsall truth"); scatterlines!(ax1, mids[ok], pm[ok], color=:orangered, linestyle=:dash, label="emulator")
axislegend(ax1)
ax2 = Axis(fig[1, 2], xlabel="solar elongation (°)", ylabel="median MJy/sr (|β|<15°, in-domain)", title="Brightness vs elongation")
emids = collect(el_edges[1:end-1] .+ 2.5)
scatterlines!(ax2, emids[oke], tе[oke], color=:white); scatterlines!(ax2, emids[oke], pe[oke], color=:orangered, linestyle=:dash)
ax3 = Axis(fig[1, 3], xlabel="solar elongation (°)", ylabel="|pred − true| / true", yscale=log10,
           title="All-sky error vs elongation (blue = in-domain)")
sub = 1:13:length(sky.pix)
scatter!(ax3, elong[sub], max.(abs.(res[sub]) ./ sky.truth[sub], 1e-6), markersize=1.5, color=ifelse.(ind[sub], :deepskyblue, :orangered))
ax4 = Axis(fig[2, 1:3], xlabel="days since first exposure", ylabel="MJy/sr",
           title="Ecliptic-pole exposures (|β| > 80°) through the mission: truth (white) vs emulator (orange); dashed = end of training")
o = sortperm(t_rel[pole]); ip = findall(pole)[o]; sp = ip[1:7:end]
scatter!(ax4, t_rel[sp], y[sp], markersize=2, color=(:white, 0.6)); scatter!(ax4, t_rel[sp], p.mean[sp], markersize=1.5, color=(:orangered, 0.6))
vlines!(ax4, [maximum(t_rel[tr])], color=:gray70, linestyle=:dash)
save(joinpath(@__DIR__, "emulator_checks.png"), fig)
println("\nemulator checks done → emulator/emulator_checks.png")
