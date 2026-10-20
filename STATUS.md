# More_zodi status
Updated: 2026-10-20 15:15, DESKTOP-BBASC81

## Headline
On the new 500-day data the emulator reaches 0.016% median error on months it never saw and tests 98% of the sky;
the plane-of-the-planets error drops from 0.083% (140 days) to 0.064%. Jupiter's direction (n·J) matters a lot at
500 days: without it the error doubles. Poster redesigned (larger text, 140 vs 500-day sky-map pair).

## Best model
500 days (round 24): Sun-frame + time-of-year inputs + n·J (n·S n·z n·E n·vS n·vE n·x⊕ n·y⊕ sinλ⊕ cosλ⊕ n·J),
64-64-32-16 gelu MLP, Adam, batch 512, one-cycle LR (peak 1e-3), 500 epochs, 5-network average, corrected 500-day
targets (ZODI_DATA="z500"). Six shifted month splits, between-month windows (sky map): median |error| 0.0162%,
p95 0.053%, within 2° of the ecliptic 0.064%, above 60° 0.014%.
Poster model (140 days, no n·J, 750 epochs): median 0.0159%, p95 0.063%, ecliptic 0.083%.

## Latest results
| Model (sky map / poster split, between-month windows) | Median abs. error | p95 | Ecliptic (<2°) |
|---|---|---|---|
| 140 days, poster model, 750 epochs (sky map) | 0.0159% | 0.063% | 0.083% |
| 500 days, + n·J, 500 epochs (sky map, round 24) | 0.0162% | 0.053% | 0.064% |
| 500 days, + n·J (poster split only) | 0.0164% | 0.055% | 0.060% |
| 500 days, without n·J (poster split only, round 25) | 0.0307% | 0.191% | 0.094% |

Without n·J the error is largest at days 0–100 and 400–500 (the same time of year, one year apart): n·J lets the
network tell the two years apart. Cause under investigation. Notebooks: notebooks/10182026.ipynb (10202026 coming).

## Running now
nothing (rounds 24 and 25 finished 12:05 and 14:26). The PC is clear for the other projects.

## Waiting on user
- Mentor's trailing-cloud validation tests: test 1 (light) and test 2 (heavy, ~11 h overnight; poster model without
  n·E, n·vE, n·x⊕, n·y⊕) are prepared and wait for Project Hub's go after Exoplanet and Solar. Not for the poster.
- Poster redesign: latest draft sent (Fig. 6 = 140 vs 500-day maps; caption to mention the n·J result).

Decided 2026-10-19: no fixed Kelsall dust-band inputs for now; future: learn the band parameters from the data.

## Next up
notebooks/10202026.ipynb (500-day data, rounds 24–25, poster redesign; tests 1–2 added when run). Find out why the
500-day model needs n·J. Later: learnable dust-band layer; ZodiOnboarding.ipynb to match the other projects.
