# Week 15 task 6 (redefined Nov 22): a geometric network trained on the change only

Goal: a rotation-invariant network, built from the onboarding notebook's vector registry, that predicts how the zodi sky
changes with time better and more consistently than SPHEREx's ZODI column. No absolute level is borrowed: no SPHEREx
ZODI and no Kelsall × 1.165 added back. Not launched; waiting for approval.

## Target: change only, per exposure × level-9 cell
1. **New pass over the full tall table on Colibrí** (realdata/tt_change.py, built from tt_diffmed.py). Per partition:
   - pixels at 4.9–5.1 μm with flags = 0 (stars and every other flagged pixel masked);
   - c = flux − the pixel's level-15 (6.4″) median of flux over time, which removes the static sky pixel by pixel;
   - per (exposure, level-9 cell, 6.9′): one 3σ MAD clip, then the median of c, plus n_pix and the median λ.
   - The same is done for SPHEREx's ZODI (ΔZODI = ZODI − its own per-pixel median), for the baseline only.
2. **Training loss:** for each cell, take residual = c − f(geometry, λ) on that cell's training visits. The loss is the
   variance of that residual about its own mean over those visits. Any per-cell constant (the static sky, or an
   absolute zodi level) drops out, so the network learns only how zodi changes with time and with λ.
3. λ is an input because each visit sees a cell at a different wavelength; with ZODI no longer removed first, the
   spectral slope of zodi is part of the change (the 4-line problem). Caveat: any spectral slope of the static sky
   leaks in the same way; it is small at 5 μm, and the ZODI baseline carries the same leak, so the comparison is fair.

## Inputs (onboarding registry, all dot products, standardized)
- **Arm A, base registry {n̂, S⃗, ẑ} + λ:** n·S, n·z, S·z, S·S. Rotation-invariant: the Week 15 card's "can't
  measure the angle of direction".
- **Arm B, A + v̂_E** (Earth's velocity direction: n·v̂E, S·v̂E, z·v̂E). This is the "more time-variable inputs" arm.
  It stays invariant under rotation about ẑ and gives leading vs trailing (Earth's ring and trailing cloud, which
  round 49 showed is the ~1% the base set misses).
- S⃗ and v̂_E come from an ephemeris at each exposure's mid-time. SPHEREx's 5×10⁻⁵ AU orbit around Earth is ignored for
  now. Earth-centric vectors (n·δ̂, the Moon) are the next step, for Earthshine and stray light.
- Architecture: the plain MLP 64-64-32-16 with gelu, as in round 49 (no band layer, which needs x̂, ŷ).

## Comparison with SPHEREx ZODI, on the same change-only footing
- Both models are judged on the same held-out visits:
  - network residual r_N = c − f, after removing each cell's median of r_N over its training visits;
  - ZODI residual r_Z = c − ΔZODI, with the same per-cell median removed.
- Numbers reported:
  - robust rms (1.4826 MAD) and median |r|, in MJy/sr and as % of the local zodi;
  - the fraction of cells where the network beats ZODI;
  - maps of the per-cell time spread (as in 11212026_fullsky_diffmed_maps.png) and residual vs time ("consistency").
- Split: time-blocked, 30-day blocks, 5 folds (onboarding rung 2; same as the task 1 months test).

## Runs and core-hours
- **Extraction:** about 200 core-hours, 10 backfill tasks × 4 CPUs × ~5 h (as array 713).
  - Output: about 200M rows full sky, kept in my Colibrí home (not in git).
  - Training draws about 5M rows from every 8th partition; evaluation uses all rows.
- **Training:** 2 arms × 5 folds × 2 seeds = 20 runs, about 2 h × 4 CPUs each, so about 160 core-hours.
- **Total:** about 360 core-hours. Wall time: about half a day for extraction, then 4–6 h of training (backfill).
- Local work first (no cluster needed): the loss, the ephemeris step and the comparison script, tested on the 192
  patches already on the ThinkPad.
