# Cell contents for 10292026.ipynb — Oct 28–29: first real SPHEREx data (the north ecliptic pole at 4.9–5.1 μm over
# 15 months, realdata/) and round 36 (cos×exp schedule on all 6 shifts, sweeps/report36.jl).
#     julia --project=. sweeps/build_nb.jl sweeps/r36_text.jl 10292026.ipynb
CELLS = Pair{String,String}[

"markdown" => raw"""
# Real SPHEREx data at the north ecliptic pole, and the cos×exp schedule on all 6 splits (Oct 28–29, 2026)

### Summary
* **First real data.** The user's task: pick a point on the sky, collect every SPHEREx image of it, keep only 4.9–5.1 μm,
  and watch it change over time. Point: the **north ecliptic pole** (SPHEREx's deep field, so the most visits).
  **435 exposures** from June 2025 to September 2026 have the pole at 4.90–4.97 μm. They're turned into a movie and a
  light curve.
* **The pole's brightness follows a yearly cycle** of about ±15%, and Kelsall's model (ZodiPy) predicts it: same
  amplitude (14.3% vs 14.8%, after removing the non-zodi offset), peaks within ~8 days. Over the 12 months of the qr2 release, the image fits as
  **1.06–1.09 × ZodiPy + 0.10 MJy/sr**, with only **0.006–0.008 MJy/sr (~1.5%) scatter**. The constant 0.10 MJy/sr is
  light that isn't zodi (galaxies, the Milky Way's diffuse glow, calibration offsets).
* **SPHEREx's own zodi model** (the ZODI layer shipped with every image) is 1.04 × ZodiPy in qr2 but **1.17 × ZodiPy
  in qr3**, a jump on the day qr3 starts. The image level also drops ~7% there. The two releases are calibrated
  differently, so they shouldn't be mixed without care.
* **Round 36 (§5):** the cos×exp learning-rate schedule beats one-cycle at 500 epochs on **all 6 splits** (−6 to −21%,
  mean −12%; ecliptic 0.0285% → 0.0247%), but one-cycle at 2000 epochs remains the best model (ecliptic 0.0162%).
""",

"code" => raw"""
using CairoMakie
const R = joinpath(@__DIR__, "..")
showpng(f) = CairoMakie.Makie.FileIO.load(joinpath(R, "figures", f))
""",

"markdown" => raw"""
## 1. Finding the images (`realdata/find_frames.py`)
* Source: IRSA (`https://irsa.ipac.caltech.edu/ibe/data/spherex/qr3` and the earlier qr2 release), searched with
  IRSA's TAP service (`spherex.obscore`, the table the mentor's `data/regen_pipeline.py` also uses).
* SPHEREx's detectors are wavelength-graded: wavelength changes across each detector. **Detector D6 covers 4.41–5.01 μm**,
  from 5.02 μm at row 1 to 4.42 μm at row 2040. So "5 ± 0.1 μm" can only be 4.9–5.01 μm, and a sky point is at that
  wavelength only when it falls in the first ~400 rows.
* 4,062 D6 images cover the pole. For each one, the pole's detector pixel is found from the image footprint (the corners
  are listed in a fixed detector order), and its wavelength from the detector's wavelength table. Checked against an
  image's own WCS: within ~6 pixels and 0.006 μm. **644** images were selected with a small margin. The exact
  wavelength from each image keeps **435** at 4.90–4.97 μm (371 qr2, 64 qr3).
* Cutouts, not whole images (`realdata/download_cutouts.py`): 200 × 200 pixels (~20′) around the pole, 4.5 MB each,
  3.3 GB total, git-ignored in `data/spherex_real/`. Each cutout includes the image, flags, variance, **SPHEREx's zodi
  model** (ZODI) and the per-pixel wavelength.

## 2. Extraction (`realdata/extract_frames.py`)
* Each frame is resampled onto a common north-up grid centred on the pole (160 × 160 pixels of 6.15″), so the stars stay
  put in the movie.
* **The pole's brightness** = the median of a 31 × 31-pixel (3.2′) box, using only pixels at 4.9–5.1 μm. A median, so
  that stars (**not masked**: masking waits until the user says so) barely affect it. Noise from VARIANCE: ~0.002 MJy/sr.
* **ZodiPy** (the same Kelsall model as our simulated training data) at the pole, each frame's mid-exposure time and its
  exact wavelength, observer at Earth (SPHEREx is ~7000 km from Earth's centre, 5 × 10⁻⁵ AU, negligible).

## 3. The movie
`figures/10292026_nep_movie.mp4` (435 frames, 29 s, git-ignored because of its size; made by `realdata/make_movie.jl`).
Left: the 16′ field around the pole (cyan circle), only pixels at 4.9–5.1 μm. Right: the pole's brightness, with the
current frame marked. One frame:
""",

"code" => raw"""
showpng("10292026_nep_movie_frame.png")
""",

"markdown" => raw"""
Twelve frames spread over the 15 months (same colour scale). The background visibly brightens toward early 2026 and
fades again. A moving object (satellite or asteroid) crosses one frame (the diagonal streak in the movie frame above).
""",

"code" => raw"""
showpng("10292026_nep_montage.png")
""",

"markdown" => raw"""
## 4. The pole's brightness over time
Filled markers: the pole at 4.90–4.95 μm (mean 4.929). Open markers: 4.95–5.0 μm (mean 4.966). Zodi at 5 μm is thermal
emission from ~280 K dust and rises steeply with wavelength: ZodiPy +1.5% per 0.01 μm, the data +2.1%. That's why there
are two parallel tracks.

| release, pole wavelength | frames | image = a · ZodiPy + b | scatter (rms) | SPHEREx zodi / ZodiPy |
|---|---|---|---|---|
| qr2, 4.90–4.95 μm | 189 | 1.061 · ZodiPy + 0.099 MJy/sr | 0.0061 MJy/sr | 1.040 ± 0.006 |
| qr2, 4.95–5.0 μm | 182 | 1.088 · ZodiPy + 0.097 MJy/sr | 0.0078 MJy/sr | 1.037 ± 0.006 |
| qr3, 4.90–4.95 μm | 38 | 1.003 · ZodiPy + 0.086 MJy/sr | 0.0035 MJy/sr | 1.172 ± 0.003 |
| qr3, 4.95–5.0 μm | 26 | (2 months only: slope not constrained) | 0.0038 MJy/sr | 1.160 ± 0.002 |

* **Why the pole's brightness changes over the year.** The pole is always ~90° from the Sun, so the geometry barely
  changes, but the dust cloud's symmetry plane is tilted ~2° to the ecliptic. As Earth goes around the Sun it moves above
  and below that plane, and the column of dust toward the pole changes. ZodiPy and the data (after subtracting the
  ~0.11 MJy/sr of non-zodi light) agree on the size (14.3% vs 14.8%) and timing (peaks ~8 days apart) of this cycle.
* **What it means for our emulator.** Its error vs Kelsall (~0.013%) is far below the ~1.5% scatter of real data around
  Kelsall, and well below the 6–9% scale and 0.10 MJy/sr offset. The real-data job will be to learn those departures
  from Kelsall (the reason for a learnable emulator), and to separate zodi from the non-zodi light.
* **The qr2 → qr3 jump** (dashed line) happens in one day, so it isn't the sky. SPHEREx's zodi model goes from 1.04 to
  1.17 × ZodiPy, possibly connected to the `zodi_scaling_v2` calibration files that qr3 lists (not checked). The image
  level drops ~7%. Worth asking the
  mentor which release to trust before fitting real data.
""",

"code" => raw"""
showpng("10292026_nep_lightcurve.png")
""",

"markdown" => raw"""
## 5. Round 36: the cos×exp schedule on all 6 splits (`sweeps/configs_v36.jl`, `sweeps/report36.jl`)
Round 35 tested the cos×exp learning-rate schedule (5% warm-up, peak 2e-3, decay 3) only on shifts 0 and 30. Round 36
ran the other four shifts (10, 20, 40, 50 × 5 seeds, 500 epochs, parallax band layer; finished 06:35 Oct 29). Same
average learning rate as one-cycle, so only the shape differs.

| ensemble test MSE (×10⁻⁸) | shift 0 | 10 | 20 | 30 | 40 | 50 | mean |
|---|---|---|---|---|---|---|---|
| one-cycle, 500 epochs | 2.44 | 2.37 | 2.40 | 2.53 | 2.43 | 2.37 | 2.42 |
| **cos×exp, 500 epochs** | 1.93 | 1.96 | 2.25 | 2.32 | 2.28 | 2.10 | **2.14** |
| change | −21% | −17% | −6% | −8% | −6% | −11% | **−12%** |
| one-cycle, 2000 epochs (round 34) | 1.47 | 1.48 | 1.54 | 2.80 | 1.73 | 1.43 | 1.74 |

| sky map, all 6 shifts | median | p95 | within 2° of the ecliptic | above 60° |
|---|---|---|---|---|
| one-cycle, 500 epochs | 0.0157% | 0.049% | 0.0285% | 0.0134% |
| cos×exp, 500 epochs | 0.0147% | 0.046% | 0.0247% | 0.0128% |
| one-cycle, 2000 epochs | **0.0130%** | **0.035%** | **0.0162%** | **0.0120%** |

* **cos×exp beats one-cycle at 500 epochs on every split**, by 6–21% (mean −12%). The gain is largest near the ecliptic
  (0.0285% → 0.0247%, the blue stripe in the lower-left map). Per seed, the gain is 2.4–2.9 standard errors on shifts 0, 10
  and 50, but only 0.7–1.2 on shifts 20, 30 and 40 (within the seed scatter).
* **It does not replace more training.** One-cycle at 2000 epochs is still better everywhere except shift 30 (where it
  overfits). The lower-right map is mostly red: the extra epochs matter more than the schedule shape.
* The obvious next test is **cos×exp at 2000 epochs** (~4 × the cost, ~40 h on this laptop or one cluster job). Its fast
  early fall might also reach the 2000-epoch level in fewer epochs. Not started: needs the user's OK.
""",

"code" => raw"""
showpng("10292026_r36_sky.png")
""",
]
