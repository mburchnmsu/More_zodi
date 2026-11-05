# More_zodi status
Updated: 2026-11-04, DESKTOP-BBASC81

## Headline
Round 34 is complete. Training the parallax dust-band model for **2000 epochs instead of 500** gives the best 500-day
model so far. On the full 6-shift sky map: median 0.0157% → **0.0130%**, p95 0.049% → **0.035%**, within 2° of the
ecliptic 0.0285% → **0.0162%**. 5 of 6 splits improve by 29–41%; shift 30 is worse (+11%, mild overfitting in 2 of 5
seeds). Rounds 35–36: a cos×exp learning-rate schedule beats one-cycle at 500 epochs on all 6 shifts (mean −12%,
ecliptic 0.0285% → 0.0247%). **Round 37: cos×exp at 1000 epochs beats one-cycle at 2000** on shifts 0 and 30
(ensemble MSE 1.38 / 1.57 vs 1.47 / 2.80; shift 30 no longer overfits). **Round 38: on all 6 shifts it ties one-cycle
2000** (mean 1.52 vs 1.74; sky median 0.0130% both; ecliptic 0.0181% vs 0.0162%). **Round 39 (first cluster round):
cos×exp 2000 gives the best sky map** (median 0.0129%, ecliptic 0.0163%) but overfits again on shifts 30/40. Rounds 40–41: AdamW λ = 1e-4 is a marginal
gain (ecliptic 0.0161%); round 42's best-epoch selection failed (its validation window leaves a 90-day orbital hole). First real SPHEREx data: the north ecliptic pole at 5 μm (notebook 10292026). **Poster: final (presented 2026-10-23).**

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

## Round 38 (done 21:40 Fri Oct 30) — notebook 10302026 §1
cos×exp at 1000 epochs on shifts 10/20/40/50 × 5 seeds (sweeps/configs_v38.jl, ThinkPad, ~5.4 h per shift; report
sweeps/report38.jl → figures/10302026_r38_sky.png). Ensemble test MSE ×10⁻⁸, shifts 0/10/20/30/40/50:
**cos×exp 1000: 1.38 1.46 1.70 1.57 1.50 1.53 (mean 1.52)**; one-cycle 2000: 1.47 1.48 1.54 2.80 1.73 1.43 (mean 1.74).
- **A tie with one-cycle 2000 at half the epochs** (1.51 vs 1.53 without shift 30). Per seed: better on 30 (and 40,
  ~1 SE), equal on 0/10, worse on 20 (~4.5 SE) and 50 (~3 SE). No overfitting: all 30 seeds 1.5–2.3.
- Sky map, 6 shifts: median 0.0130% (tie), p95 0.038% vs 0.035%, ecliptic 0.0181% vs **0.0162%**, above 60° **0.0118%**
  vs 0.0120%. One-cycle 2000 still wins on the ecliptic.

## Real data 30° above the ecliptic (Oct 30) — notebook 10302026 §2
β = 30°, λ = 210° (RA 218.487, Dec 16.649, Galactic latitude +64°; chosen by realdata/scan_ecliptic.py at β = 30° and
40°). 15 frames at 4.9–5.1 μm, all qr2 (June 2025, Jan 2026, June 2026). January ~1.8× brighter (solar elongation ~91°
vs ~119°), matched by ZodiPy. Image = 1.11 × ZodiPy + 0.11 MJy/sr (rms 0.008), like the pole; SPHEREx zodi / ZodiPy 1.055.
Figures 10302026_b30l210_{lightcurve,montage}.png; movie git-ignored. Data in data/spherex_real/b30l210_d6* (git-ignored).

## Round 39 (Discovery, done 05:09 Sun Nov 1) — notebook 11012026
cos×exp at 2000 epochs, all 6 shifts × 5 seeds (sweeps/configs_v39.jl; jobs 689786–689791 started at once, 13–21 h;
report sweeps/report39.jl → figures/11012026_r39_sky.png). Ensemble test MSE ×10⁻⁸, shifts 0/10/20/30/40/50:
**cos×exp 2000: 1.39 1.46 1.58 2.12 1.68 1.43 (mean 1.61)**; cos×exp 1000: 1.38 1.46 1.70 1.57 1.50 1.53 (1.52);
one-cycle 2000: 1.47 1.48 1.54 2.80 1.73 1.43 (1.74).
- Sky map, 6 shifts: **median 0.0129%, p95 0.035%, ecliptic 0.0163%**, above 60° 0.0119%: best or tied everywhere
  (cos×exp 1000: 0.0130 / 0.038 / 0.0181 / 0.0118; one-cycle 2000: 0.0130 / 0.035 / 0.0162 / 0.0120).
- 2000 epochs helps the ecliptic and shifts 20/50, but overfitting returns on shifts 30 (seeds 1.89–3.94) and 40.

## Round 40 (Discovery, done 16:03 Mon Nov 2)
Round 39's setup + AdamW weight decay (new `adamw` kwarg in train_mb: lr-scaled, MLP only, band layer not decayed),
λ = 1e-4 / 1e-3 / 1e-2 × shifts 0/30/40 × 5 seeds (sweeps/configs_v40.jl; jobs 691131–691139; report sweeps/report40.jl,
numbers only). Ensemble test MSE ×10⁻⁸, shifts 0/30/40 (mean); ecliptic median over those shifts:
cos×exp 1000: 1.38 1.57 1.50 (1.48), 0.0178% · cos×exp 2000: 1.39 2.12 1.68 (1.73), 0.0164% ·
**+1e-4: 1.29 1.99 1.70 (1.66), 0.0164%** · +1e-3: 1.45 1.80 1.59 (1.61), 0.0190% · +1e-2: 6.18 6.31 6.24 (underfits).
- Decay helps shift 30 a little but no λ beats cos×exp 1000 there; 1e-3 loses the ecliptic gain. 1e-4 keeps it and gives
  the best shift 0 yet (seeds 1.60 ± 0.09). Seed 43 on shift 30 overfits every time (3.5–4.2): not a weight-size problem.
- Next candidates: best-epoch selection on a validation month; λ = 1e-4 on shifts 10/20/50.

## Round 41 (Discovery, done ~13:30 Tue Nov 3) — notebook 11032026 §1
AdamW 1e-4 on shifts 10/20/50 (jobs 691528–691530) → full 6 shifts with round 40 (report sweeps/report41.jl,
figure figures/11032026_r41_sky.png). Ensemble MSE ×10⁻⁸, shifts 0–50 (mean): 1.29 1.51 1.59 1.99 1.70 1.40 (1.58) vs
cos×exp 2000 1.61 and cos×exp 1000 **1.52**. Sky map: median 0.0129%, p95 0.035%, **ecliptic 0.0161%** (vs 0.0163% / 0.0181%).
Marginal, mostly neutral gain over no decay.

## Round 42 (Discovery, done ~13:17 Tue Nov 3) — notebook 11032026 §2
Best-epoch selection (validation = training window k = 8, t_rel ∈ [Δ+240, Δ+270); jobs 691539–691541; report
sweeps/report42.jl). **Failed: ensemble MSE 6.72 / 7.70 / 4.54 vs 1.39 / 2.12 / 1.68** (shifts 0/30/40); last-epoch
networks just as bad, best epochs 111–531. Cause: days ~135–365 of Earth's orbit are seen only once in the 500 days, so
holding out window 8 leaves a 90-day orbital-phase hole with no training data (validation MSE ~1–4 × 10⁻⁶). Every test
window degrades 2–7× (why the far ones degrade too is not proven). Retry only with a validation window whose orbital
phase repeats (days 365–500 ↔ 0–135) or a few days from each training window.

## Round 43 (Discovery, done ~08:20 Wed Nov 4) — notebook 11042026
Dr. Saydjari's Nov 3 request: the 2-D residual map as Mollweide maps (Earth-motion + ecliptic frames), with vs without
the Earth-centric inputs n·δ̂, n·M̂ (best model, cos×exp 1000, 6 shifts × 5 seeds; sweeps/configs_v43.jl, jobs
692009–692014; figure sweeps/earth2d.jl → figures/11042026_earth2d_moll.png). **Null again:** ensemble MSE mean 1.56 vs
1.52, ecliptic 0.0173% vs 0.0181%, median 0.0130% both; with − without rms 0.006%. Missing trailing-cloud share
0.0000–0.0002 ± 0.0001 in both (no trailing-cloud residual).

- Meeting deck for Dr. Saydjari (Nov 3), organized by last week's 4 tasks: https://claude.ai/artifact/Sg4Rbzq7QuvVqff4EPXsXD
  (private until shared).

## Cluster validation (job 689233, done 03:02 Oct 31)
Round 37 shift 0 (cos×exp 1000, 5 seeds) rerun on Discovery node c17: **identical to the laptop** (test MSE 1.5204,
1.7110, 1.7876, 1.5979, 2.1394e-8 for seeds 42–46, the same to all printed digits). 10.75 h total: ~16 min package
precompiling on the compute node, then ~37,000 s per run vs ~25,000 s on the laptop (cluster cores ~1.5× slower each).
MaxRSS 7.9 GB for 5 trainings. Results in sweeps/results_cluster_check/ (git-ignored).

## Cluster (NMSU Discovery, set up 2026-10-30)
Passwordless SSH from the ThinkPad (alias `discovery`). Repo in ~/More_zodi (home is backed up; scratch purges after
120 days), juliaup Julia 1.12.6 (same as the laptop), data/*.h5 copied (sha256 match). Packages precompiled by
pipeline/cluster/setup_discovery.sbatch (job 689215, 10 min). Training: `sbatch --cpus-per-task=K
pipeline/cluster/threaded.sbatch sweeps/configs_vN.jl [--only ...]`, logs in ~/More_zodi/logs/. Rule: never heavy
compute on the login node. Real SPHEREx data: the mentor is putting it on Discovery directly (no location yet).

## Waiting on user
Nothing blocking.

Decided 2026-10-19: no fixed Kelsall dust-band inputs; learn the band parameters from the data (done: round 30–32).

## Next up
**Done: rounds 44 / 44b**, positive control for the Earth-centric inputs (user's choice, Nov 4): fake Earthshine
(gE from n·δ̂) + moonlight (gM from the Moon angle) added to the target at A = 1e-2 and 1e-3 of mean y (ZODI_INJECT,
sweeps/extra_features.jl); base model vs with n·δ̂, n·M̂ (configs_v44.jl) vs base without n·S (configs_v44b.jl), shift 0
× 3 seeds. Why noS: n·δ̂ = (n·S − n·E)/|δ| is a function of the base inputs (R² 0.9998), n·M̂ is not (0.41).
sweeps/report44.jl fits (network − clean Kelsall) = cE·injected Earthshine + cM·injected moonlight + c0 on the withheld
interpolation months (1 = fully learned, 0 = missed):

| A | model | cE | cM | rms left (% of y; injected 0.364 / 0.036) |
|---|---|---|---|---|
| 1e-2 | base | 0.98 | −0.16 | 0.159 |
| 1e-2 | with n·δ̂, n·M̂ | **1.00** | **1.00** | **0.021** |
| 1e-2 | base without n·S | 0.97 | −0.09 | 0.152 |
| 1e-3 | base | 0.91 | −0.06 | 0.024 |
| 1e-3 | with n·δ̂, n·M̂ | 1.04 | 1.02 | 0.021 |
| 1e-3 | base without n·S | 0.90 | −0.06 | 0.024 |

The test works: with a real Earth-centric signal, the Earth-centric inputs learn it exactly (test MSE 40–60× lower at
1e-2), so round 43's null means there is no such signal to find in the simulated sky. Moonlight is out of reach without
n·M̂. Earthshine is learned ~90–100% even without n·δ̂, and also without n·S, so the leak is not only through n·S (the
remaining inputs and the band layer still recover the Earth direction). Figure figures/11042026_r44_injection.png.
**Done: round 45**, the mentor's "with + without Earth cloud" (Week 13): best model (cos×exp 1000) on the sky without
Kelsall's Earth-trailing cloud (ZODI_NOCLOUD; the emission file stores the cloud, so no ZodiPy rerun), 6 shifts × 5
seeds (sweeps/configs_v45.jl). Cloud on = rounds 37–38. sweeps/report45.jl: mean ensemble MSE OFF 1.46 vs ON 1.52 ×10⁻⁸
(within seed spread), same sky maps (median 0.0129 vs 0.0130%, ecliptic 0.0183 vs 0.0181%). ON − OFF reproduces Kelsall's
cloud with slope 1.0000; rms leftover 0.012% (|β|<15°) / 0.006% (whole sky) vs cloud rms 5.0 / 3.6%. The network learns
the cloud fully and it costs nothing. Figure figures/11042026_r45_cloud_onoff.png; notebook 11042026 §4.
Week 13 notes: Discovery job start-up is only 2–3 min (job start → epoch 1) since round 40; the ~16 min compile was
a one-time event after setup, so the mentor's compile-once tip already holds there (use it on Colibrí). Discovery's
normal partition also has GPU nodes (A100/V100/T4). Real data: the NYU "tall table" (web service first; the full ~111 TB
is coming to the HPC). First query works (client in ~/envs/talltable on Discovery; healpy has no Windows build):
realdata/talltable_pole.py, north ecliptic pole 4.9–5.0 μm → 811 exposures (May 2025 – Sep 2026). It matches our
qr3 cutouts (flux −0.4%, zodi −0.02%) but not our older qr2 cutouts (−7% flux, +13% zodi): the tall table has the
newer calibration, so earlier qr2-based real-data numbers (e.g. SPHEREx zodi vs ZodiPy) need redoing with it.
Figure figures/11042026_talltable_nep.png (realdata/compare_talltable_nep.jl).
**Our model on real data** (realdata/talltable_ours.jl; geometry from the nearest simulated exposure, ~1 min; wavelength
moved from 5.0 μm with ZodiPy's spectral shape, talltable_zodipy.py): it equals ZodiPy to 0.01–0.03% at every exposure.
Week 13 binning (realdata/talltable_bins.py: server-side median per exposure over a 0.23° HEALPix level-8 patch):
measured = a·ours + b with a = 1.02 (NEP, 1020 exp.), 0.93 (SEP, 808), 1.09 (30° above ecliptic, 27), 1.03 (ecliptic
λ 45°, 19) and b = +0.076/+0.113/+0.075/+0.165 MJy/sr. After subtracting each series' median over time, the time-variable
part matches: amplitude measured vs ours 0.148/0.144, 0.063/0.061, 0.356/0.320, 0.348/0.348 MJy/sr; residual
scatter 0.005–0.010 MJy/sr (1–2.5%). Kelsall's TIME variation is right to ~0–10%; real sky = Kelsall + ~0.08–0.17 MJy/sr
offset that is larger on the ecliptic (so not only a fixed extragalactic background). Figures
figures/11042026_talltable_{nep,L8_nep,L8_sep,L8_b30l210,L8_ecl045}_ours.png.
**Blocked: the tall-table web service** has been down since ~15:40 Nov 4 ("database has been invalidated…", original
error "Invalid bitpacking mode"; still down at 19:24 after 22 tries, 10 min apart, job 692355). It needs a restart by
its maintainers (still down Nov 5 12:27; the user is telling Dr. Saydjari). Discovery job 692861
(pipeline/cluster/talltable_wait.sbatch) pings it hourly for up to 3 days and then runs the queries below by itself: 0.92° (level-6) test, then the 48-patch offset map
(`sbatch pipeline/cluster/talltable_bins.sbatch 6 grid 1`, then talltable_zodipy.py + realdata/talltable_offsetmap.jl). More tasks from the Nov 3 meeting coming from the user. Other options: best-epoch selection with a
validation window whose orbital phase repeats (code exists: val_tranges + keep_best); per-band radial profile (inner cutoff + ~1/R falloff, as in ZodiPy) instead of one
effective R; one-at-a-time ablation table; Earth-centric terms + star masking on real SPHEREx data (masking only when the
user says so).
