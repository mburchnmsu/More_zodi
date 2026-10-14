# Cell contents for 10142026_multiwavelength.ipynb — round 13, a multi-wavelength emulator (overnight follow-on).
CELLS = Pair{String,String}[

"markdown" => raw"""
# A multi-wavelength emulator, 1.25–5.0 μm (Oct 14, 2026, overnight)

So far the emulator predicts the zodiacal light at **one** wavelength, 5 μm. Real SPHEREx images cover **0.75–5.0 μm**
(102 spectral channels), so the real-data emulator will need wavelength as an input. This notebook tests whether
that works on simulated data.

**Physics.** Below ~3 μm the zodiacal light is sunlight scattered by the dust. Above ~3.5 μm it is the dust's own
thermal emission. The spectrum has a minimum near 3.3–3.5 μm and rises steeply toward 5 μm (a factor ~5–10).
ZodiPy's Kelsall model interpolates the dust properties between the DIRBE bands at 1.25, 2.2, 3.5 and 4.9 μm. **Below
1.25 μm it can only extrapolate**, so SPHEREx's 0.75–1.25 μm channels are left out here.

**Data** (`zodipy_gen/generate_multi.py`, `ENV["ZODI_DATA"] = "z115multi"`): the same 423,607 mission exposures with the
corrected geometry, each at **one** of 64 wavelength channels log-spaced from 1.25 to 5.0 μm (monochromatic, ~6,600
exposures per channel). Check: the 5.0 μm channel reproduces the corrected 5 μm data to 3e-15.

**Inputs**: the recommended inputs from 10142026 (Sun frame + sin/cos λ⊕) plus **log₁₀ λ**. Variants:

| variant | loss | network |
|---|---|---|
| Sun frame + λ, MSE | squared error (as before) | 64-64-32-16 |
| Sun frame + λ, fractional loss | squared *fractional* error: the brightness spans 27× across wavelengths | 64-64-32-16 |
| … bigger network | fractional | 128-128-64-32 |
| old season inputs + λ | fractional | 64-64-32-16 |

**Tests**: (1) **held-out channels**: every 4th channel (16 of 64 wavelengths, never the end ones) is never seen in
training. Can it predict wavelengths in between? (2) **30-day blocks**, all wavelengths. 5 seeds each; ensembles.
Trained with the new threaded runner (`sweeps/run_threaded.jl`, 4 trainings in one process).

### Summary
SUMMARY_PLACEHOLDER
""",

"code" => raw"""
ENV["ZODI_DATA"] = "z115multi"
include(joinpath(@__DIR__, "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl", "extra_splits.jl", "nb_verify_fns.jl", "summary_helpers.jl", "multi_helpers.jl")
    include(joinpath(@__DIR__, "sweeps", f))
end
foreach(println, readlines(joinpath(@__DIR__, "zodipy_gen", "generate_multi.log")))
""",

"markdown" => raw"""
## Accuracy
`worst_channel_median_pct` = the median error of the worst single wavelength channel.
""",

"code" => raw"""
MT = multi_table()
""",

"code" => raw"""
err_vs_lambda_fig()
""",

"markdown" => raw"""
## Whole spectra
The network saw each exposure at **one** wavelength. Here each ensemble predicts the full 1.25–5.0 μm spectrum of 6
exposures at different ecliptic latitudes (120 wavelengths), compared with ZodiPy (`zodipy_gen/generate_spectra.py`).
""",

"code" => raw"""
spectra_fig("sunrel", "chan")
""",

"markdown" => raw"""
## Why the errors spike at certain wavelengths (round 14)
The true ZodiPy spectra above have **steps** at about 1.72 μm (5–7% near the ecliptic), 2.85 μm and 4.2 μm, the
midpoints between the DIRBE bands (1.25 | 2.2 | 3.5 | 4.9 μm). ZodiPy interpolates most dust properties between
bands, but takes the **phase-function coefficients C1–C3** (how the dust scatters sunlight with angle) from the
*nearest* band (`zodipy/unpack_model.py`, `use_nearest=True`):

| λ range (μm) | C1 | C2 | C3 |
|---|---|---|---|
| < 1.725 | −0.942 | 0.121 | −0.165 |
| 1.725–2.85 | −0.527 | 0.187 | −0.598 |
| 2.85–4.2 | −0.431 | 0.172 | −0.633 |
| > 4.2 | 0 | 0 | 0 |

These steps are a property of the model, not of the sky. A smooth function of λ cannot follow them, which is where the
round-13 errors peak. **Round 14** test: hand the network the coefficients themselves (phC1–3) as inputs.
""",

"code" => raw"""
spectra_fig("sunphase", "chan")
""",

"markdown" => raw"""
## Conclusions
CONCLUSIONS_PLACEHOLDER
""",
]
