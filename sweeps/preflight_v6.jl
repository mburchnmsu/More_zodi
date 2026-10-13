# Pre-flight physics checks for round 6 features (no training).
using LinearAlgebra; BLAS.set_num_threads(4)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
include(joinpath(@__DIR__, "extra_features.jl"))
col(nm) = Fd_raw[:, findfirst(==(nm), dot_names_all)]
for (k, v) in FEATURE_SETS; println(rpad(k, 17), join(v, ", ")); end

println("\n--- Jupiter-like features: what do they add beyond the fixed frame (n·x, n·y, n·z), and is it a clock? ---")
Xf = hcat(ones(N), nvec_unit_cartesian')                         # fixed-frame span
tc = t_rel .- mean(t_rel)
Xt = hcat(nvec_unit_cartesian' .* tc, nvec_unit_cartesian' .* tc .^ 2)   # n·(dJ/dt)·t + curvature: linear-in-time motion
for nm in ("n·J", "n·Jrot45", "n·Jrot90", "n·Jrot180", "n·Jscr")
    f = col(nm); m = f .- Xf * (Xf \ f)                           # moving part (beyond the fixed frame)
    R2 = 1 - sum(abs2, m .- Xt * (Xt \ m)) / sum(abs2, m .- mean(m))
    @printf("  %-9s corr with n·J %+.4f | moving part rms %.3f (%.1f%% of feature) | R² of moving part vs smooth time drift %.3f\n",
            nm, cor(f, col("n·J")), sqrt(mean(abs2, m)), 100sqrt(mean(abs2, m)) / std(f), R2)
end
tr, te = splits["80/20 Chronological"]
for nm in ("n·J", "n·Jrot45", "n·Jrot90", "n·Jscr")
    lo, hi = extrema(col(nm)[tr]); v = col(nm)[te]
    @printf("  %-9s test exposures outside training range: %.1f%%\n", nm, 100mean((v .< lo) .| (v .> hi)))
end

println("\n--- Earth-centric: the LEO offset δ = S − E ---")
dn = sqrt.(sum(δ_vec .^ 2, dims=1))
@printf("  |δ| = %.2e – %.2e AU (%.0f – %.0f km; LEO radius ≈ Earth radius + altitude)\n", extrema(dn)..., (extrema(dn) .* 1.496e8)...)
@printf("  n·δ range %.2e – %.2e AU; corr(n·δ, n·δ̂) = %.4f (|δ| nearly constant → n·δ ≈ |δ|·n·δ̂)\n", extrema(col("n·δ"))..., cor(col("n·δ"), col("n·δ̂")))
@printf("  n·δ / |δ| in training: %.2f – %.2f → boresight is always %.0f°–180° from Earth's centre (Earth-avoidance pointing)\n",
        extrema(col("n·δ")[tr] ./ vec(dn)[tr])..., acosd(-minimum(col("n·δ")[tr] ./ vec(dn)[tr])))
@printf("  n·S vs n·E: corr %.6f, max |n·S − n·E| = %.2e AU (= max |n·δ|)\n", cor(col("n·S"), col("n·E")), maximum(abs.(col("n·S") .- col("n·E"))))

println("\n--- expected size of the LEO parallax on the brightness ---")
include(joinpath(@__DIR__, "..", "emulator", "ZodiEmulator.jl")); using .ZodiEmulator
em = load_emulator(joinpath(@__DIR__, "..", "emulator", "zodi_emulator_v1.jld2"))
sub = 1:20:N
base = predict_zodi(em, nvec_unit_cartesian[:, sub]; S=spherex_positions[:, sub], E=earth_positions[:, sub],
                    vS=v_spherex[:, sub], vE=v_earth[:, sub], J=jupiter_positions[:, sub])
moved = predict_zodi(em, nvec_unit_cartesian[:, sub]; S=earth_positions[:, sub], E=earth_positions[:, sub],   # observer at Earth's centre
                     vS=v_spherex[:, sub], vE=v_earth[:, sub], J=jupiter_positions[:, sub])
fd = abs.(moved.mean .- base.mean) ./ base.mean
@printf("  emulator: moving the observer from SPHEREx to Earth's centre changes the prediction by median %.1e, 99th pct %.1e (fractional)\n",
        median(fd), quantile(fd, 0.99))
@printf("  order-of-magnitude physics: |δ|/r × |dlnI/dlnr| ≈ %.1e × ~2 ≈ %.0e  → MSE contribution ≈ (%.0e × 0.45)² ≈ %.0e (MJy/sr)²\n",
        mean(dn), 2mean(dn), 2mean(dn), 2mean(dn), (2mean(dn) * 0.45)^2)
@printf("  current test MSE ~1e-4 → the parallax term is ~%.0e times smaller: the Earth-centric switch SHOULD be a null\n", 1e-4 / (2mean(dn) * 0.45)^2)
