# Cell contents for 10182026.ipynb — Oct 18: the month splits trained for 750 epochs (round 21), the sky map with and
# without blending, the mentor's Earth-trailing-cloud stack, poster v6, and the overnight model experiments (round 22).
#     julia sweeps/build_nb.jl sweeps/r21_text.jl notebooks/10182026.ipynb
CELLS = Pair{String,String}[

"markdown" => raw"""
# 750-epoch sky map, the Earth-trailing-cloud test, and poster v6 (Oct 18, 2026)

All with the poster model: **Sun frame + sin/cos λ⊕** inputs (n·S n·z n·E n·vS n·vE n·x⊕ n·y⊕ sinλ⊕ cosλ⊕), 64-64-32-16
gelu MLP, mini-batch 512, one-cycle LR (peak 1e-3), **5 networks averaged**, corrected data (`ENV["ZODI_DATA"] = "z115"`),
on the **month-on/month-off splits** (30-day windows, shifted by 0, 10, …, 50 days; between-month windows for the map).

1. **Longer training**: the six month splits at 100 (round 16), 300 (round 20) and **750 epochs** (round 21, 30 trainings).
2. **The sky map with and without blending** (3.5° patches ≈ SPHEREx's view vs a 7° blend for display).
3. **The mentor's test: is the Earth-trailing cloud modelled well?** Stack Kelsall's trailing-cloud signal and the
   network's residuals along a geometric "am I looking through the cloud" axis.
4. **Poster v6**: every number and figure now from the 750-epoch runs.
5. **Overnight experiments (round 22)**: can dust-band inputs or a wider network fix the ecliptic stripe?

### Summary
* **750 epochs**: sky-map median error **0.0159%** (300 ep: 0.0178%, 100 ep: 0.0246%), p95 0.063%, within 2° of the
  ecliptic 0.083%, above 60° 0.0125%. Diminishing returns (300 → 750: −11%). The poster's own split: median **0.018%**,
  p95 0.069%, **97.5%** within 0.1% (100 epochs: 0.026%, 0.10%, 94.8%).
* **Blending** to 7° patches calms the map for display; the per-pointing errors are unchanged.
* **The trailing cloud is learned**: both axes track Kelsall's cloud (correlation 0.93–0.94 with its share of the
  light), yet the residuals stay flat (±0.01–0.02%) where a model missing just 1% of the cloud would show a ~0.06%
  trend. Fitted leftover fraction of the cloud: **0.06 ± 0.09%** near the plane, 0.09 ± 0.05% whole sky (750 epochs).
* The remaining structure was the **ecliptic stripe** (dust bands, ~0.08%), untouched by longer training.
* **Overnight (rounds 22–23): the round-9 dust-band inputs fix it.** On the poster's split the error within 2° of the
  ecliptic drops 3× (0.090% → 0.031%) at no cost elsewhere; a wider network alone does little; wider + bands is best on
  every measure (median 0.017%, p95 0.058%) but trains ~1.8× slower. On all six month splits (300 epochs + bands):
  sky-map median 0.0165%, p95 0.060%, **ecliptic 0.034%** (750-epoch poster model: 0.083%). The poster still uses the
  750-epoch model without bands (to be decided).
""",

"code" => raw"""
ENV["ZODI_DATA"] = "z115"
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "configs_v16.jl", "shift_helpers.jl",
          "r17_20_helpers.jl", "r21_22_helpers.jl")
    include(joinpath(@__DIR__, "..", "sweeps", f))
end
""",

"markdown" => raw"""
## 1–2. The month splits at 100, 300 and 750 epochs, with and without blending
Out-of-sample error on the sky: every pointing is predicted by the versions that withheld its 30-day window
(between-month windows only), averaged. Top row: each pointing drawn as a 3.5° patch (≈ SPHEREx's field of view);
bottom row: blended over 7° patches (display only). Same colour scale everywhere.
""",

"code" => raw"""
skymap_grid_fig()
""",

"markdown" => raw"""
Per shift, median |error| between months and (where present) at the mission's start/end:
""",

"code" => raw"""
m300_table(((fam100, 100), (fam300, 300), (fam750, 750)))
""",

"code" => raw"""
loss_m300_fig(fam750)
""",

"markdown" => raw"""
## 3. The mentor's test: is the Earth-trailing cloud modelled well?
The mentor: *"compare what you expect from the Kelsall model by stacking the model data using that x-axis (ahead of
Earth versus behind Earth) and then do the same thing with your residuals to see if there is still some signal in the
residuals that has the trend you might expect from the effect of the earth trailing cloud."*

Two x-axes, both built from dot products of the look direction n:
* **ahead vs behind Earth**: the angle between n and Earth's direction of motion v̂⊕ (0° = straight ahead,
  180° = straight behind). v̂⊕ is the in-plane basis vector that turns with Earth (≈ y⊕).
* **toward the cloud's centre**: the angle between n and the direction from SPHEREx to the centre of Kelsall's trailing
  blob (1.06 AU from the Sun, 10° behind Earth in its orbit). This also accounts for the blob sitting slightly inside
  Earth's orbit.

Angles rather than dot products, because SPHEREx looks ~90° from the Sun, so the dot products pile up near ±1.
Top: what Kelsall predicts (the trailing cloud's share of the light, from ZodiPy's per-component output). Bottom: the
network's residuals on pointings it never saw, and (dotted) what a model that missed 1% of the cloud would show.
""",

"code" => raw"""
let a = trailing_axes(), ftf = 100 .* TF_EMISSION ./ y
    @printf("correlation with the trailing cloud's share of the light: ahead/behind angle %.3f, angle to the cloud's centre %.3f\n",
            cor(ftf, a.ahead), cor(ftf, a.blob))
end
TS_FIG, TS_TABLE = trailing_stack_fig()
TS_FIG
""",

"markdown" => raw"""
A direct number: fit residual = a·(trailing-cloud share, %) + b over all tested pointings. a = −1 would mean the cloud
is entirely missing from the network, 0 that it is perfectly reproduced; the uncertainty is the spread of a over the
5 individual networks.
""",

"code" => raw"""
TS_TABLE
""",

"markdown" => raw"""
**The trailing cloud is learned**: the leftover fraction is consistent with zero (|a| ≲ 0.1–0.2% of the cloud's own
brightness at 300 and 750 epochs). The residual wiggles along the axes (±0.01–0.02%) do not follow the cloud's shape.
Near the plane the pointings sit only at the two ends of the ahead/behind axis (SPHEREx looks ~90° from the Sun), so
the whole-sky stack is used for the residuals.

## 4. Poster v6
Every number and figure now comes from the 750-epoch runs (`poster/data_*.jl`; the poster's split is shift 0):
banner ~0.02%; tiles 0.018% / 97.5% / ≤0.03%; Fig. 4 accuracy + 1:1 scatter; Fig. 5 epoch-averaged training curves;
Fig. 6 shift timeline (0.015–0.03% between months); Fig. 7 sky map (0.08% on the ecliptic, 0.013% near the poles),
in two versions (`poster_{light,dark}.pptx` = 7° blend, `poster_{light,dark}_35.pptx` = 3.5° patches).
New since v4: Fig. 2 (what makes up the zodiacal light), the 1:1 scatter, shorter bullet text.

## 5. Overnight: fixing the ecliptic stripe (round 22)
The stripe along the ecliptic (dust bands, ~0.08–0.09%) barely moved with longer training (section 1), so it is a
limit of the model's inputs or size, not of training time. Round 22 tries both, on the poster's split (shift 0),
300 epochs, 5 networks each, against the 300- and 750-epoch baselines:
* **+ dust bands**: the 3 sharp dust-band profiles of round 9 (`:sunseason_bandsharp`) added to the poster inputs;
* **wider net**: 128-128-64-32 (4× the parameters);
* **wider + bands**: both.
""",

"code" => raw"""
r22_table([("z115_m300_shift0", "baseline, 300 epochs"), ("z115_m750_shift0", "baseline, 750 epochs"),
           ("z115_r22_bands", "+ dust bands"), ("z115_r22_big", "wider net"), ("z115_r22_bigbands", "wider + bands")])
""",

"markdown" => raw"""
**The dust-band inputs fix the stripe**: within 2° of the ecliptic the error drops 3× (0.090% → 0.031%) with nothing
lost elsewhere (p95 and the test MSE improve too). Unlike round 9, where the same inputs hurt the 30-day-block test of
the older season model, here they help everywhere. The wider network alone does little; wider + bands is best on every
measure (median 0.017%, p95 0.058%, ecliptic 0.029%) but trains ~1.8× slower.

## 6. The dust-band model on all six month splits (round 23)
The round-22 "+ dust bands" model on the other five shifted splits (25 trainings), for the out-of-sample sky map.
Compared with the poster's 750-epoch model, same drawing and colour scale.
""",

"code" => raw"""
skymap_grid_fig(((fam750, "750 epochs"), (famB, "300 epochs + dust bands")))
""",

"code" => raw"""
let (E7, EB) = (oos_interior(fam750), oos_interior(famB)), S7 = sky_stats(E7), SB = sky_stats(EB)
    DataFrame(model=["poster model, 750 epochs", "+ dust bands, 300 epochs"], exposures=[S7.n, SB.n],
              median_pct=round.([S7.med, SB.med], digits=4), p95_pct=round.([S7.p95, SB.p95], digits=3),
              ecliptic_lt2deg_pct=round.([S7.ecl, SB.ecl], digits=4), above60deg_pct=round.([S7.pole, SB.pole], digits=4))
end
""",
]
