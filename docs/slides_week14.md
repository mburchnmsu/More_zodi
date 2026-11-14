# Slide content: Week 14 meeting with Dr. Saydjari

Rule from the Week 14 card: every figure slide says what the plot is and the conclusion. Everything is at 5 μm.

---

### Slide 1: Figure slide
- **Title:** What are the grey bands in the 2D maps?
- **Figure:** `figures/11132026_earth2d_gray_annot.png` (the top-left panel of `figures/11042026_earth2d_moll.png`, labelled)
- **What the plot is:** Our model's error on withheld months, averaged in 3° cells, seen from the frame of Earth's motion
  (centre = behind Earth).
- **Conclusion:** The grey is sky SPHEREx never looks at. It only points ~90–115° from the Sun, so only the strips at
  "ahead" and "behind" fill.
- **Speaker notes:**
  - A (Sun side): never within ~90° of the Sun (Sun avoidance).
  - B (anti-Sun side): never more than ~115° from the Sun (the survey's elongations run 85–130°, median 90°).
  - The two strips meet at the ecliptic poles, where every direction is ~90° from the Sun.
  - C is outside the Mollweide ellipse (plot background).
  - D is scattered 3° cells with fewer than 30 exposures, blanked by the plotting code (`minn = 30`).
  - Each Earth-frame panel has the two big grey lunes A and B, so the with/without pair shows four.
  - In the ecliptic frame (bottom row) the year's motion fills the whole sky, except for a few small cells at the poles.

### Slide 2: Figure slide
- **Title:** What is the jump near MJD 61,200?
- **Figure:** `figures/11132026_nep_burst.png`
- **What the plot is:** At the north ecliptic pole, the measured sky minus SPHEREx's zodi model against time. Orange
  points are at the 4.98–5.01 μm detector edge. Below: exposures per 5 days.
- **Conclusion:** This is not a calibration jump. From Apr 29 to Jun 18, 2026 (MJD 61145–61195) the pole was visited
  3× as often, and many of the extra exposures are at the noisy detector edge.
- **Speaker notes:**
  - The level stays put: measured − SPHEREx zodi is 0.026 MJy/sr before and after, and 0.021 during.
  - The scatter is 0.010 at the edge vs 0.0055 MJy/sr elsewhere.
  - Sky-wide, 4.98–5.01 μm has twice the rms and 3× as many bright outliers (7.8% vs 2.2–3.5% above +0.02 MJy/sr).
  - The tall table shows no qr2→qr3 release step anywhere: SPHEREx zodi / ZodiPy holds at 1.15–1.17. That step only
    appeared in the IRSA images we downloaded in October.

### Slide 3: Figure slide
- **Title:** What model is SPHEREx's zodi column?
- **Figure:** `figures/11132026_spherex_vs_kelsall.png`
- **What the plot is:** SPHEREx's zodi divided by ZodiPy (Kelsall) for 8938 exposures over 192 patches, against solar
  elongation, ecliptic latitude and time.
- **Conclusion:** SPHEREx's zodi column is Kelsall scaled up by 16.5%, with only 1–2% changes with geometry.
- **Speaker notes:**
  - Median ratio 1.165 (16–84%: 1.147–1.186).
  - A regression explains 40% of the remaining 1.7% scatter, with these terms:
    - −1.4% per 0.05 μm of wavelength (a slightly different spectrum);
    - +0.5% per 10° of elongation;
    - −0.2% per 10° of latitude;
    - −0.6% when seen behind Earth (a slightly weaker trailing cloud);
    - −0.7% yearly term.
  - So matching SPHEREx's model is mostly a single scale factor.

### Slide 4: Figure slide
- **Title:** Where is the leak in the residual map?
- **Figure:** `figures/11132026_residual_leak.png`
- **What the plot is:** Per patch, the residual seen behind Earth minus seen ahead, before and after first scaling our
  model up by 1.181. Also shown: the solar elongations at which SPHEREx sees "behind" and "ahead".
- **Conclusion:** Most of the −5% behind-Earth deficit is Kelsall's 18% scale error leaking in. SPHEREx sees "behind" at
  larger elongation (109° vs 93°), where the sky is ~24% fainter.
- **Speaker notes:**
  - We subtract each patch's median and divide by our model. A model that is X% too faint then shows ~X% × (fractional
    brightness change) between views.
  - Scaling first removes it near the ecliptic: −5.0 ± 0.3% → −0.7 ± 0.4% (fit across longitude).
  - What remains is mostly a yearly pattern.
  - A per-exposure joint fit (side + elongation + season) still leaves −2.6 ± 0.2% behind. That error is formal, and the
    true one is larger because exposures within a patch are correlated.
  - So a small trailing-cloud term (v_e) of 1–3% may be left. That matches the component fit, where Kelsall's trailing
    feature looked too strong.
  - On the mean: subtracting each patch's own median removes anything constant in time, so the mean of the residual is
    ~0 by construction (+0.2% here).

### Slide 5: Table slide
- **Title:** Is v_e still there?
- **Table (near the ecliptic, |β| < 30°, 74 patches):**

| Behind − ahead | As in Week 13 | Scale fixed first | Joint fit (side + elongation + season) |
|---|---|---|---|
| Measured − our model | −5.0 ± 0.3% | −0.7 ± 0.4% | −2.6 ± 0.2% |
| Measured − SPHEREx zodi model | −0.1 ± 0.3% | — | −1.4 ± 0.2% |

- **What the table is:** How much fainter the sky is behind Earth than ahead of it, relative to the model, with three
  ways of removing the elongation and scale leak.
- **Conclusion:** The −5% was mostly the leak. A trailing-cloud term of 1–3% may remain, but our grid-2 data can't pin it
  down.
- **Speaker notes:** The cuts (no 4.98–5.01 μm edge, no NEP-burst dates) change these by ≤ 0.4%.
