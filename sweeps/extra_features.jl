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

const EXTRA_NAMES = ["n·δ̂", "n·Ĵfix", "n·Ĵ", "n·Ĵ⊥fix", "n·δ", "n·Jrot45", "n·Jrot90", "n·Jrot180", "n·Jscr",
                     "sinλE", "cosλE", BAND_SHARP_NAMES..., BAND_PLX_NAMES...]
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
                                band_columns(nvec, idx))
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
)
