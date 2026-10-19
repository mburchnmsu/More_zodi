# Cell contents for 10172026.ipynb — rounds 17–20 (Oct 16–17): loss curves for the 80/20 split and the month splits,
# why they are jagged and how to smooth them, error vs time gap, the Earth-trailing feature, and the 300-epoch
# month-split sky map.     julia sweeps/build_nb.jl sweeps/r20_text.jl 10172026.ipynb
CELLS = Pair{String,String}[

"markdown" => raw"""
# Loss curves, the Earth-trailing feature, and longer training for the sky map (Oct 16–17, 2026)

Follow-ups to the mentor's questions after the 10/15 notebook, all with the poster model: **Sun frame + sin/cos λ⊕**
inputs (n·S n·z n·E n·vS n·vE n·x⊕ n·y⊕ sinλ⊕ cosλ⊕), 64-64-32-16 gelu MLP, mini-batch 512, one-cycle LR (peak 1e-3),
**5 networks averaged**, corrected data (`ENV["ZODI_DATA"] = "z115"`). Rounds 17–20 (`sweeps/configs_v17.jl` … `v20.jl`).

1. **Train vs test loss for the 80/20 split** and for the month splits that test the mission's start/end (round 17).
2. **Why the curves are jagged**, and two ways to smooth them (round 18).
3. **Longer training and a lower learning rate** on the 80/20 split (round 19).
4. **The "bubbles" in the sky map**: error vs days to the nearest training day.
5. **Is the Earth-trailing dust feature modelled well?**
6. **The month splits trained for 300 epochs** (round 20): a calmer sky map.

The 80/20 split is a separate test; it is **not** used on the poster (which uses the month splits).

### Summary
* **The jagged curves come from mini-batch training**: each update uses 512 random pointings, so the network zigzags
  downhill, most at the peak of the one-cycle learning rate (epochs ~20–60), and the log axis magnifies small
  wiggles at low MSE. Early full-batch runs were smooth but ~1000× worse. The test curve never turns back up: no overfitting.
* **Averaging the 10 in-epoch evaluations of each epoch halves the epoch-to-epoch jumps** (test curve, 80/20: 0.045 →
  0.022 in log10). The **5-network average** has 3–4× lower loss but is *not* smoother.
* **300 epochs beat 100** on the 80/20 split: 5-network test MSE 1.2e-6 → 4.2e-7, median error 0.091% → 0.064%,
  p95 0.48% → 0.25%. A **lower peak LR (3e-4) gives the smoothest curves but worse accuracy** (median 0.123%).
* **The sky-map bubbles are the time pattern** (as the mentor suspected), not stars: for each version on its own, the
  error grows with the distance in days from the nearest training day (between months ~0.02% → ~0.04% at 15 days;
  beyond the mission's start/end up to 0.3–4%).
* **The Earth-trailing feature is reproduced well**: it is 5–9% of the light when looking behind Earth, and the
  out-of-sample error shows no trend with its share (bin medians within ±0.05%).
* **The month splits at 300 epochs** (30 trainings): sky-map median 0.0246% → **0.0178%**, p95 0.104% → **0.071%**,
  near the poles 0.016% → 0.013%; the bubbles are visibly calmer. The ecliptic stripe (dust bands) barely changes
  (0.094% → 0.090%): that is a limit of the model, not of training time. Start/end windows improve 2× (shift 20:
  0.22% → 0.11%). **The poster still uses the 100-epoch model.**
""",

"code" => raw"""
ENV["ZODI_DATA"] = "z115"
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "configs_v16.jl", "shift_helpers.jl", "r17_20_helpers.jl")
    include(joinpath(@__DIR__, "..", "sweeps", f))
end
""",

"markdown" => raw"""
## 1. Train vs test loss: 80/20 and the month splits that test the start/end
Round 17 trained the poster model on the 80/20 chronological split (train days 0–111, test 111–140; 5 networks).
Next to it, two round-16 month splits whose held-out days include the mission's start and end (shift 20 and 30 days).
The test MSE in those two panels mixes between-month windows with start/end windows.
""",

"code" => raw"""
raw_loss_fig([("z115_sunseason_ch", "80/20 chronological"), (20, "30-day split shifted 20 d"), (30, "30-day split shifted 30 d")])
""",

"markdown" => raw"""
## 2. Why the curves are jagged
* **Mini-batches.** Each update uses 512 random training pointings (~660 updates per epoch), not all 339k. Each
  batch points in a slightly different direction from the whole data set, so the weights zigzag downhill. Every point
  on the curve is a snapshot of where that zigzag was at the end of an epoch.
* **The one-cycle learning rate.** The step size ramps from 4e-5 up to 1e-3 over the first 30% of training, then
  anneals to 1e-7. The jumps are largest around the peak and the curves go smooth at the end.
* **Momentum.** Adam carries some memory of recent directions and can briefly overshoot (the spike near epoch 48).
* **The log axis.** Wiggles are drawn as ratios. At MSE ~1e-7 a factor-2 jump is ~0.001 MJy/sr.
* **Why the early curves were smooth:** the first runs (Oct 6) were **full-batch**, so every update used the exact
  gradient: smooth, but 2000 epochs (~2 h) to reach a test MSE of ~9e-4. Mini-batching reached that in ~2 epochs and
  ends ~10× lower with the same inputs (`sweeps/REPORT.md`).
* **Signs it is harmless:** train and test jump together (it is the network's state, not the data), the 5 seeds jump
  at different epochs, and the test curve never turns back up.

## 3. Two ways to smooth them (round 18)
Round 18 reran the three families of section 1 with in-epoch logging (`evals_per_epoch = 10`, fixed 50k-row
subsamples) and weight snapshots. **The networks are bit-identical to the originals** (the logging does not touch the
random numbers; max difference in the test-MSE history = 0). (a) average the 10 evaluations within each epoch;
(b) the loss of the 5-network average. Here (b) is sampled every 5 epochs for speed, which hides its epoch-to-epoch
jumps: at full resolution (`figures/10162026_loss_smooth.png`) it is as jagged as a single network.
""",

"code" => raw"""
SM_FIG, SM_TABLE = smooth_loss_fig([("z115_fine_ch", "80/20 chronological"), ("z115_fine_shift20", "30-day split shifted 20 d"),
                                    ("z115_fine_shift30", "30-day split shifted 30 d")]; ens_step=5)
SM_FIG
""",

"markdown" => raw"""
Roughness = median |Δ log10 MSE| between consecutive epochs over the middle 60% of the run (test curve, mean of 5 networks).
""",

"code" => raw"""
SM_TABLE
""",

"markdown" => raw"""
## 4. Longer training and a lower learning rate (round 19, 80/20 split)
300 epochs at the usual peak LR (1e-3) and at 3e-4, 5 networks each, epoch-averaged curves, compared with the
100-epoch runs of round 18. `ens_*` = the 5-network average on the test days (111–140).
""",

"code" => raw"""
LR_FIG, LR_TABLE = lr_epochs_fig([("z115_fine_ch", "100 epochs, peak LR 1e-3"), ("z115_ch300_lr1e3", "300 epochs, peak LR 1e-3"),
                                  ("z115_ch300_lr3e4", "300 epochs, peak LR 3e-4")])
LR_FIG
""",

"code" => raw"""
LR_TABLE
""",

"markdown" => raw"""
The lower learning rate settles into a solution that fits the training days as well but predicts the later days
worse; the longer run at the usual rate is better on every measure.

## 5. The "bubbles" in the sky map: error vs time gap
The mentor: *"Those bubbles are definitely not stars. Way too large to be stars. That pattern looks way more like the
extrapolation shape as a function of time, simply suppressed by your averaging over 5 blockings."* To check, each
shifted version (round 16, 100 epochs) is taken **on its own** and its error is binned by the number of days to the
nearest training day.
""",

"code" => raw"""
error_vs_gap_fig()
""",

"markdown" => raw"""
Confirmed: between training months the median error roughly doubles from ~0.02% next to the training data to ~0.04%
at 15 days; beyond the mission's start/end it keeps growing (shift 30 to ~0.3%, shift 20 above 1%), and the signed
error drifts in one direction. The sky-map bubbles are this pattern, partly averaged out across versions.

## 6. Is the Earth-trailing feature modelled well?
The corrected data store ZodiPy's components per exposure, including `emission_earth_trailing_feature` (Kelsall's
clump of dust trailing Earth). SPHEREx looks roughly perpendicular to the Sun, so it sees both the leading side
(ahead of Earth, n·vE > 0, Δλ ≈ −90°) and the trailing side (n·vE < 0, Δλ ≈ +90 to +120°). Compared with the
out-of-sample error of the round-16 between-month windows:
""",

"code" => raw"""
TF_FIG, TF_TABLE = trailing_feature_fig()
TF_FIG
""",

"code" => raw"""
TF_TABLE
""",

"markdown" => raw"""
The feature is 5–9% of the light on the trailing side (1–3% on the leading side), yet the error shows no trend with
its share and the trailing-side error maps look like the leading side: the network reproduces the feature to roughly
1% of its own brightness. A sharper test (not run): train a second model on ZodiPy **without** the trailing feature;
the difference of the two networks should reproduce the feature's map.

## 7. The month splits at 300 epochs (round 20)
The six shifted month splits of round 16, retrained for 300 epochs (30 trainings, ~5.5 h), with in-epoch logging.
Same map as the poster's Fig. 6: between-month windows only, each exposure averaged over the versions that held it out,
drawn as 3.5°-wide patches, same colour scale for both.
""",

"code" => raw"""
SKY_FIG, SKY_TABLE = skymap_100v300_fig()
SKY_FIG
""",

"code" => raw"""
SKY_TABLE
""",

"markdown" => raw"""
Per shift, median |error| on the held-out days between training months and (where present) at the mission's start/end:
""",

"code" => raw"""
m300_table()
""",

"code" => raw"""
loss_m300_fig()
""",

"markdown" => raw"""
## Conclusions
1. **Jagged loss curves are the signature of mini-batch training** (plus the one-cycle peak and the log axis), not a
   problem: train and test move together and the test curve never rises. To show smooth curves, **average the
   evaluations within each epoch** (halves the jumps). The ensemble's loss is lower but not smoother.
2. **Train longer, keep the learning rate**: 300 epochs improve both splits (80/20 median 0.091% → 0.064%; month splits
   0.0246% → 0.0178% on the sky map). A lower peak LR smooths the curves but costs accuracy.
3. **The sky-map bubbles are the time-extrapolation pattern**, and longer training calms them. The remaining structure
   is the **ecliptic stripe** (dust bands, ~0.09%), which training length does not fix: that needs a model change
   (e.g. the round-9 dust-band inputs or more capacity).
4. **The Earth-trailing feature is learned well** (no residual trend with its 5–9% share of the light).
5. **Not yet done:** the poster still uses the 100-epoch model (to be decided); the trailing-feature knockout test.
""",
]
