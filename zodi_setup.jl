# ==============================================================================
# ZODI SETUP — environment, data, feature helpers, train/test splits
# Copy this whole cell into any notebook (or `include` this file).
# ==============================================================================

# --- Environment -------------------------------------------------------------
# Use the notebook's own folder if it has a data/ directory, otherwise fall back
# to the main More_zodi project so this cell works from any notebook.
PROJECT_DIR = isdir(joinpath(@__DIR__, "data")) ? (@__DIR__) : raw"C:\JuliaProjects\More_zodi"

import Pkg
Pkg.activate(PROJECT_DIR)
let needed = ["HDF5", "StatsBase", "CairoMakie", "NaNStatistics", "ProgressMeter", "ColorSchemes"]
    missing_pkgs = setdiff(needed, keys(Pkg.project().dependencies))
    isempty(missing_pkgs) || Pkg.add(missing_pkgs)
end
try
    Pkg.instantiate()
catch err   # e.g. "X is a direct dependency, but does not appear in the manifest"
    @warn "Pkg.instantiate failed — running Pkg.resolve() and retrying" exception = err
    Pkg.resolve()
    Pkg.instantiate()
end

using HDF5, StatsBase, Statistics, Random, CairoMakie, Printf
using NaNStatistics, ProgressMeter, ColorSchemes
black_latexfonts = merge(theme_black(), theme_latexfonts())
set_theme!(black_latexfonts)
CairoMakie.disable_mime!("svg", "pdf", "text/html")

# --- Data files --------------------------------------------------------------
DATA_DIR = joinpath(PROJECT_DIR, "data")
# Two deliveries of the mentor's pipeline files (same file names):
#   data/d140/  the first 140 days (423,607 exposures, Oct 2025 / Nov 2025) — everything up to Oct 19, 2026 uses these
#   data/       the 500-day delivery of Oct 19, 2026 (1,520,194 exposures; data/regen_pipeline.py: pointings from
#               IRSA spherex.obscore, so directions are image centres ≈ 3.85° from the old boresights, times 57.6 s later)
D140_DIR = joinpath(DATA_DIR, "d140")

# Which target to use (set ENV["ZODI_DATA"] BEFORE including this file; results live in sweeps/results_<name>/):
#   140-day data (data/d140/ pointings and vectors):
#     "original"  — the mentor's ZodiPy emission (has 2 generation errors, see zodipy_gen/reproduce_original.py)
#     "z115"      — the same exposures regenerated with ZodiPy 1.1.5 (zodipy_gen/generate.py)
#     "z115multi" — same exposures, each at one of 64 wavelengths 1.25–5.0 μm (zodipy_gen/generate_multi.py)
#   "z115year"    — a synthetic ~2.3-year survey (real mission + 5 rotated copies; zodipy_gen/generate_year.py)
#   500-day data (data/ pointings and vectors):
#     "d500"      — the mentor's ZodiPy emission for the 500 days (barycentric observer: ~2–3% too faint, error #1)
#     "z500"      — the 500 days regenerated with ZodiPy 1.1.5 (zodipy_gen/generate_500.py)
ZODI_DATA = get(ENV, "ZODI_DATA", "original")
if ZODI_DATA in ("original", "z115", "z115multi")
    isdir(D140_DIR) || error("ZODI_DATA = $ZODI_DATA needs the 140-day files in $D140_DIR (copy the backup of the old " *
                             "boresight_pointing.h5, spherex_vectors_bore_interpolated.h5 and the two spherex_zodipy_5um_* files there)")
    pointing_file = joinpath(D140_DIR, "boresight_pointing.h5")
    vectors_file  = joinpath(D140_DIR, "spherex_vectors_bore_interpolated.h5")
    allsky_file   = joinpath(D140_DIR, "spherex_zodipy_5um_boresight_healpix_components_interpolated.h5")
    emission_file = joinpath(D140_DIR, "spherex_zodipy_5um_boresight_interpolated.h5")
    if ZODI_DATA == "z115"
        allsky_file   = joinpath(DATA_DIR, "zodipy115_5um_healpix_components.h5")
        emission_file = joinpath(DATA_DIR, "zodipy115_5um_boresight.h5")
    elseif ZODI_DATA == "z115multi"
        allsky_file   = joinpath(DATA_DIR, "zodipy115_5um_healpix_components.h5")
        emission_file = joinpath(DATA_DIR, "zodipy115_multi_boresight.h5")
    end
elseif ZODI_DATA == "z115year"
    pointing_file = joinpath(DATA_DIR, "z115year_pointing.h5")
    vectors_file  = joinpath(DATA_DIR, "z115year_vectors.h5")
    allsky_file   = joinpath(DATA_DIR, "zodipy115_5um_healpix_components.h5")
    emission_file = joinpath(DATA_DIR, "z115year_boresight.h5")
elseif ZODI_DATA in ("d500", "z500")
    pointing_file = joinpath(DATA_DIR, "boresight_pointing.h5")
    vectors_file  = joinpath(DATA_DIR, "spherex_vectors_bore_interpolated.h5")
    allsky_file   = joinpath(DATA_DIR, "spherex_zodipy_5um_boresight_healpix_components_interpolated.h5")
    emission_file = joinpath(DATA_DIR, "spherex_zodipy_5um_boresight_interpolated.h5")
    if ZODI_DATA == "z500"
        allsky_file   = joinpath(DATA_DIR, "zodipy115_500d_healpix_components.h5")
        emission_file = joinpath(DATA_DIR, "zodipy115_500d_boresight.h5")
    end
else
    error("unknown ZODI_DATA = $ZODI_DATA (use \"original\", \"z115\", \"z115multi\", \"z115year\", \"d500\" or \"z500\")")
end
RESULTS_DIR = joinpath(PROJECT_DIR, "sweeps", ZODI_DATA == "original" ? "results" : "results_$ZODI_DATA")
println("target data: $ZODI_DATA  ($(basename(emission_file)));  results dir: $(relpath(RESULTS_DIR, PROJECT_DIR))")

# Where is SPHEREx looking?
nvec_unit_cartesian, ecliptic_longitude_deg, ecliptic_latitude_deg, times = h5open(pointing_file) do f
    read(f["pointing/nvec_unit_cartesian"]),     # 3 × N
    read(f["pointing/ecliptic_longitude_deg"]),
    read(f["pointing/ecliptic_latitude_deg"]),
    read(f["times/julian_date"])                 # Julian Date (days); NOT sorted
end

earth_positions, v_earth, jupiter_positions, spherex_positions, v_spherex, moon_positions =
    h5open(vectors_file) do f
        read(f["earth/positions"]),   read(f["earth/velocities"]),
        read(f["jupiter/positions"]),
        read(f["spherex/positions"]), read(f["spherex/velocities"]),
        read(f["moon/positions"])
    end

zhat_vec = zero(earth_positions); zhat_vec[3, :] .= 1.0
xhat_vec = zero(earth_positions); xhat_vec[1, :] .= 1.0
yhat_vec = zero(earth_positions); yhat_vec[2, :] .= 1.0

v_earth_unit   = v_earth   ./ sqrt.(sum(v_earth .^ 2, dims=1))
v_spherex_unit = v_spherex ./ sqrt.(sum(v_spherex .^ 2, dims=1))

# --- The target: Kelsall-model 5 μm emission along each boresight ---
y = h5open(emission_file) do f
    meta = attrs(f["metadata"])
    println("description: ", meta["description"])
    println("wavelength:  ", meta["wavelength"], " ", meta["wavelength_units"])
    println("units:       ", meta["emission_units"])
    read(f["emission"])            # MJy/sr, length N
end
N = length(y)
@assert size(nvec_unit_cartesian, 2) == size(spherex_positions, 2) == length(times) == N
# wavelength of each exposure (μm) and its channel: 5 μm everywhere except the multi-wavelength data
WAVE, CHANNEL = h5open(emission_file) do f
    haskey(f, "wavelength_um") ? (read(f["wavelength_um"]), read(f["channel"])) : (fill(5.0, N), fill(0, N))
end
println("N = $N exposures;  emission range = ", extrema(y))

# --- Feature helpers ---------------------------------------------------------
dot_prod_matrix(a, b) = dropdims(sum(a .* b, dims=1), dims=1)

# make_vectors(nvec, idx) — THE one place the model inputs are defined.
#   `nvec`: 3 × M pointing directions.  `idx`: indices into the per-exposure ephemeris
#   columns — use 1:N for the boresight data, or fill(t, M) to evaluate everything at
#   a single epoch t (used for the all-sky map at the end).
# Add a vector here and every model and validation downstream sees it automatically.
make_vectors(nvec, idx) = [
    "n"  => nvec,
    "S"  => spherex_positions[:, idx],
    "z"  => zhat_vec[:, idx],
    "E"  => earth_positions[:, idx],
    "vS" => v_spherex_unit[:, idx],
    "vE" => v_earth_unit[:, idx],
    "J"  => jupiter_positions[:, idx],
    "x"  => xhat_vec[:, idx],        # fixed in-plane inertial axes
    "y"  => yhat_vec[:, idx],
]

# all pairwise dot products among the registered vectors
function dot_features(vecs)
    names, cols = String[], Vector{Float64}[]
    for i in eachindex(vecs), j in i:length(vecs)
        push!(names, string(first(vecs[i]), "·", first(vecs[j])))
        push!(cols, dot_prod_matrix(last(vecs[i]), last(vecs[j])))
    end
    return names, reduce(hcat, cols)
end

# all squares and pairwise products of (already standardized) features —
# the hand-made curvature for the linear-plus-quadratic model
function quadratic_terms(names, D)
    qnames, qcols = String[], Vector{Float64}[]
    for i in axes(D, 2), j in i:size(D, 2)
        push!(qnames, i == j ? "($(names[i]))²" : "($(names[i]))($(names[j]))")
        push!(qcols, D[:, i] .* D[:, j])
    end
    return qnames, reduce(hcat, qcols)
end

# a first look at the raw dot products and their spread
dot_names_all, Fd_raw = dot_features(make_vectors(nvec_unit_cartesian, 1:N))
for (nm, i) in zip(dot_names_all, axes(Fd_raw, 2))
    @printf("%-6s  median %10.3e   iqr %10.3e\n", nm, median(Fd_raw[:, i]), iqr(Fd_raw[:, i]))
end

# --- Train/test splits (all chronological except the random one) ------------
# The rows are NOT in time order and times[1] is not the earliest exposure, so
# time_days (same convention as the file's times/days_since_start) runs from
# about -6.2 to +133.5. Splits use t_rel, measured from the first exposure.
time_days = times .- times[1]
t_rel     = time_days .- minimum(time_days)    # 0 → ~139.7 days
c_idx     = sortperm(time_days)                # row indices in chronological order
span_days = maximum(t_rel)

chrono_split(frac) = (k = floor(Int, frac * N); (c_idx[1:k], c_idx[k+1:N]))

# alternate fixed-length time windows train/test/train/... (by actual days, not row count)
function alternating_time_split(window_days)
    blk = floor.(Int, t_rel ./ window_days)    # 0, 1, 2, ... → train, test, train, ...
    (findall(iseven, blk), findall(isodd, blk))
end

rng = Xoshiro(2026)
train_idx_rnm = sort(sample(rng, 1:N, N ÷ 2, replace=false))
test_idx_rnm  = setdiff(1:N, train_idx_rnm)

# middle 50% of exposures (chronologically) held out, outer 50% trained on
p1, p2 = floor(Int, 0.25N), floor(Int, 0.75N)
train_idx_mid = vcat(c_idx[1:p1], c_idx[p2+1:N])
test_idx_mid  = c_idx[p1+1:p2]

splits = Dict(
    "75/25 Chronological" => chrono_split(0.75),
    "50/50 Chronological" => chrono_split(0.50),
    "25/75 Chronological" => chrono_split(0.25),
    "80/20 Chronological" => chrono_split(0.80),
    "85/15 Chronological" => chrono_split(0.85),
    "random split"        => (train_idx_rnm, test_idx_rnm),
    "30 day split"        => alternating_time_split(30.0),
    "7-day alternating"   => alternating_time_split(7.0),
    "50/50 mid-mission"   => (train_idx_mid, test_idx_mid),
)

@printf("\nMission span: %.1f days\n", span_days)
for name in sort(collect(keys(splits)))
    tr, te = splits[name]
    @assert isempty(intersect(tr, te)) && length(tr) + length(te) == N
    @printf("%-20s train %7d   test %7d   (%.0f%% train)\n", name, length(tr), length(te), 100length(tr) / N)
end
println("All splits initialized.")
