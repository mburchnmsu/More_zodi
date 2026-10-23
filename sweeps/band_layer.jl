# Learnable dust-band layer (Oct 21–22). The user's plan: don't hand the network Kelsall's FIXED band shapes (that imports
# the simulator's answer); instead let it LEARN each band's geometry and profile from the data. For real SPHEREx data the
# fitted values become a measurement.
#
# For each of the 3 bands k the layer computes Kelsall's vertical profile as a function of the pointing's latitude above
# the band's plane:
#     ζ_k = asin(n̂ · N_k),   N_k = (sin i_k sin Ω_k, −sin i_k cos Ω_k, cos i_k)      (band-plane normal; inclination i, node Ω)
#     u_k = |ζ_k| / δζ_k,     g_k = exp(−u_k⁶) · (v_k + u_k⁴)                         (Kelsall's double-hump shape)
# with TRAINABLE i_k, Ω_k, δζ_k (via log), v_k (via softplus), started at Kelsall's values (or perturbed, for recovery
# tests). The 3 profiles are appended to the usual inputs and the MLP follows.
#
# The pointing enters through the dot products n̂·x̂, n̂·ŷ, n̂·ẑ, which must be the LAST THREE input features (see
# FEATURE_SETS[:sunseason_learnband]); the layer un-standardises them with the training μ, σ (fixed). Only the profiles
# are passed on, so the MLP still sees no sky coordinates directly.
#   arch = :bandmlp in train_mb (sweeps/mb_train.jl); `band_init` = :kelsall (default) or a NamedTuple of initial values.
using Flux

struct BandLayer{V}
    i::V; Ω::V; logδζ::V; vraw::V           # trainable, one entry per band (angles in radians)
    μn::Vector{Float32}; σn::Vector{Float32} # standardisation of n̂·x̂, n̂·ŷ, n̂·ẑ (fixed)
end
Flux.@layer BandLayer trainable=(i, Ω, logδζ, vraw)

const KELSALL_BANDS = (i=[0.56, 1.2, 0.8], Ω=[80.0, 30.347, 80.0], δζ=[8.78, 1.99, 15.0], v=[0.10, 0.90, 0.05])   # = BANDS
softplus_inv(v) = log(expm1(v))
function BandLayer(μn, σn; init=KELSALL_BANDS)
    f(x) = Float32.(collect(x))
    BandLayer(f(deg2rad.(init.i)), f(deg2rad.(init.Ω)), f(log.(deg2rad.(init.δζ))), f(softplus_inv.(init.v)), f(μn), f(σn))
end

function (b::BandLayer)(x::AbstractMatrix)
    k = size(x, 1)
    nxyz = x[k-2:k, :] .* b.σn .+ b.μn                                  # raw n̂·x̂, n̂·ŷ, n̂·ẑ
    N = vcat((sin.(b.i) .* sin.(b.Ω))', (-sin.(b.i) .* cos.(b.Ω))', cos.(b.i)')     # 3 (xyz) × 3 (bands)
    s = clamp.(N' * nxyz, -1f0 + 1f-6, 1f0 - 1f-6)                      # bands × samples
    u = abs.(asin.(s)) ./ exp.(b.logδζ)
    g = exp.(-u .^ 6) .* (softplus.(b.vraw) .+ u .^ 4)
    vcat(x[1:k-3, :], g)
end

"""Fitted band parameters in degrees (and v), for reporting."""
band_params(b::BandLayer) = (i=rad2deg.(b.i), Ω=mod.(rad2deg.(b.Ω), 360), δζ=rad2deg.(exp.(b.logδζ)), v=softplus.(b.vraw))

function build_bandmlp(n_in, hidden, rng, μn, σn; init=KELSALL_BANDS)
    Chain(BandLayer(μn, σn; init), build_mlp(n_in, hidden, rng))    # n_in − 3 inputs + 3 profiles = n_in
end

# ---------------------------------------------------------------------------------------------------- parallax version
# Kelsall's bands are rings of dust at heliocentric distance R; seen from SPHEREx (≈1 AU) their latitude depends on where
# the line of sight crosses them. The parallax layer evaluates the profile at the point P = O + s n̂ where the line of
# sight from the observer O (SPHEREx's HELIOcentric position) reaches distance Rₖ from the Sun:
#     s = −n̂·O + √((n̂·O)² − |O|² + Rₖ²),   ζₖ = (Nₖ · P) / Rₖ
# (as `band_parallax_ζ` in extra_features.jl), with a TRAINABLE ring distance Rₖ = 1.05 AU + softplus(rₖ) (> the observer's
# distance, so the crossing exists), started at 1.5 AU. Needs heliocentric inputs; the last SIX input features must be
# n̂·x̂, n̂·ŷ, n̂·ẑ, S·x̂, S·ŷ, S·ẑ (FEATURE_SETS[:sunseason_learnband_plx]); only the 3 profiles are passed on.
struct BandLayerPLX{V}
    i::V; Ω::V; logδζ::V; vraw::V; rraw::V
    μn::Vector{Float32}; σn::Vector{Float32}           # standardisation of the last 6 inputs (fixed)
end
Flux.@layer BandLayerPLX trainable=(i, Ω, logδζ, vraw, rraw)
const PLX_R0 = 1.5
function BandLayerPLX(μn, σn; init=KELSALL_BANDS, R0=PLX_R0)
    f(x) = Float32.(collect(x))
    BandLayerPLX(f(deg2rad.(init.i)), f(deg2rad.(init.Ω)), f(log.(deg2rad.(init.δζ))), f(softplus_inv.(init.v)),
                 f(fill(softplus_inv(R0 - 1.05), 3)), f(μn), f(σn))
end
function (b::BandLayerPLX)(x::AbstractMatrix)
    k = size(x, 1)
    raw = x[k-5:k, :] .* b.σn .+ b.μn
    n = raw[1:3, :]; O = raw[4:6, :]
    R = 1.05f0 .+ softplus.(b.rraw)                                       # 3 bands
    on = sum(n .* O, dims=1); oo = sum(O .* O, dims=1)                    # 1 × samples
    s = .-on .+ sqrt.(max.(on .^ 2 .- oo .+ R .^ 2, 1f-8))               # bands × samples
    N = vcat((sin.(b.i) .* sin.(b.Ω))', (-sin.(b.i) .* cos.(b.Ω))', cos.(b.i)')     # 3 × bands
    NO = N' * O; Nn = N' * n                                              # bands × samples
    ζ = (NO .+ s .* Nn) ./ R
    u = abs.(ζ) ./ exp.(b.logδζ)
    g = exp.(-u .^ 6) .* (softplus.(b.vraw) .+ u .^ 4)
    vcat(x[1:k-6, :], g)
end
band_params(b::BandLayerPLX) = (i=rad2deg.(b.i), Ω=mod.(rad2deg.(b.Ω), 360), δζ=rad2deg.(exp.(b.logδζ)), v=softplus.(b.vraw),
                                R=1.05 .+ softplus.(b.rraw))
function build_bandplx(n_in, hidden, rng, μn, σn; init=KELSALL_BANDS)
    Chain(BandLayerPLX(μn, σn; init), build_mlp(n_in - 3, hidden, rng))   # n_in − 6 inputs + 3 profiles
end
