# Cell contents for 10142026.ipynb — corrected simulated data + extrapolation in time.
CELLS = Pair{String,String}[

"markdown" => raw"""
# Corrected simulated data and extrapolation in time (Oct 13–14, 2026)

ZodiPy 1.1.5 is now installed (separate conda environment `zodipy`, see `zodipy_gen/`). Checking it against our data
turned up two errors in how the **original** simulated data were made, so this notebook has three parts:

* **A.** What is wrong with the original data, shown by reproducing it exactly.
* **B.** Corrected data (regenerated with ZodiPy): do the earlier conclusions still hold? Same tests, same recipe.
* **C.** **Extrapolation in time**: train on the whole 140-day mission and predict the same survey pattern up to
  1.5 years later.

Everything here uses the corrected data (`ENV["ZODI_DATA"] = "z115"`, results in `sweeps/results_z115/`). The original
files and every earlier result and notebook are unchanged.

### Summary
* **The original simulated data had two generation errors** (wrong observer origin; Earth's position extrapolated after
  mission day ~58). They put the data off by −6% to +4.6%, worst at the end of the mission. ZodiPy reproduces the
  original data to 3e-7 when it makes the same two mistakes.
* **On corrected data every earlier conclusion holds, and the numbers improve.** Season model, 30-day blocks: median
  0.024% (was 0.0325%). 80/20 chronological: p95 0.67% (was 1.04%), MSE 4× lower.
* **Extrapolation in time (trained on the 140-day mission):** the season model degrades to ~3% half a year later. The
  sin/cos λ⊕ inputs leave the training range for 60% of the year, and n·J acts as a clock.
* **Sun-frame inputs fix most of it.** Pointing measured from the Sun–Earth line instead of fixed x/y axes, no Jupiter,
  plus the season (**Sun frame + sin/cos λ⊕**, 9 inputs): worst case over the next 18 months **0.84%** (season model
  3.0%), back to 0.12% a year later. Inside the mission it is at least as accurate (MSE 0.87× the season model).
* **With a full year of training data** (simulated), Sun frame + sin/cos λ⊕ predicts the following 16 months at
  **0.10%** median, vs 0.024% on the training year. The season model with n·J gets 0.33%.
""",

"code" => raw"""
ENV["ZODI_DATA"] = "z115"          # corrected target; remove this line to get the original data back
include(joinpath(@__DIR__, "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl", "extra_splits.jl", "nb_verify_fns.jl", "summary_helpers.jl", "z115_helpers.jl")
    include(joinpath(@__DIR__, "sweeps", f))
end
include(joinpath(@__DIR__, "pipeline", "ZodiPipeline.jl")); using .ZodiPipeline
""",

"markdown" => raw"""
## A. What is wrong with the original data
`zodipy_gen/reproduce_original.py` reproduces `spherex_zodipy_5um_boresight_interpolated.h5` to **3e-7** (rounding
level) with ZodiPy's Kelsall/DIRBE model at 5 μm when it makes two mistakes:

1. **Observer position.** SPHEREx's position relative to the solar-system **barycentre** was passed to ZodiPy, which
   expects a position relative to the **Sun**. The Sun is ~0.007 AU from the barycentre, so the observer sits in the
   wrong place → the original is **~2–3% too faint** everywhere.
2. **Earth extrapolated.** All exposures went through ZodiPy in **one batch in file order**. ZodiPy fits Earth's orbit
   with a spline between the *first and last times of the batch*. The file is not time-sorted: it starts at mission day
   6.2 and ends at day 57.8, so for every exposure outside that window Earth's position was **extrapolated**. Earth's
   position places the **circumsolar ring** and the **Earth-trailing blob**:

| mission day | 70 | 82 | 94 | 106 | 118 | 130 |
|---|---|---|---|---|---|---|
| error in "Earth" (AU) | 2e-4 | 2e-3 | 0.01 | 0.03 | 0.06 | 0.12 |
| error in Earth's longitude | 0.005° | 0.04° | 0.23° | 0.85° | 2.4° | 5.6° |

The corrected data (`zodipy_gen/generate.py`) use SPHEREx's heliocentric position and Earth's true position for every
exposure (de432s ephemeris; checked to agree with our vectors file to 1e-6 AU). (The logs below count days from the
file's `days_since_start`, which is mission day − 6.23.)
""",

"code" => raw"""
for f in ("reproduce_original.log", "generate.log")
    println("── zodipy_gen/$f"); foreach(println, readlines(joinpath(@__DIR__, "zodipy_gen", f)))
end
""",

"code" => raw"""
data_compare_fig()
""",

"markdown" => raw"""
## B. Corrected data: do the earlier conclusions hold?
Same splits, same recipe (64-64-32-16 MLP, batch 512, 100 epochs, one-cycle 1e-3), 5-seed ensembles. Each ensemble is
scored against the target it was trained on: original models vs the original data, new models vs the corrected data.
(Some older original-data runs only have 3 seeds; the `seeds` column shows original / corrected.)
""",

"code" => raw"""
ST = sanity_table()
""",

"markdown" => raw"""
The 80/20 chronological test holds out the last 20% of the mission, which is exactly where the original data were most
distorted (Earth extrapolated by up to 0.12 AU):
""",

"code" => raw"""
chrono_fig(arms=("base", "season"))
""",

"markdown" => raw"""
## C. Extrapolation in time
**Set-up.** Models are trained on the whole mission except a random 10% (`random 90/10`). The test set is synthetic:
6,000 mission exposures moved forward by Δ = 30, 60, …, 540 days. SPHEREx's survey is Sun-synchronous, so "the same
survey later" = pointing and SPHEREx's Earth-relative orbit **rotated about the ecliptic pole by how far Earth has moved
around the Sun**. Latitudes and Sun angles are kept (elongation changes ≤ 0.007°). Earth, Jupiter and velocities come from
the ephemeris; the truth comes from ZodiPy (`zodipy_gen/generate_future.py`). Features come from the real-data
pipeline. Check: on in-mission rows the pipeline reproduces the training predictions exactly:
""",

"code" => raw"""
println("pipeline vs stored predictions, season r90 ensemble: max relative difference = ", pipeline_selfcheck("season"))
""",

"markdown" => raw"""
Which inputs go outside what the network saw in training? (% of future exposures outside the 0.1–99.9% training range.)
The mission covers only ~38% of Earth's orbit, so **sin/cos λ⊕ (the season inputs) leave the training range** for most of
the year.
""",

"code" => raw"""
feature_range_table("season")
""",

"code" => raw"""
FT = future_table()
""",

"code" => raw"""
future_fig()
""",

"markdown" => raw"""
## D. Sun-frame inputs (round 11)
The look-direction inputs n·x, n·y (and n·J) are tied to fixed directions in space, and sin/cos λ⊕ only covers ~38% of
the year in the mission. Zodi brightness mostly depends on the geometry **relative to the Sun**, which turns with Earth.
New inputs (`sweeps/extra_features.jl`, also in the pipeline):

* **n·x⊕, n·y⊕**: the pointing in a frame rotated by Earth's longitude (x⊕ = Sun→Earth, y⊕ = direction of travel).
* **n·ĉ**: pointing · the smooth cloud's symmetry-plane normal (Kelsall: inclination 2.03°, node 77.66°).
* **Zc, Rc**: SPHEREx's height above the cloud's symmetry plane and its distance from the cloud centre.

| variant | inputs |
|---|---|
| Sun frame | n·S n·z n·E n·vS n·vE n·x⊕ n·y⊕ |
| + sin/cos λ⊕ | … + sinλ⊕ cosλ⊕ |
| + cloud (n·ĉ, Zc, Rc) | … + n·ĉ Zc Rc |
| + cloud (n·ĉ, Zc) | … + n·ĉ Zc |

None of these uses Jupiter or the fixed x/y axes. Ranges: n·x⊕, n·y⊕, n·ĉ stay inside the mission's range for the future
set (< 0.3% outside); Zc leaves it for 20% of the future exposures, Rc for 49% (the mission never got near perihelion).
""",

"code" => raw"""
feature_range_table("suncloud")
""",

"markdown" => raw"""
In-mission accuracy first (30-day blocks), compared with the season model:
""",

"code" => raw"""
interp_table()
""",

"code" => raw"""
FT11 = future_table()
""",

"code" => raw"""
future_fig(vcat([("season", "season model")], ARMS11L); title="Sun-frame inputs: trained on the whole mission (shaded), tested later in the year")
""",

"markdown" => raw"""
## E. Train on a full simulated year, test on the next (round 12)
Can the emulator work all year round if the training data cover a full year? `zodipy_gen/generate_year.py` builds a
~2.3-year survey: the real mission (corrected target) plus the survey moved forward by 140, 280, 420, 560 and 700 days,
rotated with Earth's orbit (100,000 random exposures per copy, 600,000 in all). Training: the first 365 days
(~261,000 exposures). Test: everything after (days 365–840). The second year repeats the season, but Jupiter has moved
~30° and the Sun–barycentre offset has changed.
""",

"code" => raw"""
Y2T = year2_table()
""",

"code" => raw"""
year2_fig()
""",

"markdown" => raw"""
## Conclusions
1. **Tell the mentor about the data errors** (`zodipy_gen/reproduce_original.py`, section A). The fixes are simple: pass a
   heliocentric observer position, and sort exposures by time (or evaluate in time-ordered chunks) before a ZodiPy batch
   call. Any other data made with the same script likely has the same issue.
2. **Use the corrected data from now on** (`ENV["ZODI_DATA"] = "z115"`). Every comparison in this notebook improved on it.
   Earlier notebooks stay valid as relative comparisons, but their absolute late-mission numbers include the data error.
3. **New recommended inputs: Sun frame + sin/cos λ⊕** (n·S n·z n·E n·vS n·vE n·x⊕ n·y⊕ sinλ⊕ cosλ⊕: no Jupiter, no fixed
   x/y axes). It was the best or tied for best in all three regimes:

   | regime | season model | Sun frame + sin/cos λ⊕ |
   |---|---|---|
   | inside the mission (30-day blocks), MSE | 1× | 0.87× |
   | trained on the mission → next 18 months, worst 30-day shift | 3.0% | 0.84% |
   | trained on a full year → the next 16 months, median | 0.33% | 0.10% |

4. **The cloud-geometry inputs (n·ĉ, Zc, Rc)** extrapolate about as well from the mission alone (worst 0.76%). With a full
   year of data they fall behind sin/cos λ⊕ (0.38% vs 0.10%). Rc is essential to them: without it the error reaches 10%
   mid-year, because Earth's distance from the Sun goes outside the mission's range. Sin/cos λ⊕ is simpler and better
   once a year of data exists.
5. **For real data:** the model can be trusted about 3 months beyond the observed season (≤ 0.1% at +90 days, 0.3% at +120).
   Year-round accuracy needs year-round training data; with one year, the next year is at ~0.1%. The remaining year-2
   error (4× the training-year error) probably comes from slow changes the inputs don't see (the Sun's offset from the
   barycentre, Earth's orbit vs calendar); a candidate for later.
6. **Next steps:** emulator v2 with the Sun frame + sin/cos λ⊕ inputs, trained on the corrected data; rerun the remaining
   earlier tests (block lengths, patches, all-sky) with those inputs; multi-wavelength (SPHEREx spans 0.75–5 μm).
""",
]
