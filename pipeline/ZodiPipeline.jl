"""
    ZodiPipeline

Real-data preparation for the zodi emulator (More_zodi, round 9, 2026-10-13). It turns a table of exposures
(time, pointing, measured sky level) plus ephemerides into exactly the features the emulator was trained on,
so the simulated and real data go through the SAME code path.

    include("pipeline/ZodiPipeline.jl"); using .ZodiPipeline
    tab = exposure_table(jd, nvec, sky)                       # or exposure_table_radec(jd, ra, dec, sky)
    tab = apply_star_mask(tab)                                # no-op for now (mode = :none)
    eph = ephemeris_at(tab.jd; earth, jupiter, spherex)       # Ephemeris objects from JPL Horizons files
    F, names = build_features(tab.nvec, eph)                  # feature matrix (M × K), names as in training

Frame: barycentric ecliptic (J2000 mean ecliptic), positions in AU, velocities in AU/day — the frame of the
simulated training data. Pointing given as RA/Dec (ICRS) is rotated to ecliptic with the IAU 2006 J2000 obliquity.
"""
module ZodiPipeline

using LinearAlgebra, Printf, Statistics
export ExposureTable, exposure_table, exposure_table_radec, validate_table, apply_star_mask,
       radec_to_ecliptic, ecliptic_to_radec, ecliptic_lonlat,
       Ephemeris, read_horizons_vectors, write_horizons_vectors, interpolate_ephemeris, ephemeris_at,
       build_features, FEATURE_NAMES, BAND_SHARP_NAMES, BAND_PLX_NAMES, slurm_lane

const AU_KM = 1.495978707e8
const OBLIQUITY_J2000 = 84381.406 / 3600       # deg, IAU 2006 mean obliquity at J2000 (astropy's barycentricmeanecliptic)

# ------------------------------------------------------------------ exposure table
"""One row per exposure: mid-exposure Julian Date, ecliptic unit pointing vector, measured sky level (MJy/sr)."""
struct ExposureTable
    jd::Vector{Float64}
    nvec::Matrix{Float64}          # 3 × M, unit vectors, barycentric-ecliptic axes
    sky::Vector{Float64}           # target (MJy/sr); NaN allowed for prediction-only tables
    sky_err::Vector{Float64}       # 1σ uncertainty (NaN if unknown)
    wavelength_um::Vector{Float64} # per exposure (the current emulator is 5 μm only)
    keep::BitVector                # false = masked / rejected (star mask, bad flags, ...)
end
Base.length(t::ExposureTable) = length(t.jd)
Base.show(io::IO, t::ExposureTable) = @printf(io, "ExposureTable(%d exposures, %d kept, JD %.3f–%.3f)",
                                             length(t), count(t.keep), extrema(t.jd)...)

function exposure_table(jd, nvec, sky; sky_err=fill(NaN, length(jd)), wavelength_um=fill(5.0, length(jd)))
    t = ExposureTable(Float64.(jd), Float64.(nvec), Float64.(sky), Float64.(sky_err), Float64.(wavelength_um),
                      trues(length(jd)))
    validate_table(t); t
end
exposure_table_radec(jd, ra_deg, dec_deg, sky; kw...) = exposure_table(jd, radec_to_ecliptic(ra_deg, dec_deg), sky; kw...)

"""Throws on malformed input; returns a NamedTuple of warnings-level facts otherwise."""
function validate_table(t::ExposureTable)
    M = length(t.jd)
    size(t.nvec) == (3, M) || error("nvec must be 3 × $M, got $(size(t.nvec))")
    all(length(v) == M for v in (t.sky, t.sky_err, t.wavelength_um, t.keep)) || error("column lengths differ")
    all(isfinite, t.jd) || error("non-finite Julian Dates")
    nrm = vec(sqrt.(sum(abs2, t.nvec, dims=1)))
    maximum(abs.(nrm .- 1)) < 1e-6 || error("nvec columns are not unit vectors (max |‖n‖−1| = $(maximum(abs.(nrm .- 1))))")
    neg = count(<(0), filter(isfinite, t.sky))
    neg > 0 && @warn "$neg exposures have negative sky level"
    any(!=(5.0), t.wavelength_um) && @warn "table contains wavelengths other than 5 μm; the current emulator is 5 μm only"
    (; M, negative=neg)
end

"""
Star masking hook. **Not applied yet** (the simulated data are clean; the user will say when to switch it on).
`mode = :none` returns the table unchanged. Real masking will set `keep = false` for exposures/pixels near
catalogue sources (or replace `sky` by a source-masked statistic) — implement under a new mode when needed.
"""
function apply_star_mask(t::ExposureTable; mode::Symbol=:none)
    mode === :none && return t
    error("star mask mode :$mode is not implemented yet — masking is intentionally off until the user asks for it")
end

# ------------------------------------------------------------------ coordinates
"""ICRS RA/Dec (deg) → 3×M unit vectors on barycentric mean-ecliptic J2000 axes."""
function radec_to_ecliptic(ra_deg, dec_deg; ε=OBLIQUITY_J2000)
    x = cosd.(dec_deg) .* cosd.(ra_deg); y = cosd.(dec_deg) .* sind.(ra_deg); z = sind.(dec_deg)
    permutedims(hcat(x, y .* cosd(ε) .+ z .* sind(ε), -y .* sind(ε) .+ z .* cosd(ε)))
end
"""Inverse of `radec_to_ecliptic`: returns (ra_deg, dec_deg)."""
function ecliptic_to_radec(nvec; ε=OBLIQUITY_J2000)
    x, y, z = nvec[1, :], nvec[2, :], nvec[3, :]
    ye, ze = y .* cosd(ε) .- z .* sind(ε), y .* sind(ε) .+ z .* cosd(ε)
    mod.(atand.(ye, x), 360), asind.(clamp.(ze, -1, 1))
end
ecliptic_lonlat(nvec) = (mod.(atand.(nvec[2, :], nvec[1, :]), 360), asind.(clamp.(nvec[3, :], -1, 1)))

# ------------------------------------------------------------------ ephemerides (JPL Horizons vector tables)
"""Tabulated state vectors: `jd` (TDB), `pos` 3×K (AU), `vel` 3×K (AU/day)."""
struct Ephemeris
    name::String
    jd::Vector{Float64}
    pos::Matrix{Float64}
    vel::Matrix{Float64}
end
Base.show(io::IO, e::Ephemeris) = @printf(io, "Ephemeris(%s, %d nodes, JD %.3f–%.3f, step %.4g d)", e.name, length(e.jd),
                                         extrema(e.jd)..., length(e.jd) > 1 ? median(diff(e.jd)) : NaN)

"""
Read a JPL Horizons VECTORS table saved as text with CSV format = YES (quantities: state vector, i.e. table type 2).
Request: Center = Solar System Barycenter (500@0), Reference plane = ECLIPTIC (J2000), output units AU-D (KM-S also
accepted and converted). Header lines are checked for centre and plane; a mismatch is an error, not a warning.
"""
function read_horizons_vectors(path; name=splitext(basename(path))[1])
    lines = readlines(path)
    hdr = join(lines[1:something(findfirst(==("\$\$SOE"), strip.(lines)), length(lines))], "\n")
    occursin(r"Center body name:\s*Solar System Barycenter"i, hdr) || error("$path: centre must be the Solar System Barycenter")
    occursin(r"Reference plane\s*:\s*ECLIPTIC"i, hdr) || error("$path: reference plane must be ECLIPTIC")
    km = occursin(r"Output units\s*:\s*KM-S"i, hdr)
    i0 = findfirst(==("\$\$SOE"), strip.(lines)); i1 = findfirst(==("\$\$EOE"), strip.(lines))
    (i0 === nothing || i1 === nothing) && error("$path: no \$\$SOE/\$\$EOE block — was CSV format = YES?")
    rows = [split(l, ',') for l in lines[i0+1:i1-1] if !isempty(strip(l))]
    jd  = [parse(Float64, r[1]) for r in rows]
    num(r, k) = parse(Float64, strip(r[k]))
    pos = reduce(hcat, [[num(r, 3), num(r, 4), num(r, 5)] for r in rows])     # 3 × K
    vel = reduce(hcat, [[num(r, 6), num(r, 7), num(r, 8)] for r in rows])
    if km; pos ./= AU_KM; vel .*= 86400 / AU_KM; end
    issorted(jd) || error("$path: times not increasing")
    Ephemeris(name, jd, pos, vel)
end

"""Write an Ephemeris in the Horizons CSV layout read by `read_horizons_vectors` (used by the tests)."""
function write_horizons_vectors(path, e::Ephemeris)
    open(path, "w") do io
        println(io, "Target body name: $(e.name)\nCenter body name: Solar System Barycenter (0)\nOutput units    : AU-D")
        println(io, "Reference frame : ICRF\nReference plane : ECLIPTIC\n\$\$SOE")
        for k in eachindex(e.jd)
            @printf(io, "%.9f, A.D. xxxx, %.16e, %.16e, %.16e, %.16e, %.16e, %.16e,\n", e.jd[k], e.pos[:, k]..., e.vel[:, k]...)
        end
        println(io, "\$\$EOE")
    end
    path
end

"""Cubic Hermite interpolation (positions AND velocities at the nodes) → (pos 3×M, vel 3×M) at times `jd`."""
function interpolate_ephemeris(e::Ephemeris, jd::AbstractVector)
    lo, hi = extrema(e.jd)
    all(lo .<= jd .<= hi) || error("$(e.name): requested JD outside the tabulated range $(lo)–$(hi)")
    P = zeros(3, length(jd)); V = zeros(3, length(jd))
    for (m, t) in enumerate(jd)
        k = clamp(searchsortedlast(e.jd, t), 1, length(e.jd) - 1)
        h = e.jd[k+1] - e.jd[k]; s = (t - e.jd[k]) / h
        h00, h10, h01, h11 = 2s^3 - 3s^2 + 1, s^3 - 2s^2 + s, -2s^3 + 3s^2, s^3 - s^2
        d00, d10, d01, d11 = 6s^2 - 6s, 3s^2 - 4s + 1, -6s^2 + 6s, 3s^2 - 2s
        p0, p1, v0, v1 = e.pos[:, k], e.pos[:, k+1], e.vel[:, k], e.vel[:, k+1]
        P[:, m] = h00 * p0 + h10 * h * v0 + h01 * p1 + h11 * h * v1
        V[:, m] = (d00 * p0 + d10 * h * v0 + d01 * p1 + d11 * h * v1) / h
    end
    P, V
end

"""
Per-exposure geometry (S, E, vS, vE, J as 3×M) from ephemerides. Without a spacecraft ephemeris, SPHEREx is placed at
Earth's centre (S = E, vS = vE): the low-Earth-orbit offset is ≤ 5e-5 AU (see the pipeline test for the effect on
the emulator).
"""
function ephemeris_at(jd; earth::Ephemeris, jupiter::Ephemeris, spherex::Union{Ephemeris, Nothing}=nothing)
    E, vE = interpolate_ephemeris(earth, jd)
    J, _  = interpolate_ephemeris(jupiter, jd)
    S, vS = spherex === nothing ? (E, vE) : interpolate_ephemeris(spherex, jd)
    (; S, E, vS, vE, J)
end

# ------------------------------------------------------------------ features (must match sweeps/extra_features.jl)
const FEATURE_NAMES = ["n·S", "n·z", "n·E", "n·vS", "n·vE", "n·J", "n·x", "n·y", "sinλE", "cosλE"]
const BANDS = [(name="band1", δζ=8.78, v=0.10, p=4.0, i=0.56, Ω=80.0),
               (name="band2", δζ=1.99, v=0.90, p=4.0, i=1.2,  Ω=30.347),
               (name="band3", δζ=15.0, v=0.05, p=4.0, i=0.8,  Ω=80.0)]
const BAND_RADII = (1.25, 1.5, 2.0)
const BAND_SHARP_NAMES = [b.name for b in BANDS]
const BAND_PLX_NAMES   = ["$(b.name)@$(R)" for b in BANDS for R in BAND_RADII]
coldot(A, B) = vec(sum(A .* B, dims=1))
unitcols(A) = A ./ sqrt.(sum(abs2, A, dims=1))
band_normal(b) = [sind(b.i) * sind(b.Ω), -sind(b.i) * cosd(b.Ω), cosd(b.i)]
band_profile(b, ζ) = (u = abs(ζ) / deg2rad(b.δζ); exp(-u^6) * (b.v + u^b.p))
function band_parallax_ζ(n, O, nb, R)
    on = coldot(n, O); oo = vec(sum(abs2, O, dims=1))
    s = -on .+ sqrt.(on .^ 2 .- oo .+ R^2)
    (vec(nb' * O) .+ s .* vec(nb' * n)) ./ R
end

"""
    build_features(nvec, geom; bands=true) -> (F::Matrix (M × K), names)

`geom` = (; S, E, vS, vE, J), each 3×M (from `ephemeris_at`). Columns: $(join(FEATURE_NAMES, ", ")), then
(if `bands`) the 3 sharp and 9 parallax dust-band profiles. Identical definitions to the training code.
"""
function build_features(nvec, geom; bands=true)
    n = Float64.(nvec); λE = mod.(atand.(geom.E[2, :], geom.E[1, :]), 360)
    cols = [coldot(n, geom.S), n[3, :], coldot(n, geom.E), coldot(n, unitcols(geom.vS)), coldot(n, unitcols(geom.vE)),
            coldot(n, geom.J), n[1, :], n[2, :], sind.(λE), cosd.(λE)]
    names = copy(FEATURE_NAMES)
    if bands
        for b in BANDS
            push!(cols, band_profile.(Ref(b), asin.(clamp.(vec(band_normal(b)' * n), -1, 1))))
        end
        for b in BANDS, R in BAND_RADII
            push!(cols, band_profile.(Ref(b), band_parallax_ζ(n, geom.S, band_normal(b), R)))
        end
        append!(names, BAND_SHARP_NAMES, BAND_PLX_NAMES)
    end
    reduce(hcat, cols), names
end

# ------------------------------------------------------------------ cluster helper
"""Deterministic share of `names` for array task `task` (1-based) of `ntasks`: round-robin over the sorted list."""
slurm_lane(names, task, ntasks) = (s = sort(collect(names)); s[task:ntasks:end])

end # module
