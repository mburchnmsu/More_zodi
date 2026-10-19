# More_zodi status
Updated: 2026-10-19 08:30, DESKTOP-BBASC81

## Headline
The emulator reaches ~0.016–0.018% median error on months it never saw; the mentor's Earth-trailing-cloud test passes;
the round-9 dust-band inputs remove the last big error (the ecliptic stripe). Poster v6 ready; mentor meeting today.

## Best model
Working model (poster v6): Sun-frame + time-of-year inputs (n·S n·z n·E n·vS n·vE n·x⊕ n·y⊕ sinλ⊕ cosλ⊕),
64-64-32-16 gelu MLP, Adam, batch 512, one-cycle LR (peak 1e-3), 750 epochs, 5-network average, corrected data (z115).
Six shifted month-on/month-off splits, between-month windows (sky map): median |error| 0.0159%, p95 0.063%, within 2°
of the ecliptic 0.083%, above 60° 0.0125%. (Experimental, not adopted: + Kelsall's fixed dust-band profiles cuts the
ecliptic error to 0.034%.)

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
- Mentor's feedback on poster v6 (meeting Oct 19). Fig. 7 uses 3.5° patches (user's choice, Oct 19); the 7° blend is
  kept as poster_{light,dark}_7deg.

Decided 2026-10-19: no fixed Kelsall dust-band inputs for now (they import Kelsall's band shapes/parameters, i.e. part
of the simulator's answer); the poster stays on the 750-epoch model without bands. Future: learn the band parameters
from the data.

## Next up
Mentor meeting (Oct 19). Later: learnable dust-band layer (band widths, tilts, nodes and shape fitted with the network,
started from Kelsall's values) for real data; trailing-cloud knockout test (train without the cloud);
ZodiOnboarding.ipynb to match the other projects.
