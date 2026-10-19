# More_zodi status
Updated: 2026-10-19 07:05, DESKTOP-BBASC81

## Headline
The emulator reaches ~0.016–0.018% median error on months it never saw; the mentor's Earth-trailing-cloud test passes;
the round-9 dust-band inputs remove the last big error (the ecliptic stripe). Poster v6 ready; mentor meeting today.

## Best model
Sun-frame + time-of-year inputs (n·S n·z n·E n·vS n·vE n·x⊕ n·y⊕ sinλ⊕ cosλ⊕) **+ 3 sharp dust-band profiles**,
64-64-32-16 gelu MLP, 300 epochs, 5-network average, corrected data (z115). Six shifted month-on/month-off splits,
between-month windows (sky map): median |error| 0.0165%, p95 0.060%, within 2° of the ecliptic 0.034%, above 60° 0.012%.
Best on the poster split alone: wider 128-128-64-32 + bands (median 0.017%, p95 0.058%, ecliptic 0.029%).
Poster currently uses the model without bands at 750 epochs (median 0.016%, ecliptic 0.083%).

## Latest results
| Model (month splits, sky map, between-month windows) | Median abs. error | p95 | Ecliptic (<2°) |
|---|---|---|---|
| poster model, 100 epochs | 0.0246% | 0.104% | 0.094% |
| poster model, 300 epochs | 0.0178% | 0.071% | 0.090% |
| poster model, 750 epochs (poster v6) | 0.0159% | 0.063% | 0.083% |
| + dust bands, 300 epochs (rounds 22–23) | 0.0165% | 0.060% | 0.034% |

Earth-trailing cloud (5–9% of the light behind Earth): leftover fraction in the residuals 0.06 ± 0.09% of the cloud
(750 epochs) — learned. Notebook: notebooks/10182026.ipynb.

## Running now
nothing

## Waiting on user
- Poster Fig. 7 style: 7° blend (poster_{light,dark}.pptx) or 3.5° patches (poster_{light,dark}_35.pptx).
- Whether the poster should switch to the dust-band model (fixes the ecliptic stripe; needs ~5 h of training at 750 epochs, or use the 300-epoch runs).

## Next up
Mentor meeting (Oct 19). Options: dust-band model on the poster; wider + bands on all month splits (~7 h);
trailing-cloud knockout test (train without the cloud); ZodiOnboarding.ipynb to match the other projects.
