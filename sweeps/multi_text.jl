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
* **It works.** One network for all wavelengths 1.25–5.0 μm. The best version (round 15) reaches **0.09–0.10% median
  error** on the 30-day blocks (p95 0.44–0.46%), and full predicted spectra stay within **0.6–0.9%** of ZodiPy at every
  wavelength. That is ~4× the single-wavelength model's 0.024%; the remaining error sits at the DIRBE band centres.
* **Unseen wavelengths:** with 16 of 64 channels never shown in training, the error there is about the same as at
  seen channels (0.19–0.21% median at 100 epochs). Interpolating between wavelengths is not the hard part.
* **ZodiPy artifact found:** ZodiPy takes the dust's phase-function coefficients C1–C3 from the *nearest* DIRBE band, which
  puts **artificial steps** in every spectrum at 1.725, 2.85 and 4.2 μm (up to ~7% near the ecliptic). Giving the network
  those coefficients as inputs cut the error by ~35% (0.37% → 0.23%).
* **The rest was underfitting:** training 300 instead of 100 epochs cut it another ~2.5× (0.23% → 0.10%). Blackbody-shape
  inputs didn't matter (0.087% vs 0.098%), and a bigger network at 100 epochs didn't either.
""",

"code" => raw"""
ENV["ZODI_DATA"] = "z115multi"
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl", "extra_splits.jl", "nb_verify_fns.jl", "summary_helpers.jl", "multi_helpers.jl")
    include(joinpath(@__DIR__, "..", "sweeps", f))
end
foreach(println, readlines(joinpath(@__DIR__, "..", "zodipy_gen", "generate_multi.log")))
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
## Is the rest underfitting? (round 15)
With the phase coefficients the network follows the steps, but its error is still ~10× the single-wavelength model's.
On the 30-day blocks the **training** error is about as large as the test error (MSE ~2.0e-6 vs 2.2e-6), and a bigger
network did not help. So the network underfits. Two candidate reasons, one variant each: **longer training** (300 epochs
instead of 100), and **blackbody-shape inputs** log₁₀ B_λ(T) at T = 250 and 300 K (relative to 5 μm). The thermal part
rises like a blackbody's Wien tail toward 5 μm, a very steep function of λ for a network to build from log λ alone.
(The 300-epoch variants were only run on the 30-day blocks, for time.) Red dashed lines: ZodiPy's phase-coefficient steps.
""",

"code" => raw"""
err_vs_lambda_fig(ARMS13_R1415)
""",

"markdown" => raw"""
Spectra from the best model (phase coefficients, 300 epochs, trained on the 30-day blocks):
""",

"code" => raw"""
spectra_fig("ep300", "blk")
""",

"markdown" => raw"""
## Conclusions
| round | variant (Sun frame + sin/cos λ⊕ + log λ, fractional loss unless noted) | held-out channels | 30-day blocks |
|---|---|---|---|
| 13 | squared error (MSE) | 0.43% | 0.44% |
| 13 | fractional loss | 0.30% | 0.37% |
| 13 | fractional, 128-128-64-32 | 0.32% | 0.36% |
| 13 | old season inputs (with n·J, fixed axes) | 0.36% | 0.38% |
| 14 | + ZodiPy phase coefficients C1–C3 | 0.21% | 0.23% |
| 15 | + phase coefficients + blackbody inputs | 0.19% | 0.18% |
| 15 | + phase coefficients, **300 epochs** | — | **0.098%** |
| 15 | + phase coefficients + blackbody, 300 epochs | — | **0.087%** |
| ref. | single wavelength (5 μm), 10142026 | — | 0.024% |

(median |error|, 5-seed ensembles)

1. **A multi-wavelength emulator is feasible** with the same small network: ~0.1% median across 1.25–5.0 μm, with smooth,
   correct spectra (scattered-light decline, minimum near 3.3–3.5 μm, thermal rise to 5 μm).
2. **Train longer for harder targets.** 100 epochs was enough at one wavelength but not here. The next step is a
   longer-training check on the held-out channels too, and perhaps 500+ epochs. On this laptop, the threaded runner
   needs ~20 min per 300-epoch run, 4 at a time; on the cluster this is cheap.
3. **ZodiPy's nearest-band phase coefficients are a modelling artifact,** not sky physics. For an emulator *of ZodiPy* we
   feed them in (phC1–3). For real data, the real sky has no steps: either regenerate the training data with
   smoothly interpolated coefficients, or keep the step inputs and accept that real spectra will not show them. **A
   question for the mentor.**
4. **Not covered yet:** SPHEREx's **0.75–1.25 μm** channels. ZodiPy's Kelsall model only extrapolates below 1.25 μm (the
   shortest DIRBE band). Also not covered: channel bandpasses (monochromatic here), and several wavelengths per exposure
   (real SPHEREx exposures see all wavelengths at once; here each saw one).
""",
]
