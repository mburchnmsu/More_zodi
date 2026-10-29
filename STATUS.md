# More_zodi status
Updated: 2026-10-28 22:45, DESKTOP-BBASC81

## Headline
Round 34 is complete. Training the parallax dust-band model for **2000 epochs instead of 500** gives the best 500-day
model so far. On the full 6-shift sky map: median 0.0157% → **0.0130%**, p95 0.049% → **0.035%**, within 2° of the
ecliptic 0.0285% → **0.0162%**. 5 of 6 splits improve by 29–41%; shift 30 is worse (+11%, mild overfitting in 2 of 5
seeds). Round 35: a cos×exp learning-rate schedule beats one-cycle at 500 epochs (shift 0 −21%, shift 30 −8%). **Poster: final (presented 2026-10-23).**

## Best model
500 days, heliocentric inputs (default for ZODI_DATA="z500" since Oct 21): n·S n·z n·E n·vS n·vE n·x⊕ n·y⊕ sinλ⊕ cosλ⊕
(no n·J) + S·x S·y S·z for the parallax band layer (sweeps/band_layer.jl, arch :bandplx: 3 Kelsall-shaped bands with
trainable inclination, node, width, shape and effective distance R), then a 64-64-32-16 gelu MLP, Adam, batch 512,
one-cycle LR (peak 1e-3), **2000 epochs** (round 34, sweeps/configs_v34.jl), 5-network average, corrected 500-day targets.
Full sky map: median 0.0130%, p95 0.035%, ecliptic 0.0162%, above 60° 0.0120%.
Same at 500 epochs (rounds 31–32): 0.0157% / 0.049% / 0.0285% / 0.0134%.
Without the band layer (round 29, 500 epochs): 0.0154% / 0.050% / 0.0499% / 0.0130%.
Poster model (final; 140 days, barycentric, 750 epochs): median 0.0159%, p95 0.063%, ecliptic 0.083%.

## Latest results (Oct 23–27) — notebooks: 10242026, 10262026, 10272026
| Shift | 500 epochs | 2000 epochs | Change (ensemble test MSE) |
|---|---|---|---|
| 0 (poster split) | 2.44e-8 | **1.47e-8** | −40% |
| 10 | 2.37e-8 | **1.48e-8** | −38% |
| 20 | 2.40e-8 | **1.54e-8** | −36% |
| 30 | **2.53e-8** | 2.80e-8 | +11% |
| 40 | 2.43e-8 | **1.73e-8** | −29% |
| 50 | 2.37e-8 | **1.43e-8** | −40% |

- Shift 30: seeds 43 and 45 sit well above the rest from epoch ~1000 (4.2e-8 / 4.7e-8 vs 2.7–3.0e-8), mostly in the
  withheld windows at days 180–270. All five flatten from ~epoch 1600 while the training loss keeps falling
  (figures/10272026_r34_seed_curves.png; sweeps/diag34_shift30.jl, sweeps/diag34b.jl).
- Fitted bands at 2000 epochs (30 networks): inclinations ~1° (unchanged), band 2 width 1.62° and R 1.41 AU (unchanged).
  The nodes move from 18–23° to 26–29° with less spread; bands 1 and 3 come out narrower (3.0°, 4.6°) and closer
  (1.56, 1.72 AU).
- Figures: figures/10272026_r34_sky_6shifts.png (full map), 10272026_r34_loss.png, 10272026_r34_seed_curves.png.
- The run lost ~36 h (Sat 22:39 → Mon 10:28) to Modern Standby while the laptop was on battery; nothing was lost.

## Earlier (Oct 20–23)
Heliocentric inputs replaced n·J (the Sun moved 0.0035 AU about the barycentre over 500 days). Mentor's trailing-cloud
tests: test 1 passed; test 2 (no Earth dot products) clearly worse. Learnable bands (round 30), the parallax band layer
(rounds 31–32: ecliptic 0.050% → 0.0285%), Earth-centric null test passes (round 33). Notebooks 10202026–10232026.

## Round 35 (done 04:35 Wed Oct 28) — notebook: notebooks/10282026.ipynb
Learning-rate schedule test: cos×exp with a 5% warm-up (new schedule `:cosexpw` in sweeps/mb_train.jl; peak 2e-3,
decay 3) against one-cycle (peak 1e-3). Both have the same average learning rate (5.1e-4), so only the shape differs.
Parallax band layer, 500 epochs, shifts 0 and 30 × 5 seeds (sweeps/configs_v35.jl; report sweeps/report35.jl →
figures/10282026_r35_schedule.png).
- **cos×exp wins.** Shift 0: ensemble MSE 2.44e-8 → **1.94e-8** (−21%, ~2.7 standard errors over seeds), median
  0.0162% → 0.0149%, ecliptic 0.0292% → 0.0247%. Shift 30: 2.53e-8 → **2.32e-8** (−8%, within seed noise), ecliptic
  0.0299% → 0.0261%.
- The loss falls much faster early. The withheld-month loss flattens from ~epoch 350 while the training loss keeps
  falling.

## Mentor's requests (Oct 28 afternoon) — notebook 10282026 §4–6, sweeps/mentor1028.jl
Best model (round 34), saved runs only.
- **Interpolation vs extrapolation sky map.** The usual map already uses interpolation windows only: median 0.0130%,
  p95 0.035%, ecliptic 0.0162%. Adding the first/last withheld windows changes little (0.0132% / 0.035% / 0.0166%).
  The extrapolation windows alone (10% of exposures, only 10–30 days past the training data): 0.0168% / 0.043% / 0.0226%,
  about 30% worse. Figure: figures/10282026_r34_interp_extrap_sky.png.
- **2-D trailing-cloud residual map** (longitude from Earth's direction of motion, 0–360°, × ecliptic latitude): **no
  residual from the cloud.** Fitted missing fraction −0.0001 ± 0.0001 near the plane. Behind vs ahead of Earth:
  −0.0006% vs +0.0005%, against −0.07% if 1% of the cloud were missed. SPHEREx covers 38% of this frame (near 0°, 180°
  and the poles). Figure: figures/10282026_r34_trailing_2d.png.
- **Precision target (user leading, reading the Kelsall paper):** our 0.013% is emulation error (network vs Kelsall).
  Kelsall's residuals are model vs DIRBE data. The target should come from SPHEREx's zodi-subtraction needs.

## Real SPHEREx data (Oct 28–29) — notebook 10292026, realdata/
The user's task: one sky point, all SPHEREx images of it at 4.9–5.1 μm, a movie over time. Point: the north ecliptic
pole. Detector D6 covers 4.41–5.01 μm, so the window is 4.9–5.01 μm. IRSA TAP search plus footprint-based wavelength
estimates selected 644 images; 200-px cutouts downloaded (3.3 GB, git-ignored in data/spherex_real/). **435 frames**
with the pole at 4.90–4.97 μm, June 2025 – September 2026 (371 qr2 + 64 qr3).
- Movie figures/10292026_nep_movie.mp4 (git-ignored; realdata/make_movie.jl), light curve, montage. Stars not masked.
- Yearly cycle of ~±15% at the pole, matched by ZodiPy (amplitude 14.3% vs 14.8%, peaks ~8 days apart). qr2: image =
  1.06–1.09 × ZodiPy + 0.10 MJy/sr, scatter 0.006–0.008 MJy/sr (~1.5%).
- SPHEREx's own zodi layer: 1.04 × ZodiPy in qr2, 1.17 × in qr3 (a one-day jump at the release boundary; the image level
  drops ~7% too). The releases are calibrated differently: ask the mentor which to trust.

## Running now
Round 36 (started 17:28 Oct 28): cos×exp schedule on shifts 10, 20, 40, 50 × 5 seeds, 500 epochs (sweeps/configs_v36.jl,
run_round36.ps1). Shift 10 done (ensemble 1.96e-8 vs one-cycle 2.37e-8, −17%); the rest expected ~07:30 Oct 29.
Report: sweeps/report36.jl.

## Waiting on user
Cluster access: Zodi is moving to the NMSU HPC cluster (Slurm; access form in progress, 2026-10-27). No cluster work
yet. Rule: never run heavy compute on the login node; every heavy step goes through `sbatch` on compute nodes, using
`module load` for software and `squeue` to monitor. Template: pipeline/cluster/train_array.sbatch (partition, account and
module names still marked EDIT; precompilation should run in a job, not on the login node).

Decided 2026-10-19: no fixed Kelsall dust-band inputs; learn the band parameters from the data (done: round 30–32).

## Next up
Options from round 35: cos×exp on the remaining 4 shifts at 500 epochs (~11 h, full sky map); cos×exp at 2000 epochs;
a fix for the shift-30 overfitting (a validation month with best-epoch selection, or weight decay),
needs the user's OK. Other options: per-band radial profile (inner cutoff + ~1/R falloff, as in ZodiPy) instead of one
effective R; one-at-a-time ablation table; Earth-centric terms + star masking on real SPHEREx data (masking only when the
user says so).
