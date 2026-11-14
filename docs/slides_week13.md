# Slide content: Week 13 meeting with Dr. Saydjari

Format (Week 14 card): each figure slide says what the plot is and the conclusion (the caption). Paste into the running deck after the "Week 13" divider (not included here). All figures are dark-background PNGs in
`figures/`; the `_notitle` copies have the long in-image title cropped off, so the slide title stands alone. Order: the
2D Mollweide maps, difference imaging, then checking for a constant term in our model, followed by open questions.
Everything is at 5 μm (real data: 4.9–5.1 μm, which in practice is 4.9–5.01 μm where SPHEREx stops). The 8-wavelength
material is kept in `docs/slides_other_wavelengths.md` for later. Numbers come from notebooks 11042026, 11082026, 11092026.

---

## 2D Mollweide

### Slide 1: Figure slide
- **Title:** With vs without earth, in 2D
- **Figure:** `figures/11042026_earth2d_moll_notitle.png`
- **What the plot is:** Our model's mean error on withheld months in 3° cells, without and with the earth inputs; top row in Earth's motion frame, bottom row in ecliptic coordinates.
- **Caption:** The two maps agree to ~0.006% rms, and neither shows a trailing-cloud residual.
- **Speaker notes:** Top row: frame of Earth's motion, centred behind Earth. Bottom row: ecliptic frame. Columns: without
  the earth inputs, with them, and with − without.

### Slide 2: Table slide
- **Title:** Do the earth inputs help?
- **Table:**

| Metric | Without earth inputs | With earth inputs | Change |
|---|---|---|---|
| Median error | 0.0130% | 0.0130% | 0% |
| 95th percentile | 0.038% | 0.037% | −3% |
| Within 2° of the ecliptic | 0.0181% | 0.0173% | −4% |
| Mean test MSE (×10⁻⁸) | 1.52 | 1.56 | +3% |

- **Caption:** No difference on simulated data, as expected since Kelsall has no Earth or Moon light.
- **Speaker notes:** All changes are within the seed-to-seed spread. In a positive control (fake Earthshine and
  moonlight at 1% of the sky), the model with the earth inputs learns 100% of both.

### Slide 3: Figure slide
- **Title:** With vs without the trailing cloud, in 2D
- **Figure:** `figures/11092026_cloud2d_moll_notitle.png`
- **What the plot is:** Mean error on withheld months for the model trained with the trailing cloud, without it, and their difference, in the same two frames.
- **Caption:** Both models are equally good, and their difference shows nothing cloud-shaped.
- **Speaker notes:** Each model is scored against its own sky: median error 0.0130% with the cloud, 0.0129% without. The
  difference map has a median of 0.0027%, and ON − OFF reproduces Kelsall's cloud with slope 1.0000.

### Slide 4: Figure slide
- **Title:** The real sky in 2D
- **Figure:** `figures/11092026_realsky2d_moll_L6_grid2_notitle.png`
- **What the plot is:** Real sky at 5 μm, each patch minus its own median over time: in Earth's motion frame (top), and seen behind minus seen ahead per patch (bottom).
- **Caption:** The real sky is ~3.5% fainter behind Earth than Kelsall predicts, and SPHEREx's model already has this.
- **Speaker notes:** 144 patches off the Galactic plane, each minus its own median over time; bottom row = seen behind
  minus seen ahead. Kelsall's whole trailing feature is ~2.6% here, but the two views are ~6 months apart, so seasonal
  errors are mixed in. **Week 14 update:** most of this −3.5% is Kelsall's 18% scale error leaking through the median
  subtraction (behind is seen at elongation 109° vs 93° ahead); with the scale fixed first it is about −1%.

---

## Difference imaging

### Slide 5: Figure slide
- **Title:** NEP over 15 months, minus its own median
- **Figure:** `figures/11042026_talltable_L8_nep_ours_notitle.png`
- **What the plot is:** Measured brightness and both models at the north ecliptic pole over 15 months, each minus its own median.
- **Caption:** With each curve's median subtracted, the data and both models trace the same seasonal change.
- **Speaker notes:** One 0.23° patch at the north ecliptic pole, 1020 exposures. The seasonal amplitude is 0.148 MJy/sr
  measured vs 0.144 for ours.

### Slide 6: Table slide
- **Title:** Is the time variation right?
- **Table:**

| Patch | Exposures | Scale a (measured ≈ a·ours + b) | Offset b (MJy/sr) | Scatter (MJy/sr) |
|---|---|---|---|---|
| North ecliptic pole | 1020 | 1.024 | 0.076 | 0.006 |
| South ecliptic pole | 808 | 0.931 | 0.113 | 0.005 |
| β = 30°, λ = 210° | 27 | 1.087 | 0.075 | 0.006 |
| Ecliptic, λ = 45° | 19 | 1.031 | 0.165 | 0.016 |

- **Caption:** The seasonal change matches to within 10%, but the sky sits 0.08–0.17 MJy/sr above Kelsall.

---

## Checking for a constant term in our model

### Slide 7: Big-title slide
- **Title (3–4 lines):** Is the extra light a constant sky, or zodi that Kelsall misses?
- **Figure:** `figures/11092026_offsetmap_L6_grid2_notitle.png`
- **What the plot is:** The median of measured − our model for 192 patches of 0.92° across the sky, at 5 μm.
- **Caption:** Off the Galactic plane the offset is a small 0.08–0.35 MJy/sr; on the plane it jumps to 0.5–2.2.
- **Speaker notes:** 192 patches of 0.92° across the sky. The tall table's web service was down, so we downloaded its
  partitions (389 GB) to Discovery and ran the same SQL there.

### Slide 8: Figure + table slide
- **Title:** What explains the offset?
- **Figure:** `figures/11092026_offset_scatter_L6_grid2.png`
- **What the plot is:** Each patch's offset (measured − model) against the model's brightness, for our model (white) and SPHEREx's (orange).
- **Table (144 patches with |b| > 15°):**

| Model of the offset | Fit | R² |
|---|---|---|
| Constant + Kelsall scale | 0.036 + 0.181·Kelsall | 0.65 |
| Constant + Galaxy (csc\|b\|) only | 0.128 + 0.001·csc\|b\| | 0.00 |
| Constant + SPHEREx zodi model scale | 0.036 + 0.009·model | 0.01 |

- **Caption:** Our model is ~400× closer to Kelsall than Kelsall is to the real sky.
- **Speaker notes:** Ours matches Kelsall to ≤ 0.05%, while Kelsall is ~18% too faint. SPHEREx's own zodi model leaves
  only a constant ~0.036 MJy/sr.

### Slide 9: Figure slide
- **Title:** Which part of Kelsall is too faint?
- **Figure:** `figures/11092026_offset_comps_L6_grid2_notitle.png`
- **What the plot is:** The extra scale each Kelsall component needs to match the real sky at 5 μm (0 = Kelsall is right), from a fit across the sky and a fit over time.
- **Caption:** At 5 μm the smooth cloud is too faint and the trailing feature weaker than Kelsall.
- **Speaker notes:** Over time: cloud +0.06 ± 0.005, trailing feature −0.63 ± 0.07; bands and ring consistent with zero.
  The cloud is 94% of Kelsall off the plane, so it carries most of the gap.

### Slide 10: Table slide
- **Title:** How well do we reproduce the tall table?
- **Table (5 μm, 144 patches with |b| > 15°, 7061 exposures; from `realdata/repro_table.jl`):**

| Quantity | Tall table (measured) | Our model | SPHEREx zodi model |
|---|---|---|---|
| Median sky brightness (MJy/sr) | 0.625 | 0.488 | 0.570 |
| Model / measured (median) | 1 | 0.80 | 0.94 |
| Offset, measured − model (MJy/sr) | — | 0.127 | 0.040 |
| Offset vs model brightness (fit) | — | 0.036 + 0.181·model | 0.035 + 0.010·model |
| R² of that fit | — | 0.65 | 0.02 |
| Scatter left after the fit (MJy/sr) | — | 0.017 | 0.012 |
| Brightness range over time, model / measured | 1 | 0.92 | 1.02 |
| Time residual rms, each patch minus its median (MJy/sr) | — | 0.017 | 0.011 |
| Measured − model, behind minus ahead of Earth | — | −3.5% | +0.9% |

- **Caption:** SPHEREx's model is closer on every row; ours carries Kelsall's ~20% shortfall.
- **Speaker notes:** Our model matches ZodiPy (Kelsall) to a median 0.016% on these exposures, so every gap here is
  Kelsall vs the real sky, not the emulator. Brightness range = max − min within each patch over time; the time residual
  has each patch's own median removed, so a fixed offset drops out.

---

## Open questions (one slide each, title only)

### Slide 11
- **Title:** Add a zodi scale + constant, or train on SPHEREx's model?

### Slide 12
- **Title:** Is it time to mask stars?

### Slide 13
- **Title:** Can we trust the trailing feature result?
