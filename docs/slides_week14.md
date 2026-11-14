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

### Slide 6: Table slide
- **Title:** Can the emulator learn the real sky?
- **Table (5 μm, 197,523 rows = exposure × level-9 sub-pixel in 192 patches; each patch predicted by networks that
  never saw it, 5-fold cross-validation):**

| Trained on | Network, median \|Δ\| (rms) | Best simple baseline (fit on training patches), median \|Δ\| (rms) |
|---|---|---|
| ZodiPy (Kelsall), control (fold 0) | 0.026% (0.069%) | our simulation-trained emulator: 0.011% (0.017%) |
| SPHEREx's zodi column | 1.02% (2.03%) | Kelsall × 1.164: 0.96% (1.45%) |
| Measured sky, \|b\| > 15° | 3.2% (13.8%) | SPHEREx zodi + 0.044 MJy/sr: 1.9% (4.1%) |

- **What the table is:** Our emulator's architecture trained on the tall-table pixels instead of simulations, compared
  with one- or two-number baselines.
- **Conclusion:** 192 patches are enough to learn Kelsall itself, but on real targets the network does not beat a single
  scale factor (SPHEREx zodi) and overfits stars and residual sky (measured sky).
- **Speaker notes:**
  - Same architecture and training as the best simulation model (parallax band layer, sun-season inputs, cos×exp
    schedule, 1000 epochs); 5 seeds on fold 0, 2 seeds on folds 1–4; 31 runs on Colibrí, ~23 min each.
  - Targets are brought to 5.0 μm with Kelsall's own colour (× z(5 μm)/z(λ)), so the network sees no wavelength.
  - The measured-sky network fits its training patches to 1.2% but its held-out patches only to 4% (stars, galaxies,
    no masking yet).
  - Inputs come from our simulation feature set at the nearest simulated exposure (median 1 min apart); our emulator
    reproduces ZodiPy on these real rows to 0.016% (median).

### Slide 7: Figure slide
- **Title:** Where does the network miss?
- **Figure:** `figures/11142026_real_maps.png`
- **What the plot is:** Per-patch median residual for each patch's held-out prediction: the network trained on SPHEREx's
  zodi (left), a single Kelsall scale factor (middle), and the network trained on the measured sky (right).
- **Conclusion:** The network removes the smooth pattern left by Kelsall × 1.164 (the S-shaped ecliptic band), but adds
  1–3% errors in individual patches, so overall it ties.
- **Speaker notes:**
  - Per-patch medians: 0.43% (network) vs 0.44% (scale factor); the per-row rms is larger for the network (2.0 vs 1.45%).
  - On the measured sky (right, ±10% scale) the misses are scattered patch by patch, not along the ecliptic: they are
    sky the network can't know about from geometry.

### Slide 8: Text slide
- **Title:** Why can't it beat a scale factor on SPHEREx's zodi?
- **Points:**
  - Most of what is left in SPHEREx zodi / Kelsall is wavelength: −1.4% per 0.05 μm, over a 0.04 μm spread within the
    4.9–5.0 μm window.
  - The network has no wavelength input, so it can't learn that. A wavelength-only linear fit takes the spread from
    0.96% to 0.65% (median) and 1.45% to 1.00% (rms).
  - Next step (needs approval): add wavelength as an input, or train in narrower wavelength bins.
  - **Done Nov 14 → slide 9.**

### Slide 9: Table slide
- **Title:** With wavelength as an input, the network matches SPHEREx's zodi to 0.2%
- **Table (5 μm, all 192 patches held out in turn, 5-fold cross-validation):**

| Model of SPHEREx's zodi column | Median \|Δ\| | rms |
|---|---|---|
| Kelsall × 1.164 | 0.96% | 1.45% |
| Kelsall × f(λ) (median ratio in 0.005 μm bins) | 0.62% | 0.95% |
| Network, no wavelength input | 1.02% | 2.03% |
| **Network + wavelength input** | **0.20%** | **0.28%** |

- **What the table is:** How closely each model reproduces SPHEREx's zodi column on patches it was not trained on.
- **Conclusion:** One extra input (the pixel's wavelength within 4.9–5.01 μm) makes the network 5× better and 3× better
  than the best simple correction, so it learns how SPHEREx's model differs from Kelsall with both wavelength and geometry.
- **Speaker notes:**
  - Per-patch medians: 0.04% (map: `figures/11142026_real_maps.png`, bottom left, uniformly white).
  - 10 runs (2 seeds × 5 folds), ~25 min each on Colibrí (job 232). Every fold gives 0.195–0.210%.
  - The wavelength enters before the band layer's 6 inputs; nothing else changed (+64 weights).

### Slide 10: Figure slide
- **Title:** Does star masking help on the measured sky?
- **Figure:** `figures/11142026_real_maps.png` (bottom right)
- **What the plot is:** Per-patch median residual of the network trained on the star-masked measured sky with the
  wavelength input, each patch predicted while held out.
- **Conclusion:** Masking helps everything by 10–30%, but the network (2.3%) still doesn't beat SPHEREx's zodi + a
  constant (1.7%) off the plane: its errors are a few patches it gets badly wrong, mostly near the Galactic plane.
- **Speaker notes:**
  - Mask: the tall table's default query already drops artifact flags; we also drop MP_SOURCE (bit 21, pixels on catalog
    sources). Kept: 59% of pixels (73% at |b| > 15°, 13% on the plane); 7489 of 197,523 rows lose all pixels.
  - |b| > 15°, median |Δ| (rms): network 3.2% (13.8%) unmasked → 3.0% (18.7%) masked → **2.3% (12.2%)** masked +
    wavelength; SPHEREx zodi + b 1.9% (4.1%) → 1.7% (3.2%); Kelsall × a 2.7% → 2.3%.
  - 8% of the network's rows miss by > 10% (baseline: 1.2%). One patch is ~2× off while SPHEREx zodi + b is within 3%;
    the same network trained on SPHEREx's zodi has no trouble there, so the noisy target (not the inputs) causes it.
  - Rows with < 30% clean pixels are noisier for every model (network 5.2%, baseline 3.5%).
  - Possible next steps: a robust loss (e.g. relative L1) or training on measured / Kelsall, and dropping rows with
    few clean pixels. **Done Nov 14 → slide 11.**

### Slide 11: Table slide
- **Title:** With clean rows and a robust loss, the network beats SPHEREx's zodi model on the measured sky
- **Table (5 μm, star-masked measured sky, |b| > 15°, rows with ≥ 50% of pixels unmasked, all patches held out in turn;
  the same 141,387 rows for every line):**

| Model | Median \|Δ\| | rms | Rows off by > 10% |
|---|---|---|---|
| Network + λ (all masked rows, MSE loss) | 2.16% | 8.85% | 6.5% |
| Network + λ, trained on ≥ 50%-clean rows | 1.29% | 4.46% | 2.2% |
| **Network + λ, ≥ 50%-clean rows, relative Huber loss** | **1.20%** | **2.77%** | **0.8%** |
| SPHEREx zodi + constant (fit on training patches) | 1.44% | 2.63% | — |
| Kelsall × f(λ) | 1.82% | 3.39% | — |

- **What the table is:** How closely each model predicts the measured, star-masked sky on patches it never saw.
- **Conclusion:** Training only on rows that keep at least half their pixels removes most of the bad patches, and a
  loss that is gentle on outliers removes the rest: the network now predicts the measured sky better than SPHEREx's own
  zodi model plus a constant.
- **Speaker notes:**
  - Relative Huber loss: quadratic below 2% relative error, linear above (δ = 0.02).
  - The ≥ 50% cut keeps 143,751 of 197,523 rows; it removes most of the Galactic plane (13% of plane pixels survive the
    mask), so this result is for the sky away from the plane.
  - 20 runs (2 arms × 2 seeds × 5 folds) on Colibrí, job 254.
