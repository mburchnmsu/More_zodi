# Pick sky-patch centres: count exposures within 12° of candidate centres, and check they're observed over time.
using LinearAlgebra; BLAS.set_num_threads(4)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
angdist(lonc, latc) = acosd.(clamp.(vec([cosd(latc) * cosd(lonc) cosd(latc) * sind(lonc) sind(latc)] * nvec_unit_cartesian), -1, 1))
r = 12.0
for latc in (0.0, 45.0, -45.0, 75.0)
    println("centre latitude $(latc)°:")
    for lonc in 0:30:330
        m = angdist(lonc, latc) .<= r
        c = count(m)
        c > 0 || continue
        @printf("   lon %3d°: %6d exposures (%.1f%%), days %.0f–%.0f, elongation %.0f–%.0f°\n", lonc, c, 100c / N,
                extrema(t_rel[m])..., extrema(acosd.(clamp.(-vec(sum(nvec_unit_cartesian[:, m] .* (spherex_positions[:, m] ./ sqrt.(sum(spherex_positions[:, m] .^ 2, dims=1))), dims=1)), -1, 1)))...)
    end
end
