# More_zodi status
Updated: 2026-10-21 21:05, DESKTOP-BBASC81

## Headline
Heliocentric (Sun-centred) inputs are now the default for the 500-day data: they remove the need for n·J and give the
best model so far (500-day sky map: median 0.016%, within 2° of the ecliptic 0.048% vs 0.064% barycentric + n·J and
0.083% for 140 days). The full heliocentric 6-shift sky map is training overnight. **Poster: final (sent to print
2026-10-21); no further changes unless the user presents again.**

## Best model
500 days, heliocentric inputs (default for ZODI_DATA="z500" since Oct 21): n·S n·z n·E n·vS n·vE n·x⊕ n·y⊕ sinλ⊕ cosλ⊕
(no n·J), 64-64-32-16 gelu MLP, Adam, batch 512, one-cycle LR (peak 1e-3), 500 epochs, 5-network average, corrected
500-day targets. Poster split: median 0.0157%, p95 0.051%, ecliptic 0.044%. Sky map (shifts 0 + 30 so far): median
0.0160%, p95 0.053%, ecliptic 0.048%, above 60° 0.014%.
Poster model (final; 140 days, barycentric, 750 epochs): median 0.0159%, p95 0.063%, ecliptic 0.083%.

## Latest results
| Model (500 days, poster split, withheld months) | Median | p95 | Ecliptic (<2°) |
|---|---|---|---|
| barycentric + n·J (round 24) | 0.0164% | 0.055% | 0.060% |
| barycentric, no n·J (round 25) | 0.0307% | 0.191% | 0.094% |
| **heliocentric, no n·J (round 27)** | **0.0157%** | **0.051%** | **0.044%** |
| heliocentric + n·J (round 28, the mentor's Jupiter null test) | 0.0165% | 0.055% | 0.063% |

Why: the vectors file is barycentric, but the Sun (and the dust cloud and ZodiPy's targets with it) moved 0.0035 AU
about the barycentre over 500 days, pulled by Jupiter; n·J was standing in for it. Mentor's trailing-cloud tests:
test 1 passed (ring + blob reproduced to 0.002% of the total); test 2 (no Earth dot products) clearly worse (0.023%).
Notebooks: notebooks/10202026.ipynb, notebooks/10212026.ipynb.

## Running now
Round 29 (started 2026-10-21 20:59; ~4.8 GB RAM, below-normal priority): the remaining heliocentric 500-day sky-map
shifts — stage 1 = shifts 10 + 40 (to ~01:30), stage 2 = shifts 20 + 50 (to ~06:00 Oct 22); 20 trainings, 500 epochs.

## Waiting on user
nothing.

Decided 2026-10-19: no fixed Kelsall dust-band inputs for now; future: learn the band parameters from the data.

## Next up
Tonight, while round 29 trains: ZodiOnboarding.ipynb (to match ExoOnboarding / SolOnboarding). Then the full
heliocentric sky map and notebook 10222026. If time remains: start the learnable dust-band layer.
Later: the mentor's Earth-centric terms (n·δ̂, Moon) for real data; one-at-a-time ablation table.
