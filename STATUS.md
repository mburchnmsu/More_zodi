# More_zodi status
Updated: 2026-10-21 04:20, DESKTOP-BBASC81

## Headline
On the new 500-day data the emulator reaches 0.016% median error on months it never saw and tests 98% of the sky;
the plane-of-the-planets error drops from 0.083% (140 days) to 0.064%. Found and fixed: the inputs were barycentric
while the dust follows the Sun; heliocentric inputs remove the need for n·J and are the best 500-day model so far.
Mentor's trailing-cloud tests 1 and 2 done. Poster redesigned (larger text, 140 vs 500-day sky-map pair).

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

## Overnight results (Oct 20–21)
- **Heliocentric inputs fix the 500-day model** (round 27, poster split, no n·J): median 0.0157%, p95 0.051%,
  ecliptic 0.044%, test MSE 3.1e-8 — better than barycentric + n·J (0.0164%, 0.055%, 0.060%, 3.7e-8) and far better than
  barycentric without n·J (0.031%, 0.191%, 0.094%). The year-1/year-2 error excess is gone (days 0–100: 0.014%).
- **Mentor's test 2** (140 d, poster model without n·E, n·vE, n·x⊕, n·y⊕): sky-map median 0.0230% vs 0.0159%,
  p95 0.131% vs 0.063%, poles 0.030% vs 0.0125% (worse, esp. near the north ecliptic pole); ecliptic 0.077% vs 0.083%.
  The trailing cloud is still learned (leftover 0.03 ± 0.09%): n·S ≈ n·E since SPHEREx is ~5e-5 AU from Earth.
- **Test 1** passed (network − cloud-free ZodiPy reproduces ring + blob to 0.002% of the total).

## Running now
nothing (round 27 finished 01:48, test 2 / round 26 finished 04:08). The PC is clear.
## Waiting on user
- Poster redesign: latest draft sent (Fig. 6 = 140 vs 500-day maps; caption to mention the n·J result).

Decided 2026-10-19: no fixed Kelsall dust-band inputs for now; future: learn the band parameters from the data.

## Next up
notebooks/10202026.ipynb (500-day data, rounds 24–27, tests 1–2, poster redesign). Decide with the user: switch all
models to heliocentric inputs (and rerun the 500-day sky map with them)? Later: learnable dust-band layer;
ZodiOnboarding.ipynb to match the other projects.
