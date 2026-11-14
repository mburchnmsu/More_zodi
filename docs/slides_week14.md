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
