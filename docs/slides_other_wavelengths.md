# Slide content kept for later: other wavelengths (1.3–5 μm)

Taken out of the Week 13 deck (`docs/slides_week13.md`), which stays at 5 μm. Use this if Dr. Saydjari asks to move to
other wavelengths. Same style rules as the Week 13 file. Numbers come from notebooks 11082026 and 11092026 (grid 2: 192
patches, 144 with |b| > 15°).

---

### Slide A: Figure slide
- **Title:** Kelsall vs the real sky, 1.3 to 5 μm
- **Figure:** `figures/11092026_offset_spectrum_L6_grid2_notitle.png`
- **Caption:** Kelsall is too faint at all 8 windows, most at 3.45 μm.
- **Speaker notes:** Left: proportional part c1 (measured ≈ (1 + c1)·Kelsall); middle: the constant; right: the median
  brightness. SPHEREx's zodi model has c1 ≈ 0 at every window.

### Slide B: Table slide
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
- **Speaker notes:** The errors are ±0.01–0.04, and the 48-patch grid gave the same values. Below 3 μm there is also a
  starlight-like term (no star masking yet).

### Slide C: Figure slide
- **Title:** Which part of Kelsall is too faint, by wavelength?
- **Figure:** `figures/11092026_offset_comps_spectrum_L6_grid2_notitle.png`
- **Caption:** Over time, the smooth cloud is too faint at every wavelength; the trailing feature only looks weaker at 4–5 μm.
- **Speaker notes:** Cloud k = +0.04 to +0.32 over time; the across-sky fit is consistent with zero at 1.3 and 2.2 μm.
  Feature −0.63 ± 0.07 at 5 μm but +0.48 at 1.65 μm; the ring is +1.0 ± 0.2 at 3.45 μm.

### Slide D: Figure slide
- **Title:** 3.45 μm offset map
- **Figure:** `figures/11092026_offsetmap_L6_grid2_w3.4_notitle.png`
- **Caption:** The window where Kelsall is furthest off (31%).

### Slide E: Open question (title only)
- **Title:** Is the 3.45 μm excess known, or something new?

### Slide F: Open question (title only)
- **Title:** Scale zodi per wavelength, or train on SPHEREx's model?
