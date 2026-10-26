# More_zodi status
Updated: 2026-10-26 10:40, DESKTOP-BBASC81

## Headline
A learnable dust-band layer with parallax is now the best 500-day model: on the full 6-shift sky map it cuts the error
within 2° of the ecliptic from 0.050% to **0.0285%** (43% lower), with the rest of the sky unchanged (median 0.016%).
The mentor's Earth-centric null test passes (n·δ̂, n·M̂ change nothing on simulated data). **Poster: final (sent to print
2026-10-21); no further changes unless the user presents again.**

## Best model
500 days, heliocentric inputs (default for ZODI_DATA="z500" since Oct 21): n·S n·z n·E n·vS n·vE n·x⊕ n·y⊕ sinλ⊕ cosλ⊕
(no n·J) + S·x S·y S·z for the parallax band layer (sweeps/band_layer.jl, arch :bandplx: 3 Kelsall-shaped bands with
trainable inclination, node, width, shape and effective distance R), then a 64-64-32-16 gelu MLP, Adam, batch 512,
one-cycle LR (peak 1e-3), 500 epochs, 5-network average, corrected 500-day targets.
Full sky map: median 0.0157%, p95 0.049%, ecliptic 0.0285%, above 60° 0.0134%.
Same without the band layer (round 29): 0.0154% / 0.050% / 0.0499% / 0.0130%.
Poster model (final; 140 days, barycentric, 750 epochs): median 0.0159%, p95 0.063%, ecliptic 0.083%.

## Latest results (Oct 22–23) — notebook: notebooks/10232026.ipynb
| Model (500 days heliocentric, poster split) | Median | p95 | Ecliptic (<2°) | Ens. MSE |
|---|---|---|---|---|
| no bands (round 27) | 0.0157% | 0.051% | 0.0442% | 3.10e-8 |
| learnable bands, no parallax (round 30) | 0.0161% | 0.051% | 0.0326% | 2.66e-8 |
| **learnable bands + parallax (round 31)** | 0.0162% | 0.051% | **0.0292%** | **2.44e-8** |
| + n·δ̂ + n·M̂, Earth-centric null (round 33) | 0.0158% | 0.052% | 0.0444% | 3.12e-8 |

- Round 32: parallax layer on all 6 shifts → full sky map (figures/10232026_skymap_bandplx.png,
  sweeps/results_z500_helio/r32_summary.jld2).
- Fitted bands consistent over 30 networks: inclinations ~1°, band 2 width 1.7°, effective distances 1.42 / 1.76 / 2.04 AU
  (bands 2 / 1 / 3; ZodiPy inner cutoffs 0.94 / 1.5 / 1.5 AU). Nodes scatter ±5–9° (weakly constrained at ~1° tilt); the
  "89°" node seen first was an angle-averaging artefact (one node at 359.96°), circular mean 18°.
- Earth-centric null: every difference within seed scatter → ready to add for real data.

## Earlier (Oct 20–22)
Heliocentric inputs replaced n·J (the Sun moved 0.0035 AU about the barycentre over 500 days). Full heliocentric sky map
(round 29): median 0.0154%, ecliptic 0.050%. Mentor's trailing-cloud tests: test 1 passed; test 2 (no Earth dot
products) clearly worse. Notebooks 10202026, 10212026, 10222026.

## Running now
Round 34 (started 16:35 Fri Oct 23; sweeps/run_round34.ps1, below-normal, ~5.4 GB): the parallax band layer at **2000
epochs** (vs 500), all 6 shifts × 5 seeds, ~11 h per shift: shift 0 ~03:30 Sat, 10 ~14:30 Sat, 20 ~01:30 Sun,
30 ~12:30 Sun, 40 ~23:30 Sun, 50 ~10:30 Mon. Progress: sweeps/report34.jl → figures/r34_progress_{loss,sky}.png.
- Shift 0 (poster split) done 04:05 Sat — **big gain**: ecliptic 0.0292% → **0.0161%**, median 0.0162% → **0.0135%**,
  p95 0.051% → 0.040%, ensemble MSE 2.44e-8 → 1.47e-8; final train/test MSE 7.1e-9 / 1.8e-8, test still falling.
- Shift 10 done 15:00 Sat (MSE 2.37e-8 → 1.48e-8). Sky map, shifts 0 + 10: ecliptic 0.0294% → 0.0164%, median
  0.0156% → 0.0132%, p95 0.049% → 0.037%. Notebook: notebooks/10242026.ipynb.
- **Stalled Sat 22:39 → Mon 10:28:** the laptop was on battery and kept entering Modern Standby, which pauses training.
  The run is intact (the shift-20 batch was ~85–90% done at 10:30 Mon). New estimate if plugged in and awake: shift 20
  ~12:00 Mon, 30 ~23:00 Mon, 40 ~10:00 Tue, 50 ~21:00 Tue.

## Waiting on user
nothing.

Decided 2026-10-19: no fixed Kelsall dust-band inputs; learn the band parameters from the data (done: round 30–32).

## Next up
Options: per-band radial profile (inner cutoff + ~1/R falloff, as in ZodiPy) instead of one effective R; one-at-a-time
ablation table; Earth-centric terms + star masking on real SPHEREx data (masking only when the user says so).
