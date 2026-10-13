# Verification of pipeline/ZodiPipeline.jl on the simulated data → pipeline/pipeline_checks.log
#   julia --project=. pipeline/test_pipeline.jl > pipeline/pipeline_checks.log
using LinearAlgebra; BLAS.set_num_threads(2)
const ROOT = normpath(joinpath(@__DIR__, ".."))
include(joinpath(ROOT, "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl", "extra_splits.jl", "nb_verify_fns.jl", "summary_helpers.jl")
    include(joinpath(ROOT, "sweeps", f))
end
include(joinpath(ROOT, "pipeline", "ZodiPipeline.jl")); using .ZodiPipeline
ok(c) = c ? "PASS" : "FAIL"
results = Pair{String, Bool}[]
check(name, c) = (push!(results, name => c); println("[$(ok(c))] $name"))

println("\n=== 1. Exposure table from the simulated data ===")
tab = exposure_table(times, nvec_unit_cartesian, y)
println(tab); check("table validates (unit vectors, lengths, finite times)", length(tab) == N)

println("\n=== 2. Features reproduce the training features exactly ===")
geom = (; S=spherex_positions, E=earth_positions, vS=v_spherex, vE=v_earth, J=jupiter_positions)
F, names = build_features(nvec_unit_cartesian, geom)
for (j, nm) in enumerate(names)
    d = maximum(abs.(F[:, j] .- Fd_raw[:, findfirst(==(nm), dot_names_all)]))
    @printf("  %-11s max |pipeline − training| = %.1e\n", nm, d)
end
dmax = maximum(maximum(abs.(F[:, j] .- Fd_raw[:, findfirst(==(nm), dot_names_all)])) for (j, nm) in enumerate(names))
check("all $(length(names)) features identical to training (max diff $(@sprintf("%.1e", dmax)))", dmax < 1e-12)

println("\n=== 3. Coordinates ===")
lon, lat = ecliptic_lonlat(nvec_unit_cartesian)
dlon = maximum(abs.(mod.(lon .- ecliptic_longitude_deg .+ 180, 360) .- 180) .* cosd.(lat)); dlat = maximum(abs.(lat .- ecliptic_latitude_deg))
@printf("  ecliptic lon/lat from nvec vs the pointing file: max |Δlon·cosβ| = %.1e°, max |Δlat| = %.1e°\n", dlon, dlat)
check("ecliptic lon/lat match the pointing file (< 1e-6°)", max(dlon, dlat) < 1e-6)
ra, dec = ecliptic_to_radec(nvec_unit_cartesian); back = radec_to_ecliptic(ra, dec)
rt = maximum(abs.(back .- nvec_unit_cartesian)); @printf("  RA/Dec round trip: max |Δn| = %.1e\n", rt)
check("RA/Dec ↔ ecliptic round trip (< 1e-12)", rt < 1e-12)
nep = radec_to_ecliptic([270.0], [90 - ZodiPipeline.OBLIQUITY_J2000]); vern = radec_to_ecliptic([0.0], [0.0])
@printf("  north ecliptic pole (RA 270°, Dec 66.56°) → %s;  vernal equinox (0°, 0°) → %s\n", round.(vec(nep), digits=12), round.(vec(vern), digits=12))
check("NEP → +z and equinox → +x", isapprox(vec(nep), [0, 0, 1]; atol=1e-12) && isapprox(vec(vern), [1, 0, 0]; atol=1e-12))

println("\n=== 4. Ephemerides: Horizons-format files + Hermite interpolation ===")
o = sortperm(times); tj = times[o]
# velocity units in the simulated file: compare to finite differences of the positions
fd(P, k) = (P[:, o[k+1]] .- P[:, o[k]]) ./ (tj[k+1] - tj[k])
ks = [k for k in 1:1000:N-1 if 1e-4 < tj[k+1] - tj[k] < 0.01]
scaleE = median([norm(fd(earth_positions, k)) / norm(v_earth[:, o[k]]) for k in ks])
scaleS = median([norm(fd(spherex_positions, k)) / norm(v_spherex[:, o[k]]) for k in ks])
@printf("  file velocity → AU/day factor: Earth %.4f, SPHEREx %.4f (1 = already AU/day; 86400/AU_km = %.4e for km/s)\n",
        scaleE, scaleS, 86400 / ZodiPipeline.AU_KM)
function nodes(P, V, step)                       # pick the exposure nearest each grid time as a node
    g = tj[1]:step:tj[end]; idx = unique([o[clamp(searchsortedfirst(tj, t), 1, N)] for t in g])
    idx = idx[sortperm(times[idx])]
    Ephemeris("test", times[idx], P[:, idx], V === nothing ? zeros(3, length(idx)) : V[:, idx]), idx
end
tmpdir = mktempdir()
for (nm, P, V, sc, step) in (("Earth", earth_positions, v_earth, scaleE, 0.25), ("SPHEREx", spherex_positions, v_spherex, scaleS, 1 / 1440))
    eph, idx = nodes(P, V .* sc, step)
    f = write_horizons_vectors(joinpath(tmpdir, "$nm.txt"), Ephemeris(nm, eph.jd, eph.pos, eph.vel))
    e2 = read_horizons_vectors(f)
    rd = max(maximum(abs.(e2.pos .- eph.pos)), maximum(abs.(e2.vel .- eph.vel)))
    sel = filter(i -> e2.jd[1] <= times[i] <= e2.jd[end], 1:N)
    Pi, _ = interpolate_ephemeris(e2, times[sel])
    err = vec(sqrt.(sum(abs2, Pi .- P[:, sel], dims=1)))
    @printf("  %-8s %5d nodes every %.4g d; file round trip %.1e; interpolation error median %.2e AU (%.3f km), max %.2e AU (%.2f km)\n",
            nm, length(e2.jd), step, rd, median(err), median(err) * ZodiPipeline.AU_KM, maximum(err), maximum(err) * ZodiPipeline.AU_KM)
    nm == "Earth" && begin
        λi = mod.(atand.(Pi[2, :], Pi[1, :]), 360); dλ = maximum(abs.(mod.(λi .- λE_deg[sel] .+ 180, 360) .- 180))
        @printf("           Earth longitude λ⊕ error max %.1e°\n", dλ)
        check("Earth: 6-hourly Horizons table interpolates to < 100 km and λ⊕ < 1e-4°", maximum(err) * ZodiPipeline.AU_KM < 100 && dλ < 1e-4)
    end
    nm == "SPHEREx" && check("SPHEREx: 1-minute table interpolates to < 10 km", maximum(err) * ZodiPipeline.AU_KM < 10)
end
# Jupiter has no velocities in the simulated file → central differences at daily nodes (Horizons provides real ones)
let eph = first(nodes(jupiter_positions, nothing, 1.0))
    V = similar(eph.pos)
    for k in eachindex(eph.jd)
        a, b = max(k - 1, 1), min(k + 1, length(eph.jd)); V[:, k] = (eph.pos[:, b] .- eph.pos[:, a]) ./ (eph.jd[b] - eph.jd[a])
    end
    sel = filter(i -> eph.jd[1] <= times[i] <= eph.jd[end], 1:N)
    Pi, _ = interpolate_ephemeris(Ephemeris("Jupiter", eph.jd, eph.pos, V), times[sel])
    err = maximum(sqrt.(sum(abs2, Pi .- jupiter_positions[:, sel], dims=1)))
    @printf("  Jupiter  %5d daily nodes (finite-difference velocities): max error %.2e AU → max |Δ(n·J)| %.2e (n·J spans ±5)\n",
            length(eph.jd), err, err)
    check("Jupiter: daily table good to < 1e-5 AU", err < 1e-5)
end
try
    interpolate_ephemeris(Ephemeris("x", [0.0, 1.0], zeros(3, 2), zeros(3, 2)), [2.0]); check("out-of-range JD is refused", false)
catch; check("out-of-range JD is refused", true); end

println("\n=== 5. What if no SPHEREx ephemeris is available (S → E, vS → vE)? ===")
for (lbl, pref) in (("season model (n·* + sin/cos λ⊕), 30-day blocks", "se_blk_s"),)
    rs = load_prefix(pref); r1 = rs[1]; te = r1.te_idx
    geomE = (; S=earth_positions, E=earth_positions, vS=v_earth, vE=v_earth, J=jupiter_positions)
    function ens(g)
        Fg, nms = build_features(nvec_unit_cartesian[:, te], map(A -> A[:, te], g))
        cols = [findfirst(==(f), nms) for f in r1.feature_names]
        vec(mean(reduce(hcat, [Float64.(predict_y(r, Float32.(((Fg[:, cols] .- r.μ') ./ r.σ')'))) for r in rs]), dims=2))
    end
    p_ok, p_E = ens(geom), ens(geomE)
    fe(p) = 100 .* abs.(p .- y[te]) ./ y[te]
    p_Sonly = ens((; geom..., S=earth_positions)); p_vonly = ens((; geom..., vS=v_earth))
    @printf("    only S → E   (position, ≤ 5e-5 AU): median |err| %.4f%%, median |Δprediction| %.5f%%\n", median(fe(p_Sonly)), 100median(abs.(p_Sonly .- p_ok) ./ y[te]))
    @printf("    only vS → vE (velocity direction)  : median |err| %.4f%%, median |Δprediction| %.5f%%\n", median(fe(p_vonly)), 100median(abs.(p_vonly .- p_ok) ./ y[te]))
    @printf("  %s, %d members, %d test exposures\n", lbl, length(rs), length(te))
    @printf("    exact SPHEREx geometry : MSE %.3e, median |err| %.4f%%, p95 %.3f%%\n", mean(abs2, p_ok .- y[te]), median(fe(p_ok)), quantile(fe(p_ok), 0.95))
    @printf("    SPHEREx placed at Earth: MSE %.3e, median |err| %.4f%%, p95 %.3f%%   (median |Δprediction| %.4f%%)\n",
            mean(abs2, p_E .- y[te]), median(fe(p_E)), quantile(fe(p_E), 0.95), 100median(abs.(p_E .- p_ok) ./ y[te]))
    uc(A) = A ./ sqrt.(sum(abs2, A, dims=1))
    dvs = acosd.(clamp.(vec(sum(uc(v_spherex[:, te]) .* uc(v_earth[:, te]), dims=1)), -1, 1))
    @printf("    (v̂S vs v̂E differ by %.1f–%.1f° — the 94-min orbit — so n·vS changes by up to %.2f)\n", extrema(dvs)..., 2sind(maximum(dvs) / 2))
end

println("\n=== 6. Star mask hook (deliberately off) ===")
t2 = apply_star_mask(tab); check("mode :none returns the table unchanged", t2 === tab)
try apply_star_mask(tab; mode=:catalog); check("other modes refuse until implemented", false)
catch; check("other modes refuse until implemented", true); end

println("\n=== 7. Cluster lanes ===")
include(joinpath(ROOT, "sweeps", "configs_v9.jl"))
nm9 = collect(keys(CONFIGS)); L = [slurm_lane(nm9, k, 16) for k in 1:16]
check("16 lanes cover all $(length(nm9)) round-9 configs exactly once", sort(vcat(L...)) == sort(nm9))
@printf("  lane sizes: %s\n", join(length.(L), " "))

println("\n=== Summary ===")
println(count(last, results), "/", length(results), " checks passed")
for (k, v) in results; v || println("  FAILED: ", k); end
