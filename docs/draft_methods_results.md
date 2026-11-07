# A neural-network emulator of the zodiacal light for SPHEREx — methods and results (draft)

*Working draft, Nov 6 2026. Mark Burch (NMSU), advisor Dr. Andrew Saydjari. Built from the project log (STATUS.md) and
the dated notebooks; every number below traces to a notebook or report script named in brackets. Sections marked
**[pending]** wait on running work.*

## 1. Goal
SPHEREx sees the zodiacal light (sunlight scattered and re-emitted by interplanetary dust) in every exposure, and it must
be modelled and subtracted. The standard model, Kelsall et al. (1998), as implemented in ZodiPy, integrates a 3-D dust
cloud along each line of sight. That is slow, and it is fixed: it cannot learn where the real sky differs from it.
This project trains a small neural network to reproduce Kelsall's prediction from the observing geometry alone:
fast to evaluate, differentiable, and, in a later step, able to be refit to SPHEREx's own data.

Two questions run through the work:
1. **Emulation.** How closely can a network reproduce Kelsall on exposures it never saw (new times, new sky)?
2. **Reality.** How does Kelsall (and so the emulator) compare with the real SPHEREx sky?

## 2. Data
* **Training targets:** ZodiPy (Kelsall 1998, DIRBE parameters) sky brightness at 5.0 μm for 1,520,194 simulated SPHEREx
  pointings over 500 days, MJD 60789.8–61290.0 (the "z500" set). The original delivery had two generation errors; the
  corrected targets are used throughout.
* **Real data:** SPHEREx images through the NYU "tall table" (Hainje & Hogg), a pixel-level SQL/Parquet database with,
  per pixel, flux, the SPHEREx pipeline's own ZODI layer, wavelength, HEALPix index and exposure time. It is queried
  through its web service (the full ~111 TB copy is being transferred to the NMSU HPC). Earlier tests used 200-pixel
  IRSA cutouts. The tall table matches the newer (qr3) cutouts to 0.4% in flux, but not the older qr2 release (−7% flux,
  +13% zodi layer). Numbers based on qr2 are therefore marked as superseded.

## 3. Model

### 3.1 Inputs
All positions are heliocentric (the Sun's 0.0035 AU wobble about the barycentre is removed). With n the unit line of
sight, S and E the heliocentric positions of SPHEREx and Earth, and vS, vE their velocities, the network sees:

| input | meaning |
|---|---|
| n·S, n·E | line of sight · SPHEREx / Earth position |
| n·vS, n·vE | line of sight · SPHEREx / Earth velocity direction |
| n·z | line of sight · ecliptic pole (ecliptic latitude) |
| n·x⊕, n·y⊕ | line of sight in the frame that turns with Earth (x⊕ = Sun→Earth, y⊕ = ahead of Earth) |
| sin λ⊕, cos λ⊕ | Earth's orbital phase |
| n·x, n·y, n·z, S·x, S·y, S·z | fixed-axis pointing and SPHEREx position; used only by the band layer (3.2) |

### 3.2 Architecture
* **Parallax dust-band layer** [notebook 10232026; `sweeps/band_layer.jl`]. Three Kelsall-shaped dust bands, each with
  trainable inclination, ascending node, width, shape and an effective distance R. From the pointing and SPHEREx's
  position, the layer computes each band's latitude profile as seen from SPHEREx (including parallax) and passes the
  3 profiles on. This gives the network the sharp, near-ecliptic band structure, which a plain MLP smooths over.
* **MLP:** the 9 geometric inputs + 3 band profiles → 64-64-32-16 GELU layers → brightness.
* **Ensemble:** the average of 5 networks trained with different seeds (42–46).

### 3.3 Training
Inputs standardised with the training mean and standard deviation. Adam, batch 512, 1000 epochs. Learning-rate
schedule "cos×exp" (rounds 35–38): a 5% cosine warm-up to the peak 2×10⁻³, then lr = peak · ½(1 + cos πu) · e^(−3u) over
the remaining fraction u of training. Loss: mean squared error on the brightness (MJy/sr). Jobs run on the NMSU Discovery cluster (Slurm, 5–6 trainings per
job, ~6–10 h). A cluster rerun reproduced the laptop's results to every printed digit [STATUS, job 689233].

### 3.4 Validation design
The 500 days are cut into **alternating 30-day windows**: even windows train, odd windows are withheld. Shifting the cut
by Δ = 0, 10, …, 50 days gives 6 splits, so every day is withheld in at least one split. The main score is the
**interpolation** error: withheld windows with training data on both sides. Withheld windows at the start or end of the
mission (extrapolation) are reported separately. Errors are quoted as % of Kelsall's brightness, on a sky map built from
the withheld exposures of all 6 splits.

## 4. Emulation results

### 4.1 Accuracy
Best model (parallax band layer, cos×exp 1000, 6 splits × 5 seeds) [notebooks 10292026, 10302026]:

| | median \|error\| | p95 | within 2° of the ecliptic | above 60° |
|---|---|---|---|---|
| best model | **0.0130%** | 0.038% | 0.0181% | 0.0118% |
| same, 2000 epochs (round 39) | 0.0129% | 0.035% | 0.0163% | 0.0119% |
| without the band layer, 500 epochs (round 29) | 0.0154% | 0.050% | 0.0499% | 0.0130% |

* Mean ensemble test MSE 1.52×10⁻⁸ over the 6 splits (per split 1.38–1.70).
* Extrapolation 10–30 days past the training data is ~30% worse (median 0.0168%, ecliptic 0.0226%) [10282026 §4].
* For scale: Kelsall's own residuals against DIRBE are ≥0.28%, and SPHEREx's pipeline zodi model differs from ZodiPy by
  several % [10292026 §9]. The emulation error is ~20× below the model's own accuracy, so it is not the limiting factor.

### 4.2 What helped (in order of size)
1. **Earth's orbital phase (sin/cos λ⊕):** 44–65× lower interpolation error [10092026].
2. **The parallax band layer:** ecliptic error 0.050% → 0.0285% at 500 epochs [10232026].
3. **Longer training with a better schedule:** cos×exp at 1000 epochs matches one-cycle at 2000. At 2000 epochs it gives
   the best map but starts to overfit on 2 of 6 splits [rounds 34–39].
4. Not helpful: AdamW weight decay (marginal) [round 41]; best-epoch selection on a validation month (failed: the
   validation window removed the only training data for a 90-day stretch of Earth's orbit) [round 42].

### 4.3 Input ablation [11072026]
Each MLP input (or pair) and the band layer removed one at a time; splits 0 and 30 × 3 seeds:

| removed | test MSE ÷ full model | ecliptic (\|β\| < 2°) | whole-sky median |
|---|---|---|---|
| nothing | 1.00 | 0.0189% | 0.0133% |
| n·z | **2090** | 0.098% | 0.080% |
| sin/cos λ⊕ | **1062** | 0.305% | 0.151% |
| band layer | **1.29** | **0.0289%** | 0.0135% |
| n·E / n·x⊕,n·y⊕ / n·S / n·vS / n·vE | 1.01 / 0.98 / 0.95 / 0.93 / 0.93 | 0.0179–0.0191% | 0.0129–0.0135% |

* n·z is the only input that carries the **sign** of the ecliptic latitude, and Kelsall's tilted cloud is not
  north–south symmetric. Earth's orbital phase is what lets the model follow the year.
* The band layer is what brings the ecliptic error down.
* The other inputs come in near-duplicate pairs (SPHEREx is ~5×10⁻⁵ AU from Earth: n·S ≈ n·E, n·vS ≈ n·vE), so removing
  one changes nothing beyond seed noise (~±9%).

### 4.4 Checks on the Earth-related terms
* **Earth-centric null test** [11042026 §1–2]. Adding the directions to Earth (n·δ̂, δ = S − E) and to the Moon (n·M̂)
  changes nothing: MSE 1.56 vs 1.52, with − without rms 0.006%. That is expected, since the simulated sky has no
  Earthshine or moonlight.
* **Positive control** [11042026 §3]. A fake Earthshine and moonlight injected at 1% of the sky are learned in full when
  these inputs are present (fitted fractions 1.00 / 1.00; test MSE 40–60× lower than without them). Without n·M̂ the
  moonlight is missed. The Earthshine is ~90–98% learned even without n·δ̂, because the Earth direction can be rebuilt
  from the other inputs. So the null test is sensitive, and for real data n·M̂ is the input that matters.
* **Earth-trailing dust cloud** [11042026 §4]. The model was retrained on the sky with Kelsall's trailing cloud removed
  (the cloud is 2.4% of the sky at the median, 9% at most). The accuracy is the same (MSE 1.46 vs 1.52). The difference
  between the two models' predictions reproduces the cloud with slope 1.0000, leaving 0.006–0.012% of the sky (0.2% of the
  cloud). The network learns the cloud fully from the geometry.

## 5. Real SPHEREx data

### 5.1 The emulator on real exposures
For each real exposure, the geometry is taken from the nearest simulated exposure (≤ ~1 min away). Our 5 μm prediction
is moved to the exposure's wavelength with ZodiPy's spectral shape. On real exposures, the emulator equals ZodiPy to
0.01–0.03% [`realdata/talltable_ours.jl`].

### 5.2 Kelsall vs the real sky
Per exposure, the tall table's median over a 0.23° HEALPix patch at 4.9–5.0 μm. Fit: measured = a · ours + b
[`realdata/talltable_bins.py`, figures `11042026_talltable_L8_*`]:

| patch | exposures | a | b (MJy/sr) | time-variable amplitude, measured / ours (MJy/sr) | scatter (MJy/sr) |
|---|---|---|---|---|---|
| north ecliptic pole | 1020 | 1.024 | 0.076 | 0.148 / 0.144 | 0.006 |
| south ecliptic pole | 808 | 0.931 | 0.113 | 0.063 / 0.061 | 0.005 |
| β = 30°, λ = 210° | 27 | 1.087 | 0.075 | 0.356 / 0.320 | 0.006 |
| ecliptic, λ = 45° | 19 | 1.031 | 0.165 | 0.348 / 0.348 | 0.016 |

* **The time variation is right.** Kelsall's seasonal change of the zodiacal light matches the data to ~0–10% in amplitude,
  with 1–2.5% scatter.
* **There is an extra offset.** The real sky is brighter than Kelsall by 0.08–0.17 MJy/sr, more on the ecliptic. So it
  is not only a uniform extragalactic background.
* SPHEREx's pipeline zodi layer fits with a = 0.93–0.96 and b = 0.05–0.13 MJy/sr.

### 5.3 Where the offset comes from [pending: tall-table service]
The next step maps the offset over 48 patches across the sky. If it follows ecliptic latitude, it is zodiacal light that
Kelsall misses. If it follows Galactic latitude, it is a fixed sky component. The query and analysis scripts are ready.
The tall-table web service has been down since Nov 4 (a server-side database error).

## 6. Status and next steps
* Ablation table (round 46, running).
* Offset map over the sky (waiting on the tall table).
* Per-band radial profiles (inner cutoff + ~1/R falloff) instead of one effective distance per band, aimed at the
  remaining ecliptic error.
* Refitting the emulator to SPHEREx data (with star masking) once the full tall table is on the HPC. This is the step
  that goes beyond Kelsall.
