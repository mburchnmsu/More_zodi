# Cell contents for 10202026.ipynb — Oct 19–21: the 500-day data, the 500-day model (round 24), the n·J control (25),
# the Sun's wobble and heliocentric inputs (27), the mentor's trailing-cloud tests 1–2 (round 26), poster redesign.
# Several data settings are involved (140-day z115, 500-day z500, heliocentric), so this notebook shows the figures and
# tables made by the round scripts; each cell says which script makes it.
#     julia sweeps/build_nb.jl sweeps/r24_text.jl 10202026.ipynb
CELLS = Pair{String,String}[

"markdown" => raw"""
# 500 days of SPHEREx, the Sun's wobble, and the mentor's trailing-cloud tests (Oct 19–21, 2026)

### Summary
* **New data (Oct 19):** the mentor's 500-day delivery (1,520,194 pointings, 500.25 days; `data/regen_pipeline.py`,
  pointings from the public IRSA archive). It contains the first 140 days (the same exposures; directions are image
  centres ≈ 3.85° from the old boresights, times 57.6 s later). Its ZodiPy emission repeats error #1 of the old data
  (barycentric observer, ~2% off), so the targets were regenerated: `zodipy_gen/generate_500.py` → `ZODI_DATA = "z500"`.
  The 140-day files now live in `data/d140/`.
* **500-day model (round 24):** poster model + n·J, 6 month splits × 5 seeds, 500 epochs. Sky map tests 98% of the
  sky; median 0.0162%, p95 0.053%, within 2° of the ecliptic **0.064%** (140 days: 0.083%).
* **Why n·J mattered (rounds 25, 27):** without n·J the 500-day error doubled (0.031%), concentrated one year apart.
  Cause: the inputs were **barycentric**, but the Sun — and the dust cloud and ZodiPy's targets with it — moved
  0.0035 AU about the barycentre over 500 days (pulled by Jupiter; n·J was a proxy for it). With **heliocentric**
  inputs and no n·J: median **0.0157%**, ecliptic **0.044%** — the best 500-day model so far.
* **Mentor's test 1:** removing Kelsall's ring + trailing blob changes the emission-vs-angle curves, and the poster
  network minus cloud-free ZodiPy reproduces ring + blob to 0.002% of the total → the earlier plots showed real cloud
  signal and the network learned it.
* **Mentor's test 2:** the poster model without the Earth dot products (n·E, n·vE, n·x⊕, n·y⊕) is clearly worse
  (median 0.023% vs 0.016%, p95 2×, near the poles 2.4×). The cloud is still learned, because n·S ≈ n·E.
* **Poster:** redesigned (larger text, Fig. 2 removed, 140 vs 500-day sky-map pair, compact Next Steps, coloured key
  phrases, the mentor's wording notes).
""",

"code" => raw"""
using CairoMakie
const R = joinpath(@__DIR__, "..")
struct PNGFile; path::String; end; Base.show(io::IO, ::MIME"image/png", p::PNGFile) = write(io, read(p.path))   # raw PNG bytes: renders in any Jupyter front end
showpng(f) = PNGFile(joinpath(R, "figures", f))
""",

"markdown" => raw"""
## 1. The 500-day model vs the poster model (round 24)
Out-of-sample error on the sky, between-month windows of the 6 shifted month splits (`sweeps/r24_data.jl`,
`sweeps/plot_r24.jl`). Left: 140 days (poster model, 750 epochs). Right: 500 days (+ n·J, 500 epochs).

| | 140 days | 500 days |
|---|---|---|
| median | 0.0159% | 0.0162% |
| p95 | 0.063% | 0.053% |
| within 2° of the ecliptic | 0.083% | 0.064% |
| above 60° | 0.0125% | 0.0140% |
""",

"code" => raw"""
showpng("10202026_skymap_140v500.png")
""",

"markdown" => raw"""
Loss curves (poster split, epoch-averaged): the 500-day model ends lower (test MSE 4.6e-8 vs 1.2e-7) with test and
training only ~1.4× apart (140 days: ~4.7×).
""",

"code" => raw"""
showpng("10202026_loss_140v500.png")
""",

"markdown" => raw"""
## 2. Why does the 500-day model need n·J? The Sun's wobble (rounds 25 and 27)
Poster split (shift 0), 5 seeds, 500 epochs each, withheld months:

| inputs | median | p95 | ecliptic (<2°) | days 0–100 | days 400–500 |
|---|---|---|---|---|---|
| barycentric + n·J (round 24) | 0.0164% | 0.055% | 0.060% | 0.0137% | 0.0152% |
| barycentric, no n·J (round 25) | 0.0307% | 0.191% | 0.094% | 0.0586% | 0.0567% |
| **heliocentric, no n·J (round 27)** | **0.0157%** | **0.051%** | **0.044%** | 0.0138% | 0.0139% |

Without n·J the errors pile up at days 0–100 and 400–500: the same time of year one year apart, which sin/cos λ⊕
cannot tell apart. The check below compares matching pointings one year apart (same λ⊕, same Earth-frame direction):
the target repeats, but Earth's barycentric distance does not.
""",

"code" => raw"""
Base.include(Module(:YearCheck), joinpath(R, "sweeps", "year_check.jl"))   # own namespace (the script defines n, y, …)
""",

"markdown" => raw"""
`zodipy_gen/sun_wobble.py` (ZodiPy environment) gives the reason: the Sun sits 0.0054–0.0072 AU from the barycentre and
moved 0.0035 AU over the 500 days, roughly opposite Jupiter. Heliocentric Earth distance repeats to 6e-5 AU year to
year; barycentric to only 2e-3 AU. The dust cloud and ZodiPy's targets are Sun-centred, so barycentric inputs drift
relative to them, and n·J stood in for the Sun's position. Fix: `ENV["ZODI_HELIO"] = "1"` subtracts the Sun's
barycentric position (`zodipy_gen/sun_positions.py` → `data/sun_positions.h5`) from every position before the inputs are
built. With it, n·J is no longer needed and the ecliptic error drops further (0.060% → 0.044%).

## 3. The mentor's trailing-cloud test 1
Remove Kelsall's two Earth-linked components (circumsolar ring + Earth-trailing blob, stored per pointing in the
corrected data) and remake the emission-vs-angle plots (`sweeps/cloud_test1.jl`). (a) the curves change, most behind
Earth; (b) the blob rises from ~1% ahead to ~7% behind (the ~1% straight ahead is the blob itself: Earth sits in its
leading wing), the ring is ~symmetric; (c) the poster network (trained WITH the cloud) minus the cloud-free ZodiPy
reproduces the true ring + blob curve to 0.002% of the total brightness, on pointings it never saw.
""",

"code" => raw"""
showpng("10202026_cloud_test1.png")
""",

"markdown" => raw"""
## 4. The mentor's trailing-cloud test 2 (round 26)
The poster model (140 days, 750 epochs, 6 month splits × 5 seeds) without the Earth dot products: inputs n·S, n·z, n·vS,
sin λ⊕, cos λ⊕ (`sweeps/configs_v26.jl`, `sweeps/cloud_test2.jl`).

| | poster model | without Earth dot products |
|---|---|---|
| median | 0.0159% | 0.0230% |
| p95 | 0.063% | 0.131% |
| within 2° of the ecliptic | 0.083% | 0.077% |
| above 60° | 0.0125% | 0.0298% |

Clearly worse overall, especially toward the north ecliptic pole and in the tails. But the trailing cloud is still
learned (leftover fraction 0.03 ± 0.09%): SPHEREx is only ~5e-5 AU from Earth, so n·S carries Earth's position and
n·vS nearly Earth's motion. What the removed inputs mostly supplied is the Earth-following frame (n·x⊕, n·y⊕).
""",

"code" => raw"""
showpng("10212026_cloud_test2_skymap.png")
""",

"code" => raw"""
showpng("10212026_cloud_test2_stack.png")
""",

"markdown" => raw"""
## 5. Poster redesign (not affected by the tests above)
Following the mentor's notes and his example posters: larger text (body 30 pt, captions 26 pt), Fig. 2 (components)
removed, the training curve back in Methods, Fig. 6 = 140 vs 500-day sky maps side by side (caption: with more than a
year of data, Jupiter's direction also helps the network tell the two years apart), compact 2 × 2 Next Steps (Refine:
more data, longer training, Jupiter's direction), key phrases coloured, wording: pointing vector, ZodiPy's prediction of
the zodiacal-light contribution, Kelsall's finite analytic components, sky coordinates; Jupiter and the Moon kept in
Fig. 2 (tracked for real data). `poster/build_poster.py`, `poster/make_figures.jl`.

## Next
* Switch to heliocentric inputs everywhere (and redo the 500-day sky map with them, without n·J)? Then n·J can be tested
  on its own merits for real data (dust leading/trailing Jupiter).
* The Fig. 6 caption could then say the real reason (the Sun's wobble) instead of "Jupiter helps".
""",
]
