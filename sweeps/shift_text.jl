# Cell contents for 10152026.ipynb — round 16 (mentor requests, Oct 15): shifted 30-day windows, train + test MSE
# curves, all-sky map of the out-of-sample error.   julia sweeps/build_nb.jl sweeps/shift_text.jl 10152026.ipynb
CELLS = Pair{String,String}[

"markdown" => raw"""
# Shifted train/test windows, train + test MSE, and the error on the sky (Oct 15, 2026)

Three requests from the mentor meeting, all with the poster's model: **Sun frame + sin/cos λ⊕** inputs
(n·S n·z n·E n·vS n·vE n·x⊕ n·y⊕ sinλ⊕ cosλ⊕), 64-64-32-16 gelu MLP, 100 epochs, one-cycle LR, **5 seeds averaged**,
corrected data (`ENV["ZODI_DATA"] = "z115"`).

1. **Does the result depend on which months are held out?** The "30 day split" trains on mission days 0–30, 60–90,
   120–140 and tests on 30–60 and 90–120. Here the whole alternating pattern is slid by **Δ = 0, 10, 20, 30, 40, 50 days**
   (Δ = 30 swaps the train and test months). Round 16, `sweeps/configs_v16.jl` (Δ = 0 is the existing run
   `z115_sunseason_blk`).
2. **Train and test MSE on the same plot**, for every version.
3. **The error on the sky.** Each exposure is held out by 3 of the 6 versions, so every exposure gets a prediction from
   models that never saw its 30-day window. Mapped on a regular 3° × 3° grid in ecliptic coordinates.

**Caveat for the sky map:** the target here is ZodiPy's model of the zodiacal light only, sampled at each exposure's
**boresight** (one direction per exposure). There are **no stars** in this data, so star artifacts cannot appear;
they will appear once the model is compared with real SPHEREx images (pixel by pixel, which needs the real images'
pixel pointing — and star masking then).

### Summary
* **Between training months the result does not depend on which months are held out.** For every shift, the
  held-out windows that have training data on both sides ("interior") reach **0.023–0.037% median error** (p95
  0.10–0.14%). The poster's 0.026% (shift 0) is typical, not a lucky choice.
* **Windows at the start or end of the mission are a different test: extrapolation in time.** When a shift holds out
  the first or last days, the network has no training data on that side. 10 days at an edge costs little (0.03–0.04%),
  but 20–30 days costs a lot: shift 30 (days 0–30 and 120–140) **0.11%**, shift 20 (days 0–20 and 110–140) **0.22%
  median, p95 2.9%**. This is the same limit found before (predictions stay good for a short time beyond the
  training data and degrade after that).
* **Train vs test MSE:** for interior windows the test MSE ends ~2× the training MSE (a small, stable gap; no
  overfitting: the test curve flattens but never rises). With edge windows the gap is 20–300×, and the test curve
  stalls early. With a random 10% hold-out the two curves coincide.
* **On the sky** (out-of-sample, interior windows): the error is largest along the **ecliptic** (median 0.094% at
  |β| < 2°, vs 0.016% above |β| = 60°), where the dust bands and the densest part of the cloud are. The signed map
  shows thin east–west stripes along the ecliptic (dust-band structure the network smooths over) and no large-scale
  bias. Edge-window errors trace the arcs of sky observed at the start and end of the mission.
* **No star artifacts** — expected, since the simulated data contains no stars (see the caveat above).
""",

"code" => raw"""
ENV["ZODI_DATA"] = "z115"
include(joinpath(@__DIR__, "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "configs_v16.jl", "shift_helpers.jl")
    include(joinpath(@__DIR__, "sweeps", f))
end
""",

"markdown" => raw"""
## 1. Sliding the 30-day windows
Each row is one version: blue = trained on, red = held out (tested). Right: the 5-seed ensemble's median |error| on
its own held-out days.
""",

"code" => raw"""
shift_timeline_fig()
""",

"markdown" => raw"""
Accuracy on the held-out days (ensemble of 5 seeds). `rms_err_pct` = root-mean-square of the fractional error;
`ens_test_mse` = the ensemble's MSE on the held-out days; `final_train_mse` / `final_test_mse` = the mean over seeds of
each single network's last-epoch MSE.
""",

"code" => raw"""
ST = shift_table()
""",

"markdown" => raw"""
Shifts 10–40 hold out days at the **start or end** of the mission (orange above), where there is training data on only
one side: those exposures test **extrapolation in time**, not interpolation. Split by window type:
""",

"code" => raw"""
IE = interior_edge_table()
""",

"markdown" => raw"""
## 2. Train and test MSE during training
Blue = training data, red = held-out data; thin lines are the 5 seeds, thick lines their mean. The last panel is the
random 10% hold-out (`z115_sunseason_r90`) for comparison: there the test points are interleaved with training points,
so train and test track each other exactly.
""",

"code" => raw"""
loss_curves_fig()
""",

"markdown" => raw"""
## 3. The out-of-sample error on the sky
Top: median signed error (network − ZodiPy) per 3° × 3° cell; middle: median |error|; bottom: number of exposures per
cell. Ecliptic coordinates, longitude 0° in the centre increasing to the left; grey = never observed in the 140 days
(cells with fewer than 5 exposures are left grey in the top two maps). Every exposure's prediction comes from the
versions that held out its 30-day window (3 of the 6), averaged.
""",

"code" => raw"""
sky_error_fig()
""",

"markdown" => raw"""
**The thin pole-to-pole grey stripes are gaps between scan circles, not missing days.** There are no gaps in time (one
exposure every ~2 min for 140 days; one half-day gap on day 3), and the same columns are empty in the whole-mission
data, not only in the held-out months. SPHEREx scans great circles through the ecliptic poles, roughly along lines of
longitude, and our file stores only each exposure's **boresight**: those lie on circles a few degrees apart, so a 3°
cell that falls between two circles gets fewer than 5 exposures (e.g. nothing at all at longitude 357°–3°). The real
images are ~3.5° wide and cover these gaps. Below, each exposure is drawn as a disc of radius 1.75° on a 1° grid (the
values are still the errors at the boresights; this is the map on the poster, `poster/data_skyerror.jl`).
""",

"code" => raw"""
sky_footprint_fig()
""",

"code" => raw"""
for w in (:interior, :edge)          # error vs ecliptic latitude, interpolation and extrapolation separately
    o = oos_prediction(which=w); ok = .!isnan.(o.err_pct); a = abs.(o.err_pct[ok]); b = abs.(ecliptic_latitude_deg[ok])
    @printf("%s windows: %d exposures (%.0f%% of the mission); median |error| %.4f%%, p95 %.3f%%\n", w, sum(ok), 100mean(ok),
            median(a), quantile(a, 0.95))
    for (lo, hi) in ((0, 2), (2, 5), (5, 15), (15, 30), (30, 60), (60, 90))
        k = lo .<= b .< hi
        @printf("  |β| %2d–%2d°: %6d exposures, median |error| %.4f%%, p95 %.3f%%\n", lo, hi, sum(k), median(a[k]), quantile(a[k], 0.95))
    end
end
""",

"markdown" => raw"""
## Conclusions
| shift | held out (interior = between training windows) | interior median | edge (start/end) held out | edge median |
|---|---|---|---|---|
| 0 d | 30–60, 90–120 | 0.026% | — | — |
| 10 d | 40–70, 100–130 | 0.030% | 0–10 | 0.037% |
| 20 d | 50–80 | 0.037% | 0–20, 110–140 | 0.22% (p95 2.9%) |
| 30 d | 60–90 | 0.035% | 0–30, 120–140 | 0.11% (p95 0.51%) |
| 40 d | 10–40, 70–100 | 0.026% | 130–140 | 0.031% |
| 50 d | 20–50, 80–110 | 0.023% | — | — |

1. **The 30-day-block accuracy is robust to the choice of months** as long as the held-out month lies between
   training months: 0.023–0.037% median for every shift.
2. **Held-out windows at the mission's ends measure extrapolation in time, not interpolation**, and should be reported
   separately. Up to ~10 days beyond the training data costs little; 20–30 days costs 4–10× in median error and much
   more in the tail. For real data this means: train on data that brackets the period to be modelled (or a full year).
3. **The remaining interpolation error lives on the ecliptic** (dust bands), ~6× larger than near the poles. That is
   where to look for improvements (e.g. the dust-band inputs tested in round 9, or more capacity/epochs).
4. **For the next sky maps:** with real SPHEREx images (pixel-level pointing, stars present), the same out-of-sample
   map would show stars as point-like residuals; they would then need masking.
""",
]
