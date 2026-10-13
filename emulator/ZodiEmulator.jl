"""
    ZodiEmulator

Self-contained neural-network emulator of the Kelsall (1998) 5 μm zodiacal emission (as evaluated by ZodiPy)
along a line of sight, trained on SPHEREx boresight geometry (Oct 2026, More_zodi project).

    using .ZodiEmulator
    em = load_emulator("zodi_emulator_v1.jld2")
    out = predict_zodi(em, nvec; S, E, vS, vE, J)      # out.mean, out.std, out.in_domain  (MJy/sr)

Geometry: barycentric ecliptic frame, positions in AU (S = SPHEREx, E = Earth, J = Jupiter), velocities in any
units (only their directions are used), `nvec` = 3×M unit line-of-sight vectors. Each of S, E, vS, vE, J may be
a 3-vector (one epoch for all directions) or a 3×M matrix (one epoch per direction).

The model is an ensemble of 5 MLPs (8 → 64 → 64 → 32 → 16 → 1, gelu). `std` is the spread across members.
**Trust predictions only where `in_domain` is true** — every input feature inside its training range. Out of
domain (e.g. looking within ~60° of the Sun) errors can be tens of percent and the ensemble spread does NOT warn.
"""
module ZodiEmulator

using Flux, JLD2, HDF5, Statistics, Printf
export load_emulator, predict_zodi, emulator_features, load_ephemeris, out_of_range, Emulator

const FEATURES = ["n·S", "n·z", "n·E", "n·vS", "n·vE", "n·J", "n·x", "n·y"]   # order the networks expect

struct Emulator
    members::Vector{Any}          # Flux Chains
    μ::Vector{Float64}            # robust centre of each feature (training median)
    σ::Vector{Float64}            # robust scale (training IQR / 1.349)
    lo::Vector{Float64}           # training range of each feature (in-domain mask)
    hi::Vector{Float64}
    meta::Dict{String, Any}
end
Base.show(io::IO, em::Emulator) = print(io, "ZodiEmulator ($(length(em.members))-member ensemble, ",
                                        get(em.meta, "recipe", ""), ")")

build_mlp(n_in, hidden) = (w = (n_in, hidden...);
    Chain([Dense(w[i] => w[i+1], gelu) for i in 1:length(hidden)]..., Dense(w[end] => 1)))

"""Load an emulator saved by `export_emulator.jl`."""
function load_emulator(path)
    d = JLD2.load(path)
    @assert d["feature_names"] == FEATURES "feature order mismatch"
    members = map(d["states"]) do st
        m = build_mlp(length(FEATURES), Tuple(d["hidden"])); Flux.loadmodel!(m, st); m
    end
    Emulator(members, d["mu"], d["sigma"], d["lo"], d["hi"], d["meta"])
end

as3M(v, M) = (v isa AbstractVector ? repeat(reshape(Float64.(v), 3, 1), 1, M) : Float64.(v))
unitcols(A) = A ./ sqrt.(sum(abs2, A, dims=1))
coldot(A, B) = vec(sum(A .* B, dims=1))

"""8 × M feature matrix (rows in `FEATURES` order) from raw geometry."""
function emulator_features(nvec; S, E, vS, vE, J)
    M = size(nvec, 2)
    n = Float64.(nvec)
    S3, E3, J3 = as3M(S, M), as3M(E, M), as3M(J, M)
    vS3, vE3 = unitcols(as3M(vS, M)), unitcols(as3M(vE, M))
    permutedims(hcat(coldot(n, S3), n[3, :], coldot(n, E3), coldot(n, vS3), coldot(n, vE3),
                     coldot(n, J3), n[1, :], n[2, :]))
end

"""
    predict_zodi(em, nvec; S, E, vS, vE, J) -> (; mean, std, members, in_domain, features)

Zodiacal emission in MJy/sr along each column of `nvec`.
"""
function predict_zodi(em::Emulator, nvec; S, E, vS, vE, J, batch=65_536)
    F = emulator_features(nvec; S, E, vS, vE, J)
    X = Float32.((F .- em.μ) ./ em.σ)
    P = zeros(Float64, size(X, 2), length(em.members))
    for (k, m) in enumerate(em.members), s in 1:batch:size(X, 2)
        e = min(s + batch - 1, size(X, 2))
        P[s:e, k] .= vec(m(X[:, s:e]))
    end
    in_domain = vec(all(em.lo .<= F .<= em.hi, dims=1))
    (; mean=vec(mean(P, dims=2)), std=vec(std(P, dims=2)), members=P, in_domain, features=F)
end
predict_zodi(em::Emulator, nvec, eph::NamedTuple) = predict_zodi(em, nvec; eph.S, eph.E, eph.vS, eph.vE, eph.J)

"""Which features of prediction column `k` lie outside the training range, e.g. `["n·z = 1.000 > 0.999"]`."""
out_of_range(em::Emulator, out, k) =
    [@sprintf("%s = %.4f %s %.4f", FEATURES[i], out.features[i, k], out.features[i, k] < em.lo[i] ? "<" : ">",
              out.features[i, k] < em.lo[i] ? em.lo[i] : em.hi[i])
     for i in eachindex(FEATURES) if !(em.lo[i] <= out.features[i, k] <= em.hi[i])]

"""Ephemeris (S, E, vS, vE, J as 3×M) for exposure indices `idx` from the project's HDF5 vectors file."""
function load_ephemeris(vectors_file, idx)
    h5open(vectors_file) do f
        g(k) = read(f[k])[:, idx]
        (; S=g("spherex/positions"), E=g("earth/positions"), vS=g("spherex/velocities"),
           vE=g("earth/velocities"), J=g("jupiter/positions"))
    end
end

end # module
