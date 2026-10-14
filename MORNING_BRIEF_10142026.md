# Morning brief — Oct 14, 2026 (overnight work on the zodi emulator)

Everything below is committed and pushed. Two new notebooks run top to bottom: **10142026.ipynb** (corrected
data, extrapolation in time, Sun-frame inputs) and **10142026_multiwavelength.ipynb** (the follow-on project).
Original data, earlier results and 10132026.ipynb are untouched (10132026's local saved outputs are still uncommitted, as you chose).

## 1. The original simulated data has two generation errors (tell the mentor)
`zodipy_gen/reproduce_original.py` reproduces our data files to 3e-7 with ZodiPy 1.1.5, but **only** with two mistakes:
* **Observer origin:** SPHEREx's position relative to the solar-system *barycentre* was passed to ZodiPy as if relative
  to the *Sun* (0.007 AU off) → ~2–3% too faint everywhere.
* **Earth extrapolated:** all exposures went through ZodiPy in one batch in *file order*. The file isn't time-sorted, so
  ZodiPy's Earth-orbit spline only covered mission days ~6–58 and was extrapolated elsewhere (0.12 AU / 5.6° wrong by day
  130) → the late mission is off by up to 6%. That is exactly the 80/20 chronological test set.

Fix for their script: pass a heliocentric observer position, and time-sort exposures (or chunk them) before the batch call.
Corrected data: `data/zodipy115_*.h5`, opt-in with `ENV["ZODI_DATA"] = "z115"`. All earlier conclusions hold on it,
and the numbers get better (season model, 30-day blocks: 0.024% median, was 0.0325%).

## 2. New recommended inputs: Sun frame + season (emulator v2)
`n·S n·z n·E n·vS n·vE n·x⊕ n·y⊕ sinλ⊕ cosλ⊕`: the pointing measured from the Sun–Earth line instead of fixed x/y axes,
**no Jupiter**.

| | season model | **Sun frame + sin/cos λ⊕** |
|---|---|---|
| inside the mission (MSE) | 1× | 0.87× |
| trained on the 140-day mission → worst error over the next 18 months | 3.0% | **0.84%** |
| trained on a simulated full year → the following 16 months (median) | 0.33% | **0.10%** |

* Jupiter acts as a clock (it moves ~30°/yr). With a full year of training data, simply dropping n·J matters most.
* Trust ≈ 3 months beyond the observed season (≤ 0.1% at +90 days). Year-round accuracy needs year-round training data.
* **Emulator v2** packaged (`emulator/zodi_emulator_v2.jld2`, same module loads v1 or v2; 7/7 checks): held-out
  median 0.015%, p95 0.064%; on the future set its in-domain flag works (0.06% in-domain vs 0.40% out).

## 3. Follow-on project: a multi-wavelength emulator, 1.25–5.0 μm
Real SPHEREx covers 0.75–5 μm, so wavelength must become an input. 64 channels (ZodiPy), log λ as an input:
* **Works:** best version **~0.09–0.10% median** (p95 0.44%), full spectra within 0.6–0.9% of ZodiPy. Unseen wavelengths
  are about as accurate as seen ones.
* **Found a ZodiPy artifact:** it takes the dust phase-function coefficients from the *nearest* DIRBE band, which puts
  artificial **steps** in every spectrum at 1.725, 2.85, 4.2 μm (up to 7%). Feeding those coefficients in cut the
  error ~35%. **Question for the mentor:** emulate ZodiPy's steps, or regenerate with smooth coefficients (the real sky has none)?
* The rest was underfitting: **300 epochs instead of 100 cut error 2.5×**. Blackbody inputs and a bigger net didn't matter.
* Not covered: **0.75–1.25 μm** (ZodiPy's Kelsall model only extrapolates there), channel bandpasses, several
  wavelengths per exposure.

## 4. Tooling (your picks from last night)
* `data_manifest.jl` + `data/MANIFEST.tsv`: fingerprints of all 12 data files. `julia --project=. data_manifest.jl` checks a machine.
* `sweeps/run_threaded.jl`: K trainings in one process (`julia -t 4`), **bit-identical** to the old lanes, ~1/3 the
  memory (2.5 GB for 4 trainings vs ~9 GB). Used for rounds 13–15.
* `sweeps/test_nb.jl <notebook>`: runs any notebook top to bottom.

## Decisions for you / the mentor
1. Tell the mentor about the data errors (and whether other data from that script is affected).
2. Adopt Sun frame + sin/cos λ⊕ (emulator v2) as the default model?
3. Multi-wavelength: emulate ZodiPy's phase-coefficient steps, or smooth them? How to handle 0.75–1.25 μm?
4. Cluster: the 300-epoch multi-wavelength runs take ~20 min each here. Worth setting up the cluster account soon.

## Suggested next steps
* Longer-training multi-wavelength runs on the held-out channels (+ 500 epochs); then package a multi-λ emulator (v3).
* Rerun the remaining earlier tests (block lengths, sky patches 2/3, all-sky map) with the v2 inputs on corrected data.
* Extend the real-data pipeline (`pipeline/`) with the Sun-frame and wavelength inputs.

Runs overnight: rounds 10–15 = 55 + 40 + 35 + 40 + 10 + 20 = **200 trainings**, all finished, none failed.
