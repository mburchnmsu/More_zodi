# Fitted parallax band-layer parameters (rounds 31–32), per shift and seed, to check they are consistent across splits.
#   julia --project=. sweeps/band_params_r32.jl            (ENV["BAND_FAM"] = "z500h_bandplx2k_shift" for round 34)
ENV["ZODI_DATA"] = "z500"; ENV["ZODI_HELIO"] = "1"
using LinearAlgebra; BLAS.set_num_threads(2)
redirect_stdout(devnull) do
    include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
    for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "shift_helpers.jl"); include(joinpath(@__DIR__, f)); end
end
println("Kelsall: i ", KELSALL_BANDS.i, "  Ω ", KELSALL_BANDS.Ω, "  δζ ", KELSALL_BANDS.δζ, "  v ", KELSALL_BANDS.v)
P = Dict(k => Float64[] for k in (:i, :Ω, :δζ, :v, :R))
const FAM = get(ENV, "BAND_FAM", "z500h_bandplx_kelsall_shift")
for Δ in (0, 10, 20, 30, 40, 50), r in runs16("$FAM$Δ")
    local p = band_params(r.model[1])
    for k in keys(P); append!(P[k], getfield(p, k)); end
    @printf("shift %2d seed %d | i %s | Ω %s | δζ %s | v %s | R %s\n", Δ, r.seed,
            (join((@sprintf("%6.2f", x) for x in getfield(p, k)), " ") for k in (:i, :Ω, :δζ, :v, :R))...)
end
# summary over all 30 networks (each band); the node is a circular mean/spread (one seed's band-2 node is 359.96° ≡ −0.04°)
println("\nall 30 networks, mean ± std (node: circular mean ± circular std):")
for b in 1:3
    sel(k) = P[k][b:3:end]; Ω = deg2rad.(sel(:Ω)); C = mean(cis.(Ω))
    @printf("band %d: i %.2f ± %.2f°  Ω %.1f ± %.1f°  δζ %.2f ± %.2f°  v %.2f ± %.2f  R %.2f ± %.2f AU\n", b,
            mean(sel(:i)), std(sel(:i)), mod(rad2deg(angle(C)), 360), rad2deg(sqrt(-2log(abs(C)))),
            mean(sel(:δζ)), std(sel(:δζ)), mean(sel(:v)), std(sel(:v)), mean(sel(:R)), std(sel(:R)))
end
