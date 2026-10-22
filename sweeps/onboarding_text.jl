# Cell contents for ZodiOnboarding.ipynb (project root) — the orientation notebook for More_zodi, matching
# ExoOnboarding / SolOnboarding in the user's other projects.   julia sweeps/build_nb.jl sweeps/onboarding_text.jl ./ZodiOnboarding.ipynb
CELLS = Pair{String,String}[

"markdown" => raw"""
# Onboarding: a geometrically constrained neural network for SPHEREx zodiacal light

This notebook is the orientation for the `More_zodi` project. Read it top to bottom once; every code cell is light
(seconds) and nothing here trains a model. Details live in the dated notebooks (`notebooks/`, one per working day) and
`STATUS.md`.

| Part | What you get |
|---|---|
| 1. Why this matters | SPHEREx, zodiacal light, and why it must be removed |
| 2. The data | Pointings, ephemerides, the ZodiPy (Kelsall) targets; 140-day vs 500-day deliveries; known data issues |
| 3. The ML problem | Inputs as dot products, the splits, what "never seen" means |
| 4. The model | Architecture, training recipe, ensembles, heliocentric inputs |
| 5. Results so far | Tables and figures from `sweeps/` and `figures/` |
| 6. Kinks to work out | Honest limitations, ranked |
| 7. Future work | Projects that need your decisions, and topics I can walk you through |
| 8. Glossary | |

Run the setup cell first. It activates this project's environment, the same pattern as your other projects.
""",

"code" => raw"""
import Pkg; Pkg.activate(@__DIR__)
using HDF5, Statistics, Printf, CairoMakie
const ROOT = @__DIR__
const DATA = joinpath(ROOT, "data"); const FIG = joinpath(ROOT, "figures")
showpng(f) = CairoMakie.Makie.FileIO.load(isabspath(f) ? f : joinpath(FIG, f))
println("project: ", ROOT)
""",

"markdown" => raw"""
## 1. Why this matters
* **SPHEREx** (NASA, launched March 2025) maps the entire sky in 102 infrared colours from 0.75 to 5 μm, to study how the
  universe began (inflation), how galaxies formed, and where water and other ices are found.
* **Zodiacal light** is sunlight scattered by interplanetary dust (from comets and asteroids) plus the dust's own heat
  glow. At SPHEREx wavelengths it is far brighter than the faint combined glow of distant galaxies that SPHEREx wants to
  measure, so it must be modelled and removed from every image, with sub-percent accuracy.
* The standard model is **Kelsall et al. (1998)**, fit to COBE/DIRBE data: a smooth cloud, three dust bands, a
  circumsolar ring and a blob trailing Earth. It uses a finite number of analytic components that do not fully describe
  the spatial and spectral structure of the real sky.
* **The research goal:** a *geometrically constrained* neural network that learns the zodiacal light from SPHEREx data
  and outperforms Kelsall. **First step (done):** learn ZodiPy's simulated Kelsall sky from geometry alone, to ~0.02%.
""",

"markdown" => raw"""
## 2. The data
Everything is in `data/` (not in git; `data/MANIFEST.tsv` has the checksums — `julia --project=. data_manifest.jl`).
Three kinds of file per delivery:

| file | contents |
|---|---|
| `boresight_pointing.h5` | where SPHEREx pointed: unit vectors n̂ (ecliptic frame), ecliptic lon/lat, times (JD) |
| `spherex_vectors_bore_interpolated.h5` | positions and velocities of SPHEREx, Earth, Moon, Jupiter at each pointing (**barycentric** ecliptic, AU) |
| `spherex_zodipy_5um_boresight_interpolated.h5` | the mentor's ZodiPy (Kelsall) 5 μm brightness along each pointing, MJy/sr |
| `…healpix_components_interpolated.h5` | an all-sky map at one epoch, split into Kelsall's components |

**Two deliveries.** `data/d140/` = the first 140 days (423,607 pointings, Oct–Nov 2025). `data/` = the 500-day delivery
of Oct 19, 2026 (1,520,194 pointings; `data/regen_pipeline.py`: pointings from the public IRSA archive, so directions
are image centres ≈ 3.85° from the old boresights). It contains the first 140 days too.

**Known data issues (found here, worth knowing):** the mentor's ZodiPy files pass SPHEREx's *barycentric* position where
ZodiPy expects a *heliocentric* one (~2–3% too faint), and the 140-day file evaluated ZodiPy in file order rather than time
order (late data off by up to 6%). So the targets were regenerated: `zodipy_gen/generate.py` (140 d → `ZODI_DATA="z115"`)
and `zodipy_gen/generate_500.py` (500 d → `"z500"`), with all six Kelsall components stored per pointing.
""",

"code" => raw"""
let
    for (lbl, dir, tgt) in (("140 days", joinpath(DATA, "d140"), "zodipy115_5um_boresight.h5"), ("500 days", DATA, "zodipy115_500d_boresight.h5"))
        jd = h5open(f -> read(f["times/julian_date"]), joinpath(dir, "boresight_pointing.h5"))
        y = h5open(f -> read(f["emission"]), joinpath(DATA, tgt))
        @printf("%-9s %9d pointings over %6.1f days; corrected 5 μm target %.2f–%.2f MJy/sr (median %.3f)\n",
                lbl, length(jd), maximum(jd) - minimum(jd), extrema(y)..., median(y))
    end
end
""",

"markdown" => raw"""
What the Kelsall brightness looks like over the whole sky at one moment, and what makes it up (smooth cloud ~90–95%;
the rest is dust bands, the ring, and the trailing blob, which is 5–9% when looking behind Earth):
""",

"code" => raw"""
showpng(joinpath(ROOT, "poster", "fig", "sky_dark.png"))
""",

"markdown" => raw"""
## 3. The ML problem
**Inputs: geometry only, as dot products.** The network never sees a date or a sky coordinate. Its 9 inputs are dot
products of the pointing vector n̂ with the directions that shape the zodiacal light, plus Earth's place in its orbit
(this follows the mentor's onboarding notebook, `C:\JuliaProjects\zodi_onboarding_bundle\`):

| input | meaning |
|---|---|
| n̂·S, n̂·E | toward/away from the Sun, seen from SPHEREx (S) and from Earth (E) |
| n̂·ẑ | how far above or below the plane of the planets |
| n̂·v̂S, n̂·v̂E | ahead of or behind the orbital motion |
| n̂·x̂⊕, n̂·ŷ⊕ | the ecliptic x̂, ŷ axes rotated by Earth's longitude λ⊕ (x̂⊕ = Sun → Earth, ŷ⊕ = Earth's motion) |
| sin λ⊕, cos λ⊕ | the time of year (Earth's orbital phase) |

Defined in one place: `zodi_setup.jl` (`make_vectors`) and `sweeps/extra_features.jl` (`FEATURE_SETS[:sunframe_season]`).

**Splits: what "never seen" means.** A random split is easy (neighbouring exposures are seconds apart). The real test is
**whole months withheld**: alternating 30-day windows train / test, shifted by 0, 10, …, 50 days so every pointing is
tested by networks that never saw its month. Windows at the very start/end of the data test *extrapolation in time* and
are reported separately. The out-of-sample **sky map** combines all shifts.
""",

"markdown" => raw"""
## 4. The model
* **Network:** fully connected 9 → 64 → 64 → 32 → 16 → 1 (≈7,400 parameters), GELU, linear output in MJy/sr.
* **Training:** Adam on MSE, mini-batches of 512, one-cycle learning rate (warm-up from 4e-5 to a peak of 1e-3 at 30% of
  training, then annealed to 1e-7), 500–750 epochs (`sweeps/mb_train.jl`; configs in `sweeps/configs_v*.jl`; parallel
  runs with `julia -t 5 --project=. sweeps/run_threaded.jl <config>`).
* **Ensemble:** 5 networks with different seeds; predictions are averaged.
* **Heliocentric inputs (Oct 21):** positions are measured from the **Sun** (the Sun's barycentric position,
  `zodipy_gen/sun_positions.py`, is subtracted) — the default for the 500-day data (`ENV["ZODI_HELIO"]`). The dust cloud
  is Sun-centred; the Sun moves 0.0035 AU about the barycentre over 500 days.
""",

"code" => raw"""
showpng("10192026_model_card.png")
""",

"markdown" => raw"""
## 5. Results so far
Errors are relative to ZodiPy (the Kelsall model), on pointings the networks never saw.

| model | data | median | p95 | within 2° of the ecliptic |
|---|---|---|---|---|
| poster model (barycentric, 750 epochs) — poster, final | 140 days | 0.016% | 0.063% | 0.083% |
| + n·J, barycentric, 500 epochs (round 24) | 500 days | 0.016% | 0.053% | 0.064% |
| **heliocentric, no n·J (rounds 27–29)** | 500 days | **0.016%** | **0.053%** | **0.048%** |

Main lessons: the time-of-year inputs cut the errors 40–65× (Oct 9); longer training helps up to ~750 epochs; on 500
days n·J helped only because the inputs were barycentric (it stood in for the Sun's wobble) and adds nothing once they
are heliocentric (the mentor's Jupiter null test); the Earth-trailing cloud is learned (mentor's tests, Oct 20).
""",

"code" => raw"""
showpng("10212026_skymap_helio.png")
""",

"markdown" => raw"""
## 6. Kinks to work out (most important first)
1. **Simulated data only.** Everything so far emulates ZodiPy's Kelsall model; the real goal is real SPHEREx images
   (stars, Earthshine/stray light, the Moon, calibration, per-pixel pointing).
2. **The ecliptic stripe** (dust bands) is the largest remaining error (~0.05%). Kelsall's fixed band shapes fix it but
   import the simulator's answer; the plan is to *learn* the band parameters.
3. **Extrapolation in time:** predictions beyond ~10 days past the training data degrade; train on data that brackets
   the period to model.
4. **One wavelength.** Results are at 5 μm; a first 1.25–5 μm version reached ~0.1%.
5. **Outside SPHEREx's geometry** (e.g. near the Sun) the network is untested and should not be trusted.

## 7. Future work
### 7a. Projects that need your decision
* Learnable dust-band layer (band widths, tilts, nodes fitted with the network, started from Kelsall's values).
* The mentor's Earth-centric terms for real data: n̂·δ̂ with δ = S − E (Earth-limb direction, Earthshine) and the Moon's
  direction, checked first as a null on simulated data.
* A one-at-a-time input-removal (ablation) table; output positivity; ensemble spread off the training geometry.
* Moving training to a computing cluster; the real-data pipeline (`pipeline/`).

### 7b. Things I can walk you through (no decision needed, just ask)
How the targets were regenerated and why; how the splits and sky maps are built; the barycentric-vs-heliocentric finding;
the trailing-cloud tests; reading the loss curves; the poster build (`poster/build_poster.py`).

## 8. Glossary
* **Zodiacal light** — sunlight scattered (and heat re-emitted) by interplanetary dust.
* **Kelsall model / ZodiPy** — the standard 1998 dust model, and the Python package that evaluates it.
* **Pointing vector n̂** — the unit vector of where SPHEREx looks.
* **Barycentric / heliocentric** — measured from the solar system's centre of mass / from the Sun.
* **λ⊕** — Earth's ecliptic longitude (its angle around its orbit, the time of year).
* **Epoch** — one pass through the training data. **Ensemble** — several networks averaged.
* **Month split / shift** — alternating 30-day train/test windows, slid by Δ days.
* **p95** — 95% of errors are smaller than this.
""",
]
