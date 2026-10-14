# Checks for emulator v2 (and that v1 still works after the module change).   julia --project=.. test_emulator_v2.jl
#   → emulator/emulator_v2_checks.log (printed)
ENV["ZODI_DATA"] = "z115"
using LinearAlgebra; BLAS.set_num_threads(2)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl", "extra_splits.jl"); include(joinpath(@__DIR__, "..", "sweeps", f)); end
include(joinpath(@__DIR__, "ZodiEmulator.jl")); using .ZodiEmulator
using Serialization
npass = Ref(0); nfail = Ref(0)
check(name, ok) = (ok ? npass[] += 1 : nfail[] += 1; println(ok ? "[PASS] " : "[FAIL] ", name))
eph(idx) = (; S=spherex_positions[:, idx], E=earth_positions[:, idx], vS=v_spherex[:, idx], vE=v_earth[:, idx], J=jupiter_positions[:, idx])

# --- v1 still loads and reproduces its own training-run ensemble (original data) ---------------------------------
em1 = load_emulator(joinpath(@__DIR__, "zodi_emulator_v1.jld2"))
r1s = [deserialize(joinpath(PROJECT_DIR, "sweeps", "results", "final_base_s$s.jls")) for s in 42:46]
k = 1:97:N
o1 = predict_zodi(em1, nvec_unit_cartesian[:, k], eph(k))
d1 = maximum(abs.(o1.mean .- vec(mean(reduce(hcat, [r.ypred[k] for r in r1s]), dims=2))) ./ o1.mean)
check(@sprintf("v1 unchanged: reproduces its training ensemble (max rel diff %.1e)", d1), d1 < 1e-5)

# --- v2 -------------------------------------------------------------------------------------------------------------
em2 = load_emulator(joinpath(@__DIR__, "zodi_emulator_v2.jld2")); println(em2)
runs = [deserialize(joinpath(RESULTS_DIR, "z115_sunseason_r90_s$s.jls")) for s in 42:46]
F2 = emulator_features(nvec_unit_cartesian[:, k]; eph(k)..., names=em2.features)
cols = [findfirst(==(nm), dot_names_all) for nm in em2.features]
dF = maximum(abs.(F2 .- permutedims(Fd_raw[k, cols])))
check(@sprintf("v2 features == training features (max diff %.1e)", dF), dF < 1e-12)
o2 = predict_zodi(em2, nvec_unit_cartesian[:, k], eph(k))
d2 = maximum(abs.(o2.mean .- vec(mean(reduce(hcat, [r.ypred[k] for r in runs]), dims=2))) ./ o2.mean)
check(@sprintf("v2 reproduces its training ensemble (max rel diff %.1e)", d2), d2 < 1e-5)
o2nj = predict_zodi(em2, nvec_unit_cartesian[:, k]; S=spherex_positions[:, k], E=earth_positions[:, k], vS=v_spherex[:, k], vE=v_earth[:, k])
check("v2 does not need Jupiter (same result without J)", o2nj.mean == o2.mean)
te = runs[1].te_idx
o2t = predict_zodi(em2, nvec_unit_cartesian[:, te], eph(te)); fe = abs.(o2t.mean .- y[te]) ./ y[te]
@printf("  held-out 10%% of the mission (%d exposures): median %.4f%%, p95 %.3f%%, in-domain %.1f%%\n",
        length(te), 100median(fe), 100quantile(fe, 0.95), 100mean(o2t.in_domain))
check("v2 held-out median error < 0.03%", median(fe) < 3e-4)
try predict_zodi(em1, nvec_unit_cartesian[:, 1:3]; S=spherex_positions[:, 1:3], E=earth_positions[:, 1:3], vS=v_spherex[:, 1:3], vE=v_earth[:, 1:3])
    check("v1 without J errors", false)
catch err; check("v1 without J errors clearly", occursin("Jupiter", sprint(showerror, err))) end

# --- v2 on the synthetic future set: accuracy and the in-domain flag --------------------------------------------------
F = h5open(joinpath(DATA_DIR, "zodipy115_future.h5")) do f
    (; y=read(f["emission"]), Δ=read(f["delta_days"]), n=read(f["pointing/nvec_unit_cartesian"]), S=read(f["spherex/positions"]),
       vS=read(f["spherex/velocities"]), E=read(f["earth/positions"]), vE=read(f["earth/velocities"]))
end
of = predict_zodi(em2, F.n; S=F.S, E=F.E, vS=F.vS, vE=F.vE); ff = abs.(of.mean .- F.y) ./ F.y
@printf("  future set (%d exposures, +30…+540 d): in-domain %.1f%% → median %.3f%%; out-of-domain → median %.3f%%\n",
        length(ff), 100mean(of.in_domain), 100median(ff[of.in_domain]), 100median(ff[.!of.in_domain]))
println("  by shift: ", join([@sprintf("+%dd %.2f%%", d, 100median(ff[F.Δ .== d])) for d in sort(unique(F.Δ))[1:3:end]], ", "))
check("in-domain flag is informative on the future set (in-domain median error < out-of-domain)", median(ff[of.in_domain]) < median(ff[.!of.in_domain]))
println("\n$(npass[])/$(npass[] + nfail[]) checks passed")
