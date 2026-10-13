using LinearAlgebra; BLAS.set_num_threads(4)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
include(joinpath(@__DIR__, "ZodiEmulator.jl")); using .ZodiEmulator
using Healpix
em = load_emulator(joinpath(@__DIR__, "zodi_emulator_v1.jld2"))
TINDX = 13170
sky = h5open(allsky_file) do f
    (; truth=read(f["emission"]), lon=read(f["ecliptic_longitude_deg"]), lat=read(f["ecliptic_latitude_deg"]),
       pix=read(f["pixels"]) .+ 1, trail=read(f["emission_earth_trailing_feature"]), ring=read(f["emission_circum_solar_ring"]),
       smooth=read(f["emission_smooth_cloud"]))
end
nsky = vcat((cosd.(sky.lat) .* cosd.(sky.lon))', (cosd.(sky.lat) .* sind.(sky.lon))', sind.(sky.lat)')
eph1 = (; S=spherex_positions[:, TINDX], E=earth_positions[:, TINDX], vS=v_spherex[:, TINDX], vE=v_earth[:, TINDX], J=jupiter_positions[:, TINDX])
q = predict_zodi(em, nsky, eph1); ind = q.in_domain
t2 = @elapsed predict_zodi(em, nsky, eph1)
@printf("full-sky timing after warm-up: %.2f s for %d directions × 5 networks (%.1f μs/direction)\n", t2, size(nsky, 2), 1e6t2 / size(nsky, 2))

# --- N/S asymmetry pattern ---
res_hp = Healpix.Resolution(Healpix.npix2nside(length(sky.pix)))
lookup = zeros(Int, length(sky.pix)); lookup[sky.pix] .= 1:length(sky.pix)
mirror = [lookup[Healpix.ang2pixRing(res_hp, deg2rad(90 + sky.lat[i]), deg2rad(mod(sky.lon[i], 360)))] for i in eachindex(sky.lat)]
pair = ind .& ind[mirror] .& (sky.lat .> 5)
dN(v) = ((v .- v[mirror]) ./ ((v .+ v[mirror]) ./ 2))[pair]           # signed (north − south)/mean
dm, dt = dN(q.mean), dN(sky.truth)
b = dm \ dt
@printf("\nN/S asymmetry pattern: corr(model, truth) = %.3f ; truth ≈ %.2f × model ; mean signed: model %+.2f%%, truth %+.2f%%\n",
        cor(dm, dt), dt \ dm, 100mean(dm), 100mean(dt))
@printf("  observer height above ecliptic at TINDX: S·z = %.2e AU (Earth: %.2e AU)\n", spherex_positions[3, TINDX], earth_positions[3, TINDX])
for (lo, hi) in ((5, 20), (20, 40), (40, 60), (60, 85))
    m = (sky.lat[pair] .>= lo) .& (sky.lat[pair] .< hi)
    @printf("  |β| %2d–%2d°: median |N−S|/mean  model %.2f%%  truth %.2f%%  (n=%d)\n", lo, hi, 100median(abs.(dm[m])), 100median(abs.(dt[m])), count(m))
end
# same check on the TRAINING exposures themselves (no mask issues): mirror exposures don't exist, so
# instead compare residual vs ecliptic latitude sign
tr, te = splits["80/20 Chronological"]
p = predict_zodi(em, nvec_unit_cartesian[:, tr], (; S=spherex_positions[:, tr], E=earth_positions[:, tr],
                 vS=v_spherex[:, tr], vE=v_earth[:, tr], J=jupiter_positions[:, tr]))
r = p.mean .- y[tr]; β = ecliptic_latitude_deg[tr]
@printf("  training exposures: median residual north (β>20) %+.4f, south (β<−20) %+.4f MJy/sr (bias ≈ 0 → asymmetry learned where observed)\n",
        median(r[β .> 20]), median(r[β .< -20]))

# --- leading vs trailing at matched elongation ---
Ŝ = eph1.S ./ norm(eph1.S); elong = acosd.(clamp.(-(nsky' * Ŝ), -1, 1))
lead = nsky' * (eph1.vE ./ norm(eph1.vE))
println("\nleading (n·v̂E > 0.5) vs trailing (n·v̂E < −0.5), |β| < 10°, matched elongation bins:")
println("  elong   n_lead n_trail | truth T/L−1   model T/L−1 | Earth-trailing comp. T vs L (MJy/sr)")
for (lo, hi) in ((85, 90), (90, 95), (95, 100), (100, 110), (110, 120))
    base = (abs.(sky.lat) .< 10) .& (elong .>= lo) .& (elong .< hi)
    mL = base .& (lead .> 0.5); mT = base .& (lead .< -0.5)
    mLi = mL .& ind; mTi = mT .& ind
    cmp(v, a, c) = count(a) > 20 && count(c) > 20 ? @sprintf("%+6.2f%%", 100(median(v[c]) / median(v[a]) - 1)) : "   —   "
    @printf("  %3d–%3d  %5d  %5d  |  %s       %s     |  %.4f vs %.4f   (all pixels; in-domain lead/trail %d/%d)\n",
            lo, hi, count(mL), count(mT), cmp(sky.truth, mLi, mTi), cmp(q.mean, mLi, mTi),
            count(mT) > 0 ? median(sky.trail[mT]) : NaN, count(mL) > 0 ? median(sky.trail[mL]) : NaN, count(mLi), count(mTi))
end
@printf("  Earth-trailing component: max %.4f MJy/sr = %.2f%% of the median sky — a small feature at 5 μm\n",
        maximum(sky.trail), 100maximum(sky.trail) / median(sky.truth))
# where is the trailing blob brightest? (should be near the ecliptic, behind Earth: n·v̂E < 0)
k = argmax(sky.trail)
@printf("  brightest trailing-feature pixel: β = %.1f°, elongation %.1f°, n·v̂E = %+.2f (negative = trailing side)\n", sky.lat[k], elong[k], lead[k])
