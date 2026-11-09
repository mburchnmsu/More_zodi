# Slide content: Week 13 meeting with Dr. Saydjari

Paste into the running deck after the "Week 13" divider (not included here). All figures are dark-background PNGs in
`figures/`. Order: the 2D Mollweide maps, difference imaging, then checking for a constant term in our model, followed by
open questions. Numbers come from notebooks 11042026, 11082026 and 11092026.

---

## 2D Mollweide

### Slide 1: Figure slide
- **Title:** With vs without earth, in 2D
- **Figure:** `figures/11042026_earth2d_moll.png`
- **Caption:** The two maps agree to ~0.006% rms, and neither shows a trailing-cloud residual.
- **Speaker notes:** Top row: frame of Earth's motion, centred behind Earth where the trailing cloud is. Bottom row:
  ecliptic frame. Columns: without the earth-centric inputs, with them (n·δ̂, n·M̂, round 43), and their difference.

### Slide 2: Table slide
- **Title:** Do the earth inputs help?
- **Table:**

| Metric | Without earth inputs | With earth inputs | Change |
|---|---|---|---|
| Median error | 0.0130% | 0.0130% | 0% |
| 95th percentile | 0.038% | 0.037% | −3% |
| Within 2° of the ecliptic | 0.0181% | 0.0173% | −4% |
| Mean test MSE (×10⁻⁸) | 1.52 | 1.56 | +3% |

- **Caption:** No difference on simulated data, which is what we expect since Kelsall has no Earth or Moon light.
- **Speaker notes:** All the changes are within the seed-to-seed spread. As a positive control we injected fake
  Earthshine and moonlight at 1% of the sky: with the earth inputs the model learns 100% of both, and without n·M̂ it
  misses the moonlight completely.

### Slide 3: Figure slide (optional)
- **Title:** What happens if we remove the trailing cloud?
- **Figure:** `figures/11042026_r45_cloud_onoff.png`
- **Caption:** ON − OFF reproduces Kelsall's cloud with slope 1.0000, so the model learns the cloud without being told
  it exists.
- **Speaker notes:** Without the cloud the test MSE is 1.46 vs 1.52 (−4%, within the noise). What's left after
  subtracting the cloud is 0.006–0.012% of the sky, about 0.2% of the cloud itself.

---

## Difference imaging

### Slide 4: Figure slide
- **Title:** NEP over 15 months, minus its own median
- **Figure:** `figures/11042026_talltable_L8_nep_ours.png`
- **Caption:** Once each curve has its own median subtracted, the data, SPHEREx's zodi model and our model trace the
  same seasonal change.
- **Speaker notes:** One 0.23° HEALPix patch at the north ecliptic pole, 1020 exposures, at 5 μm. The panels are:
  raw curves, measured − model, each curve minus its own median over time (the difference image), and ours − ZodiPy
  (≤ 0.05%). The time-variable amplitude is 0.148 measured vs 0.144 for ours.

### Slide 5: Table slide
- **Title:** Is the time variation right?
- **Table:**

| Patch | Exposures | Scale a (measured ≈ a·ours + b) | Offset b (MJy/sr) | Scatter (MJy/sr) |
|---|---|---|---|---|
| North ecliptic pole | 1020 | 1.024 | 0.076 | 0.006 |
| South ecliptic pole | 808 | 0.931 | 0.113 | 0.005 |
| β = 30°, λ = 210° | 27 | 1.087 | 0.075 | 0.006 |
| Ecliptic, λ = 45° | 19 | 1.031 | 0.165 | 0.016 |

- **Caption:** The seasonal change matches to ~0–10%, but the sky sits 0.08–0.17 MJy/sr above Kelsall, which led to the
  next question.

---

## Checking for a constant term in our model

### Slide 6: Big-title slide
- **Title (3–4 lines):** Is the extra light a constant sky, or zodi that Kelsall misses?
- **Figure:** `figures/11092026_offsetmap_L6_grid2.png`
- **Caption:** 192 patches across the sky: the offset follows the ecliptic, not the Galaxy, except right on the plane.
- **Speaker notes:** Offset = median over exposures of (measured − our model), one 0.92° patch per grid point, 4.9–5.1 μm.
  The tall table's web service was down, so we downloaded the database partitions (389 GB) to Discovery and ran the
  same SQL locally. Patches on the Galactic plane reach 0.5–2.2 MJy/sr; everything else is 0.08–0.35.

### Slide 7: Figure + table slide
- **Title:** What explains the offset at 5 μm?
- **Figure:** `figures/11092026_offset_spectrum_L6_grid2.png` (or crop its left panel)
- **Table (144 patches with |b| > 15°):**

| Model of the offset | Fit | R² |
|---|---|---|
| Constant + Kelsall scale | 0.036 + 0.181·Kelsall | 0.65 |
| Constant + Galaxy (csc\|b\|) only | 0.128 + 0.001·csc\|b\| | 0.00 |
| Constant + SPHEREx zodi model scale | 0.036 + 0.009·model | 0.01 |

- **Caption:** Kelsall is ~19% too faint at 5 μm; a Galactic sky explains none of the offset.
- **Speaker notes:** Our model equals Kelsall to ≤ 0.05% on these exposures, while Kelsall is off from the data by ~19%,
  so our model is ~400× closer to Kelsall than Kelsall is to the real sky. SPHEREx's own zodi model leaves only a
  constant 0.036 MJy/sr, so their pipeline already includes this scale-up.

### Slide 8: Table slide
- **Title:** How much too faint is Kelsall at each wavelength?
- **Table:**

| Window (μm) | Kelsall too faint by | Constant left vs SPHEREx model (MJy/sr) |
|---|---|---|
| 1.3 | 7% | 0.056 |
| 1.65 | 14% | 0.043 |
| 2.25 | 12% | 0.031 |
| 2.85 | 12% | 0.028 |
| 3.45 | 31% | 0.026 |
| 4.1 | 17% | 0.036 |
| 4.55 | 14% | 0.039 |
| 4.95 | 19% | 0.036 |

- **Caption:** Too faint at every wavelength, with a real peak at 3.45 μm (0.31 ± 0.03).
- **Speaker notes:** Fit c0 + c1·Kelsall + c2·csc|b| over 144 off-plane patches; errors ±0.01–0.04. The 48-patch grid
  from the night before gave the same values within errors. Below 3 μm a starlight-like csc|b| term shows up (no star
  masking yet).

### Slide 9: Figure slide
- **Title:** Which part of Kelsall is too faint?
- **Figure:** `figures/11092026_offset_comps_spectrum_L6_grid2.png`
- **Caption:** The smooth cloud is too faint at every wavelength; the trailing feature only looks weaker at 4–5 μm.
- **Speaker notes:** We fit measured − Kelsall = constant + Σ k·component over time, with one constant per patch. Cloud:
  k = +0.04 to +0.32. Feature: −0.63 ± 0.07 at 5 μm and −0.67 ± 0.09 at 4.1 μm, but +0.48 at 1.65 μm, so it is only a
  hint. Bands are consistent with zero. SPHEREx's own model shows the same cloud pattern (+0.09 to +0.26).

### Slide 10: Figure slide (optional)
- **Title:** 3.45 μm offset map
- **Figure:** `figures/11092026_offsetmap_L6_grid2_w3.4.png`
- **Caption:** The window where Kelsall is furthest off (31%).

---

## Open questions (one slide each, title only)

### Slide 11
- **Title:** Is the 3.45 μm excess known, or something new?

### Slide 12
- **Title:** Should we fit a zodi scale per wavelength, or train on SPHEREx's zodi model instead of Kelsall?

### Slide 13
- **Title:** Is it time to mask stars?

### Slide 14
- **Title:** Can we trust the trailing-feature result, given we see each patch only twice a year?
