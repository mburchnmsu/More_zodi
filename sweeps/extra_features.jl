# Extra feature columns appended to Fd_raw / dot_names_all, and named feature sets.
# All extras are computed by ONE function, `extra_columns(nvec, idx)`, so training rows and the
# all-sky map (nvec = pixel directions, idx = fill(TINDX, npix)) use identical definitions.
#
# n·δ̂     : boresight · Earth→SPHEREx direction (δ = S − E, the LEO offset). Earth's centre lies along −δ̂.
#           Cycles every ~94-min orbit. SPHEREx always points ≥139° from Earth → n·δ̂ ∈ [0.76, 1] in training.
# n·Ĵfix  : boresight · Jupiter's MISSION-MEAN direction (a fixed inertial axis; ecliptic lon ≈ 94°, so ≈ n·y)
# n·Ĵ     : boresight · Jupiter's CURRENT direction (unit vector; drifts 88°→100° in longitude over the mission)
# n·Ĵ⊥fix : boresight · fixed in-plane axis 90° ahead of Ĵfix (≈ −n·x) — a control axis unrelated to Jupiter
using Random
δ_vec  = spherex_positions .- earth_positions
δ_unit = δ_vec ./ sqrt.(sum(δ_vec .^ 2, dims=1))
J_unit = jupiter_positions ./ sqrt.(sum(jupiter_positions .^ 2, dims=1))
J_fix  = (m = vec(mean(J_unit, dims=2)); m ./ sqrt(sum(abs2, m)))
J_perp = (p = [-J_fix[2], J_fix[1], 0.0]; p ./ sqrt(sum(abs2, p)))

# Round 6 (Earth-centric control and Jupiter null controls):
# n·δ       : boresight · RAW LEO offset δ = S − E (AU, ≈5e-5) — the onboarding's Earth-centric switch (n·S → n·E + n·δ)
# n·Jrot45  : boresight · Jupiter's position rotated +45° about the ecliptic pole — a "fake planet" with exactly
#             Jupiter's motion (same 12° drift, same distance) seen from a different direction
# n·Jrot90  : same, rotated +90°
# n·Jrot180 : same, rotated 180° — kept only to SHOW it is ≈ −n·J (an in-plane vector rotated 180° is its negative)
# n·Jscr    : Jupiter's position at a RANDOMLY SHUFFLED exposure time — same values as n·J, no link to time
Rz(θ) = [cosd(θ) -sind(θ) 0; sind(θ) cosd(θ) 0; 0 0 1]
J_rot45, J_rot90, J_rot180 = Rz(45) * jupiter_positions, Rz(90) * jupiter_positions, Rz(180) * jupiter_positions
const J_SCRAMBLE = randperm(Xoshiro(2026), N)
J_scr = jupiter_positions[:, J_SCRAMBLE]

# Round 7 (season): Earth's ecliptic longitude λ⊕ (from Earth's barycentric position; the Sun–barycentre offset
# shifts it by < 0.3°) as sin/cos — the orbital phase / time of year, periodic over one year.
λE_deg = mod.(atand.(earth_positions[2, :], earth_positions[1, :]), 360)

# Round 9 (dust bands): Kelsall (1998) band planes and vertical band shape. ZodiPy/Kelsall band density
#   n_B ∝ (1/R) · exp(−u⁶) · (v + u⁴) · [1 − exp(−(R/δR)²⁰)],   u = ζ/δζ,  ζ = |Z_B|/R  (Z_B = height above band plane)
# The profile g(u) = exp(−u⁶)(v + u⁴) is a sharp double hump peaking at ζ ≈ ±0.8 δζ (band 2: ±1.6°).
# A plain band-plane normal n·n̂_B is an EXACT linear combination of n·x, n·y, n·z (checked to 1e-15), so it adds nothing;
# these features put the band's sharp NONLINEAR shape in directly.
#   bandK      : g(|n·n̂_B| / δζ)            — band latitude as seen from SPHEREx (no parallax), fixed on the sky
#   bandK@R    : g(|ζ(R)| / δζ)             — parallax version: ζ at the point where the line of sight crosses heliocentric
#                distance R (R > observer's ≈1 AU, so it is crossed exactly once). Uses SPHEREx's barycentric position as
#                heliocentric (Sun–barycentre offset ≈ 0.007 AU, nearly in-plane → < 0.01° error in ζ).
const BANDS = [(name="band1", δζ=8.78, v=0.10, p=4.0, i=0.56, Ω=80.0,   δR=1.5),
               (name="band2", δζ=1.99, v=0.90, p=4.0, i=1.2,  Ω=30.347, δR=0.94),
               (name="band3", δζ=15.0, v=0.05, p=4.0, i=0.8,  Ω=80.0,   δR=1.5)]
# AU. Chosen by a scan of R = 1.05…3 AU against ZodiPy's per-band all-sky maps (epoch 13170): Spearman with the true band
# component peaks at R ≈ 1.25–1.6 (band1 0.89, band3 0.94; band2 only ≈ 0.6 — its inner edge δR = 0.94 AU is right at Earth)
const BAND_RADII = (1.25, 1.5, 2.0)
band_normal(b) = [sind(b.i) * sind(b.Ω), -sind(b.i) * cosd(b.Ω), cosd(b.i)]
band_profile(b, ζ) = (u = abs(ζ) / deg2rad(b.δζ); exp(-u^6) * (b.v + u^b.p))
function band_parallax_ζ(nvec, O, nb, R)                          # ζ = Z_B/R at |O + s n| = R, s > 0
    on = dot_prod_matrix(nvec, O); oo = vec(sum(abs2, O, dims=1))
    s = -on .+ sqrt.(on .^ 2 .- oo .+ R^2)
    (vec(nb' * O) .+ s .* vec(nb' * nvec)) ./ R
end
const BAND_SHARP_NAMES = ["$(b.name)" for b in BANDS]
const BAND_PLX_NAMES   = ["$(b.name)@$(R)" for b in BANDS for R in BAND_RADII]
band_columns(nvec, idx) = hcat([band_profile.(Ref(b), asin.(clamp.(vec(band_normal(b)' * nvec), -1, 1))) for b in BANDS]...,
                               [band_profile.(Ref(b), band_parallax_ζ(nvec, spherex_positions[:, idx], band_normal(b), R))
                                for b in BANDS for R in BAND_RADII]...)

# Round 11 (Sun-frame features, for extrapolation in time). Zodi brightness depends on the geometry RELATIVE TO THE SUN
# (which turns with Earth over the year) plus the cloud's small inertial tilt/offset. n·x, n·y (and n·J) are inertial, so a
# new time of year means new values. Instead:
#   n·x⊕, n·y⊕ : pointing in the frame rotated by Earth's longitude λ⊕ (x⊕ = Sun→Earth direction in the ecliptic, y⊕ ahead)
#   n·ĉ        : pointing · the smooth cloud's symmetry-plane normal (Kelsall: i = 2.03°, Ω = 77.7°) — a fixed inertial axis
#   Zc, Rc     : SPHEREx's height above the cloud's symmetry plane and its distance from the cloud centre (AU; Kelsall
#                offset X0 = (0.0119, 0.00548, −0.00215) AU from the Sun ≈ barycentre to < 0.01 AU)
# Zc/Rc/n·ĉ carry the season information through quantities whose values recur every year and that the mission mostly
# covers (Zc: Earth crosses the cloud plane twice a year), unlike sin/cos λ⊕ which the mission sees for only ~38% of the circle.
const CLOUD_I, CLOUD_Ω = 2.0335188072390769, 77.657955554097114     # = zodipy/component_params.py (DIRBE cloud)
const CLOUD_N  = [sind(CLOUD_I) * sind(CLOUD_Ω), -sind(CLOUD_I) * cosd(CLOUD_Ω), cosd(CLOUD_I)]
const CLOUD_X0 = [0.011887800744346281, 0.0054765064662263777, -0.0021530908020710744]
const SUNFRAME_NAMES = ["n·x⊕", "n·y⊕", "n·ĉ", "Zc", "Rc"]
function sunframe_columns(nvec, idx)
    λ = λE_deg[idx]; Sx = spherex_positions[:, idx] .- CLOUD_X0
    hcat(cosd.(λ) .* nvec[1, :] .+ sind.(λ) .* nvec[2, :],          # n · (cos λ, sin λ, 0)
         -sind.(λ) .* nvec[1, :] .+ cosd.(λ) .* nvec[2, :],         # n · (−sin λ, cos λ, 0)
         vec(CLOUD_N' * nvec), vec(CLOUD_N' * Sx), vec(sqrt.(sum(abs2, Sx, dims=1))))
end

# Round 13 (multi-wavelength): log10 of the exposure's wavelength in μm (WAVE from zodi_setup.jl; 5 μm for the 5-μm data)
# Round 14: ZodiPy takes the Kelsall phase-function coefficients C1–C3 from the NEAREST DIRBE band (zodipy/unpack_model.py,
# use_nearest=True) → steps in the spectrum at 1.725, 2.85 and 4.2 μm. phC1–3 hand the network those coefficients.
const DIRBE_BANDS = [1.25, 2.2, 3.5, 4.9]
const PHASE_C = [-0.94209999 0.1214 -0.1648; -0.52670002 0.18719999 -0.59829998; -0.4312 0.1715 -0.63330001; 0.0 0.0 0.0]
phase_coeffs(λ) = PHASE_C[argmin(abs.(DIRBE_BANDS .- λ)), :]          # nearest band, as ZodiPy (valid for λ ≤ 8.45 μm)
# Round 15: the thermal part rises like a blackbody's Wien tail toward 5 μm. logB250/logB300 = log10 of the Planck
# function B_λ(T) at T = 250 / 300 K (typical dust temperatures near 1 AU), relative to its value at 5 μm.
logplanck(λ, T) = (c2 = 14387.77; -5log10(λ) - log10(expm1(c2 / (λ * T))))             # λ in μm; c2 = hc/k in μm·K
logB_rel(λ, T) = logplanck(λ, T) - logplanck(5.0, T)
const EXTRA_NAMES = ["n·δ̂", "n·Ĵfix", "n·Ĵ", "n·Ĵ⊥fix", "n·δ", "n·Jrot45", "n·Jrot90", "n·Jrot180", "n·Jscr",
                     "sinλE", "cosλE", BAND_SHARP_NAMES..., BAND_PLX_NAMES..., SUNFRAME_NAMES..., "logλ", "phC1", "phC2", "phC3",
                     "logB250", "logB300"]
extra_columns(nvec, idx) = hcat(dot_prod_matrix(nvec, δ_unit[:, idx]),
                                vec(J_fix' * nvec),
                                dot_prod_matrix(nvec, J_unit[:, idx]),
                                vec(J_perp' * nvec),
                                dot_prod_matrix(nvec, δ_vec[:, idx]),
                                dot_prod_matrix(nvec, J_rot45[:, idx]),
                                dot_prod_matrix(nvec, J_rot90[:, idx]),
                                dot_prod_matrix(nvec, J_rot180[:, idx]),
                                dot_prod_matrix(nvec, J_scr[:, idx]),
                                sind.(λE_deg[idx]), cosd.(λE_deg[idx]),
                                band_columns(nvec, idx),
                                sunframe_columns(nvec, idx),
                                log10.(WAVE[idx]),
                                permutedims(reduce(hcat, phase_coeffs.(WAVE[idx]))),
                                logB_rel.(WAVE[idx], 250.0), logB_rel.(WAVE[idx], 300.0))
if !("n·δ̂" in dot_names_all)
    global Fd_raw = hcat(Fd_raw, extra_columns(nvec_unit_cartesian, 1:N))
    append!(dot_names_all, EXTRA_NAMES)
end

const LOOK_DIR = filter(nm -> startswith(nm, "n·") && nm != "n·n" && !(nm in EXTRA_NAMES), dot_names_all)
swapJ(new) = [nm == "n·J" ? new : nm for nm in LOOK_DIR]
const FEATURE_SETS = Dict(
    :look_dir       => LOOK_DIR,                          # n·S n·z n·E n·vS n·vE n·J n·x n·y
    :look_dir_dhat  => vcat(LOOK_DIR, "n·δ̂"),
    :look_dir_noJ   => filter(!=("n·J"), LOOK_DIR),
    :look_dir_Jfix  => swapJ("n·Ĵfix"),                   # n·J → fixed Jupiter axis
    :look_dir_Junit => swapJ("n·Ĵ"),                      # n·J → moving Jupiter direction (no distance)
    :look_dir_Jperp => swapJ("n·Ĵ⊥fix"),                  # n·J → fixed axis 90° from Jupiter (control)
    # round 6
    :earth_centric  => [nm == "n·S" ? "n·δ" : nm for nm in LOOK_DIR],   # n·S → n·δ (n·E already present)
    :look_dir_Jrot45 => swapJ("n·Jrot45"),                # time-matched fake planets
    :look_dir_Jrot90 => swapJ("n·Jrot90"),
    :look_dir_Jscr   => swapJ("n·Jscr"),                  # time-scrambled Jupiter
    # round 7
    :look_dir_season => vcat(LOOK_DIR, "sinλE", "cosλE"), # + Earth's orbital phase
    # round 9 (dust bands, on top of the season model)
    :season_bandsharp => vcat(LOOK_DIR, "sinλE", "cosλE", BAND_SHARP_NAMES),                    # +3 sharp profiles
    :season_bandplx   => vcat(LOOK_DIR, "sinλE", "cosλE", BAND_PLX_NAMES),                      # +9 parallax profiles
    :season_bandboth  => vcat(LOOK_DIR, "sinλE", "cosλE", BAND_SHARP_NAMES, BAND_PLX_NAMES),    # +12
    # the pipeline test found the season model leans on n·vS (SPHEREx's orbital-velocity direction; Kelsall has no
    # velocity dependence) — control: drop it
    :season_novS      => filter(!=("n·vS"), vcat(LOOK_DIR, "sinλE", "cosλE")),
    # round 10 (extrapolation in time): Jupiter is a slow clock (10/08) — does dropping it help beyond the mission?
    :season_noJ       => filter(!=("n·J"), vcat(LOOK_DIR, "sinλE", "cosλE")),
    # round 11 (Sun frame): Sun-relative inputs only — no inertial n·x, n·y, no Jupiter
    :sunframe         => ["n·S", "n·z", "n·E", "n·vS", "n·vE", "n·x⊕", "n·y⊕"],
    :sunframe_season  => ["n·S", "n·z", "n·E", "n·vS", "n·vE", "n·x⊕", "n·y⊕", "sinλE", "cosλE"],
    # round 24 (500-day data): the poster model + Jupiter's direction (Jupiter-associated dust matters for real data)
    :sunseason_J      => ["n·S", "n·z", "n·E", "n·vS", "n·vE", "n·x⊕", "n·y⊕", "sinλE", "cosλE", "n·J"],
    # round 22: the poster model + the round-9 sharp dust-band profiles (target: the ecliptic stripe)
    :sunseason_bandsharp => vcat(["n·S", "n·z", "n·E", "n·vS", "n·vE", "n·x⊕", "n·y⊕", "sinλE", "cosλE"], BAND_SHARP_NAMES),
    :sunframe_cloud   => ["n·S", "n·z", "n·E", "n·vS", "n·vE", "n·x⊕", "n·y⊕", "n·ĉ", "Zc", "Rc"],
    # Rc leaves the mission's range for ~half the year (the mission never got near perihelion); Zc only for ~20%
    :sunframe_cloudZ  => ["n·S", "n·z", "n·E", "n·vS", "n·vE", "n·x⊕", "n·y⊕", "n·ĉ", "Zc"],
    # round 13 (multi-wavelength): the recommended inputs (and the old season model) + log10 wavelength
    :sunseason_lambda => ["n·S", "n·z", "n·E", "n·vS", "n·vE", "n·x⊕", "n·y⊕", "sinλE", "cosλE", "logλ"],
    :season_lambda    => vcat(LOOK_DIR, "sinλE", "cosλE", "logλ"),
    # round 14: + ZodiPy's (nearest-band) phase-function coefficients
    :sunseason_lambda_phase => ["n·S", "n·z", "n·E", "n·vS", "n·vE", "n·x⊕", "n·y⊕", "sinλE", "cosλE", "logλ", "phC1", "phC2", "phC3"],
    # round 15: + blackbody shape
    :sunseason_lambda_phase_bb => ["n·S", "n·z", "n·E", "n·vS", "n·vE", "n·x⊕", "n·y⊕", "sinλE", "cosλE", "logλ", "phC1", "phC2", "phC3",
                                   "logB250", "logB300"],
)
