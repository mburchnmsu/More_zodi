# More_zodi status
Updated: 2026-10-23 11:40, DESKTOP-BBASC81

## Headline
Heliocentric (Sun-centred) inputs are now the default for the 500-day data: they remove the need for nÂ·J and give the
best model so far (500-day sky map: median 0.016%, within 2Â° of the ecliptic 0.048% vs 0.064% barycentric + nÂ·J and
0.083% for 140 days). The full heliocentric 6-shift sky map is training overnight. **Poster: final (sent to print
2026-10-21); no further changes unless the user presents again.**

## Best model
500 days, heliocentric inputs (default for ZODI_DATA="z500" since Oct 21): nÂ·S nÂ·z nÂ·E nÂ·vS nÂ·vE nÂ·xâŠ• nÂ·yâŠ• sinÎ»âŠ• cosÎ»âŠ•
(no nÂ·J), 64-64-32-16 gelu MLP, Adam, batch 512, one-cycle LR (peak 1e-3), 500 epochs, 5-network average, corrected
500-day targets. Poster split: median 0.0157%, p95 0.051%, ecliptic 0.044%. Sky map (shifts 0 + 30 so far): median
0.0160%, p95 0.053%, ecliptic 0.048%, above 60Â° 0.014%.
Poster model (final; 140 days, barycentric, 750 epochs): median 0.0159%, p95 0.063%, ecliptic 0.083%.

## Latest results
| Model (500 days, poster split, withheld months) | Median | p95 | Ecliptic (<2Â°) |
|---|---|---|---|
| barycentric + nÂ·J (round 24) | 0.0164% | 0.055% | 0.060% |
| barycentric, no nÂ·J (round 25) | 0.0307% | 0.191% | 0.094% |
| **heliocentric, no nÂ·J (round 27)** | **0.0157%** | **0.051%** | **0.044%** |
| heliocentric + nÂ·J (round 28, the mentor's Jupiter null test) | 0.0165% | 0.055% | 0.063% |

Why: the vectors file is barycentric, but the Sun (and the dust cloud and ZodiPy's targets with it) moved 0.0035 AU
about the barycentre over 500 days, pulled by Jupiter; nÂ·J was standing in for it. Mentor's trailing-cloud tests:
test 1 passed (ring + blob reproduced to 0.002% of the total); test 2 (no Earth dot products) clearly worse (0.023%).
Notebooks: notebooks/10202026.ipynb, notebooks/10212026.ipynb.

## Running now
Rounds 31â†’33 chain (sweeps/run_round31.ps1, started 19:01 Oct 22, below-normal priority, ~5 GB RAM, log sweeps/round31.log):
- round 31 DONE 21:47: band layer WITH parallax (trainable ring distance R), poster split â€” **wins**: ecliptic 0.0326% â†’
  **0.0292%**, ens MSE 2.66e-8 â†’ 2.44e-8, median 0.016% (same). Fitted R â‰ˆ 1.74 / 1.48 / 2.06 AU (bands 1/2/3);
  band 2's node moved to ~89Â° (30Â° without parallax) â€” to look into.
- round 32 DONE 11:07 Oct 23: full 6-shift sky map with the parallax band layer â€” median 0.0157%, p95 0.049%, ecliptic
  **0.0285%** (no band layer, round 29: 0.0499%), above 60Â° 0.0134%. figures/10232026_skymap_bandplx.png;
  sweeps/results_z500_helio/r32_summary.jld2
- round 33 (running since 11:07): mentor's Earth-centric null test (+ nÂ·Î´Ì‚, nÂ·MÌ‚; should not help on simulated data), 5 runs â€” (â†’ ~13:45 Oct 23)
Then: notebooks/10232026.ipynb.

## Learnable dust-band layer (round 30, Oct 22) â€” notebook: notebooks/10222026.ipynb
Kelsall's band profile with trainable inclination/node/width/shape per band (sweeps/band_layer.jl, arch :bandmlp),
heliocentric 500 days, poster split: ecliptic error 0.044% â†’ **0.033%** (median ~0.016%, ensemble MSE 3.1e-8 â†’ 2.4â€“2.7e-8).
Started from Kelsall's values or deliberately wrong ones, the fits converge to the same parameters; the strong band 2
lands near Kelsall (node ~31Â° vs 30.3Â°, i ~1.0Â° vs 1.2Â°, width 2.45Â° vs 1.99Â°); faint bands 1 and 3 settle elsewhere.

## Full heliocentric 500-day sky map (round 29 done 06:02)
6 shifts Ã— 5 seeds, no nÂ·J: median **0.0154%**, p95 **0.050%**, within 2Â° of the ecliptic **0.050%**, above 60Â° **0.0130%**
(barycentric + nÂ·J: 0.0162% / 0.053% / 0.064% / 0.0140%). figures/10212026_skymap_helio.png (right panel).
## Waiting on user
nothing.

Decided 2026-10-19: no fixed Kelsall dust-band inputs for now; future: learn the band parameters from the data.

## Next up
Done Oct 21â€“22: heliocentric default + full sky map, ZodiOnboarding.ipynb (project root), learnable dust-band layer
(first results). Options: learnable bands on all 6 shifts (full sky map, ~13 h); a parallax version of the band layer.
Later: the mentor's Earth-centric terms (nÂ·Î´Ì‚, Moon) for real data; one-at-a-time ablation table.
