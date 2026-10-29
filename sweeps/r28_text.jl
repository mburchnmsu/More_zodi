# Cell contents for 10212026.ipynb — Oct 21: the heliocentric 500-day sky map (rounds 27–28) and the mentor's Jupiter
# null experiment; comparison with the mentor's onboarding notebook; poster review.
#     julia sweeps/build_nb.jl sweeps/r28_text.jl 10212026.ipynb
CELLS = Pair{String,String}[

"markdown" => raw"""
# Heliocentric inputs on 500 days, and the Jupiter null experiment (Oct 21, 2026)

Continues `10202026.ipynb`. All runs: 500-day data (`ZODI_DATA = "z500"`), the poster recipe (64-64-32-16 gelu,
one-cycle LR 1e-3, 5 networks averaged), 500 epochs, positions made **heliocentric** with `ENV["ZODI_HELIO"] = "1"`
(the Sun's barycentric position from `zodipy_gen/sun_positions.py` is subtracted from every position before the inputs
are built; results in `sweeps/results_z500_helio/`).

### Summary
* **The heliocentric 500-day sky map** (no n·J; shifts 0 + 30, which together test every pointing once): median
  **0.0160%**, p95 0.053%, within 2° of the ecliptic **0.048%** — vs 0.064% for the barycentric + n·J model and 0.083%
  for the 140-day poster model.
* **The mentor's Jupiter null experiment** (his onboarding notebook, stretch goal 2): with heliocentric inputs, adding n·J
  gives **no gain** (slightly worse: median 0.0165% vs 0.0157%, ecliptic 0.063% vs 0.044%). On Kelsall data — which has
  no Jupiter — n·J carries no real information; its earlier benefit was entirely the Sun's wobble about the barycentre.
* **Recommended default from now on:** heliocentric inputs, no n·J. Keep n·J as an option for real data (dust leading
  and trailing Jupiter); this null test means any gain there would be real physics, not a hidden clock.
""",

"code" => raw"""
using CairoMakie
const R = joinpath(@__DIR__, "..")
struct PNGFile; path::String; end; Base.show(io::IO, ::MIME"image/png", p::PNGFile) = write(io, read(p.path))   # raw PNG bytes: renders in any Jupyter front end
showpng(f) = PNGFile(joinpath(R, "figures", f))
""",

"markdown" => raw"""
## 1. The heliocentric 500-day sky map
Out-of-sample error, between-month windows, 3.5° patches, same colour scale (`sweeps/r24_data.jl` with
`R24_FAM = "z500h_noJ_shift"`, `sweeps/plot_r28.jl`). Left to right: 140 days (poster model); 500 days, barycentric
inputs + n·J (round 24, 6 shifts); 500 days, heliocentric inputs, no n·J (rounds 27–28, shifts 0 + 30).

| | 140 days | 500 d, barycentric + n·J | 500 d, heliocentric |
|---|---|---|---|
| median | 0.0159% | 0.0162% | 0.0160% |
| p95 | 0.063% | 0.053% | 0.053% |
| within 2° of the ecliptic | 0.083% | 0.064% | **0.048%** |
| above 60° | 0.0125% | 0.0140% | 0.0142% |

The heliocentric map uses 2 shifts (each pointing tested once, 90% of pointings: the shift-30 windows at the mission's
ends are left out), so it is slightly noisier than the 6-shift map; the ecliptic stripe is visibly thinner.
""",

"code" => raw"""
showpng("10212026_skymap_helio.png")
""",

"markdown" => raw"""
## 2. The Jupiter null experiment (round 28)
Poster split (shift 0), 5 seeds, 500 epochs, withheld months (`sweeps/jupiter_null_compare.jl`):

| inputs | median | p95 | ecliptic (<2°) | above 60° | days 0–100 | days 400–500 |
|---|---|---|---|---|---|---|
| barycentric + n·J (round 24) | 0.0164% | 0.055% | 0.060% | 0.0145% | 0.0137% | 0.0152% |
| barycentric, no n·J (round 25) | 0.0307% | 0.191% | 0.094% | 0.0188% | 0.0586% | 0.0567% |
| **heliocentric, no n·J (round 27)** | **0.0157%** | **0.051%** | **0.044%** | 0.0140% | 0.0138% | 0.0139% |
| heliocentric + n·J (round 28) | 0.0165% | 0.055% | 0.063% | 0.0149% | 0.0147% | 0.0147% |

The mentor's onboarding notebook: *"on Kelsall-generated data, Jupiter-based features should carry no information —
verify that adding them doesn't (spuriously) change your test error, and think about what it would mean if it did."*
With barycentric inputs it did change the error, and what it meant was a missing input: the Sun's position. With
heliocentric inputs the null holds (n·J adds nothing; a little worse, as an uninformative input usually is).

## 3. How this fits the mentor's onboarding plan
* His method — *"structure in residuals against a quantity that is not an input feature: that quantity (or a proxy)
  probably belongs in the model"* — is exactly how the Sun's wobble was found (residual structure one year apart; n·J
  was the proxy).
* His notebook works in barycentric language and notes the smooth cloud's centre is offset ~0.01 AU from the Sun; the
  140-day data were too short for the Sun's own motion (0.0035 AU over 500 days) to show.
* Still open from it: the Earth-centric terms for real data (n·δ̂ with δ = S − E, the Earth-limb direction for
  Earthshine/stray light, and the Moon's direction), first checked as a null on simulated data; a one-at-a-time
  ablation table; output positivity; ensemble spread out of the training domain.

## 4. Poster review (Oct 21)
Final pass: Fig. 2's ẑ note moved (it overlapped the "n̂ = pointing vector" label after the font increase); the training
bullet now says "tested on whole months they never saw" (the sky-patch tests were done with an older model); speaker
notes brought up to date. The poster keeps the barycentric + n·J 500-day map in Fig. 6 (user's choice).
""",
]
