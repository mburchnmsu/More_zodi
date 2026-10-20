# Minimal example: load the packaged emulator and predict the zodiacal emission.
#   julia --project=C:\JuliaProjects\More_zodi example_usage.jl
include(joinpath(@__DIR__, "ZodiEmulator.jl")); using .ZodiEmulator
using Printf

em = load_emulator(joinpath(@__DIR__, "zodi_emulator_v1.jld2"))
println(em)

# 1) Geometry for one epoch, taken from the project's ephemeris file (exposure index 13170)
eph = load_ephemeris(joinpath(@__DIR__, "..", "data", "d140", "spherex_vectors_bore_interpolated.h5"), [13170])
eph1 = map(v -> vec(v), eph)                                   # 3×1 → 3-vectors (same epoch for every direction)

# 2) A few lines of sight (unit vectors, barycentric ecliptic): north ecliptic pole, and points on the ecliptic
#    at 90° and 120° from the Sun on the trailing side
Ŝ = eph1.S ./ sqrt(sum(abs2, eph1.S)); λsun = atand(-Ŝ[2], -Ŝ[1])          # Sun's ecliptic longitude seen from SPHEREx
dirs = [0 0 1; cosd(λsun + 90) sind(λsun + 90) 0; cosd(λsun + 120) sind(λsun + 120) 0]'
out = predict_zodi(em, dirs, eph1)
for (k, nm) in enumerate(["north ecliptic pole", "ecliptic, 90° from Sun", "ecliptic, 120° from Sun"])
    @printf("%-24s %.4f ± %.4f MJy/sr   in-domain: %s\n", nm, out.mean[k], out.std[k], out.in_domain[k])
    out.in_domain[k] || println("    out of training range: ", join(out_of_range(em, out, k), "; "))
end
# Out-of-domain predictions can still be close (see emulator_checks.log), but they are not guaranteed —
# treat them as extrapolations. The ensemble spread (±) is NOT a reliable warning there.
