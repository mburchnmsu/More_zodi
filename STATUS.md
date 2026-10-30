# More_zodi status
Updated: 2026-10-30 15:40, DESKTOP-BBASC81

## Headline
Round 34 is complete. Training the parallax dust-band model for **2000 epochs instead of 500** gives the best 500-day
model so far. On the full 6-shift sky map: median 0.0157% → **0.0130%**, p95 0.049% → **0.035%**, within 2° of the
ecliptic 0.0285% → **0.0162%**. 5 of 6 splits improve by 29–41%; shift 30 is worse (+11%, mild overfitting in 2 of 5
seeds). Rounds 35–36: a cos×exp learning-rate schedule beats one-cycle at 500 epochs on all 6 shifts (mean −12%,
ecliptic 0.0285% → 0.0247%). **Round 37: cos×exp at 1000 epochs beats one-cycle at 2000** on shifts 0 and 30
(ensemble MSE 1.38 / 1.57 vs 1.47 / 2.80; shift 30 no longer overfits). First real SPHEREx data: the north ecliptic pole at 5 μm (notebook 10292026). **Poster: final (presented 2026-10-23).**

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

## Round 36 (done 06:35 Thu Oct 29) — notebook 10292026 §5
cos×exp schedule on all 6 shifts, 500 epochs (sweeps/configs_v36.jl; report sweeps/report36.jl →
figures/10292026_r36_sky.png). Ensemble test MSE ×10⁻⁸, shifts 0/10/20/30/40/50:
one-cycle 500: 2.44 2.37 2.40 2.53 2.43 2.37 (mean 2.42); **cos×exp 500: 1.93 1.96 2.25 2.32 2.28 2.10 (mean 2.14, −12%)**;
one-cycle 2000: 1.47 1.48 1.54 2.80 1.73 1.43 (mean 1.74).
- cos×exp wins on every split (−6 to −21%). Per seed, that's 2.4–2.9 standard errors on shifts 0/10/50 and 0.7–1.2 on 20/30/40.
- Sky map, 6 shifts: cos×exp 500 median 0.0147%, p95 0.046%, ecliptic 0.0247%, above 60° 0.0128% (one-cycle 500:
  0.0157 / 0.049 / 0.0285 / 0.0134). One-cycle 2000 is still the best model (0.0130 / 0.035 / 0.0162 / 0.0120).

## Real data, Oct 29 — notebook 10292026 §6–7
- qr3-only pole movie (figures/10292026_nep_qr3_movie.mp4, 64 frames, git-ignored): SPHEREx zodi = 1.168 × ZodiPy, steady.
- Ecliptic point at longitude 45° (RA 42.536, Dec 16.336, Galactic latitude −38°; chosen by realdata/scan_ecliptic.py): only 8 frames
  at 4.9–5.1 μm (3 visits: Aug 2025, Jan 2026 in qr2; Aug 2026 in qr3). Zodi ~2× the pole; the same qr2→qr3 jump
  (1.06 → 1.20 × ZodiPy); non-zodi light ~0.2 MJy/sr. Data in data/spherex_real/ecl045_d6* (git-ignored).
- Geometry figures (§8): figures/10292026_geometry_3panel.png / _2panel.png (realdata/geometry.py, plot_geometry.jl). Both
  perihelion (Jan 4) and the cloud's 2° tilt set the pole's yearly cycle; half the light comes from within 0.15 AU.
- Precision comparison (§9): figures/10292026_precision_compare.png (realdata/precision_compare.jl). Emulator 0.013% vs
  Kelsall-vs-DIRBE ≥0.28% (~20×), few % to 30% vs other data, SPHEREx zodi model 4–21% off ZodiPy. The emulator is not the
  limit. Literature numbers still to check against the papers (Table 5 at 4.9 μm).
- find_frames / download_cutouts / extract_frames / make_movie now take any sky point.
- Git history rewritten 2026-10-29 (template images removed); the other PC must re-clone or `git fetch; git reset --hard origin/main`.

## Round 37 (done 22:51 Thu Oct 29) — notebook 10292026 §10
cos×exp at 1000 epochs, shifts 0 and 30 × 5 seeds (sweeps/configs_v37.jl; report sweeps/report37.jl →
figures/10292026_r37_sky.png). Ensemble test MSE ×10⁻⁸, shift 0 / 30: one-cycle 500 2.44 / 2.53; cos×exp 500 1.93 / 2.32;
**cos×exp 1000 1.38 / 1.57**; one-cycle 2000 1.47 / 2.80.
- **Beats one-cycle 2000 with half the epochs.** Shift 0: a tie within seed noise. Shift 30: −44% (~3.4 standard errors),
  no overfitting (seeds 1.95–2.31).
- Sky map (shifts 0 and 30): median 0.0132%, p95 0.041%, ecliptic 0.0181%, above 60° 0.0122% (one-cycle 2000 on the same
  shifts: 0.0156 / 0.048 / 0.0183 / 0.0154).

## Running now
Round 38 (approved Oct 29, queued 23:20): cos×exp at 1000 epochs on shifts 10/20/40/50 × 5 seeds (sweeps/configs_v38.jl, run_round38.ps1), starts when Solar R4's done marker (SolarFlareForcast\sweeps\results\.lowprio_done) appears and ≥6 GB is free; ~26 h, 5 threads, ~5–6.5 GB. Then a 6-shift report vs one-cycle 2000.

## Waiting on user
Cluster access: Zodi is moving to the NMSU HPC cluster (Slurm; access form in progress, 2026-10-27). No cluster work
yet. Rule: never run heavy compute on the login node; every heavy step goes through `sbatch` on compute nodes, using
`module load` for software and `squeue` to monitor. Template: pipeline/cluster/train_array.sbatch (partition, account and
module names still marked EDIT; precompilation should run in a job, not on the login node).

Decided 2026-10-19: no fixed Kelsall dust-band inputs; learn the band parameters from the data (done: round 30–32).

## Next up
Decided Oct 29: cos×exp at 2000 epochs on all 6 shifts goes to the HPC cluster once access arrives. Round 37 suggests
cos×exp at 1000 epochs on the remaining 4 shifts (10, 20, 40, 50) is also worth running (~13 h locally, or on the
cluster); the user decides. Other options:
a fix for the shift-30 overfitting (a validation month with best-epoch selection, or weight decay),
needs the user's OK. Other options: per-band radial profile (inner cutoff + ~1/R falloff, as in ZodiPy) instead of one
effective R; one-at-a-time ablation table; Earth-centric terms + star masking on real SPHEREx data (masking only when the
user says so).
