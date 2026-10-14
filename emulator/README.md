# ZodiEmulator — packaged Kelsall 5 μm zodiacal-light emulator (v1, v2)

Neural-network emulator of the Kelsall (1998) 5 μm zodiacal emission (as computed by ZodiPy) along any line of sight,
trained on SPHEREx boresight geometry (More_zodi project). The same module loads either file.

## v2 (2026-10-14) — recommended
| | v1 (Oct 7) | **v2 (Oct 14)** |
|---|---|---|
| inputs | n·S n·z n·E n·vS n·vE n·J n·x n·y | n·S n·z n·E n·vS n·vE **n·x⊕ n·y⊕ sinλ⊕ cosλ⊕** (Sun frame + season; no Jupiter) |
| training data | original simulated data (has 2 generation errors) | **corrected** data (ZodiPy 1.1.5, `zodipy_gen/`) |
| training split | mission days 0–111 | random 90% of the whole 140-day mission |
| held-out accuracy | 80/20 chrono: median 0.54% | random 10%: **median 0.015%, p95 0.064%** |
| outside the mission (+30…+540 d) | — | in-domain median 0.06%, out-of-domain 0.40%; ≤0.1% up to ~90 days |

`n·x⊕, n·y⊕` = the pointing in a frame turned by Earth's ecliptic longitude λ⊕ (x⊕ = Sun→Earth). v2 does not need
Jupiter's position (`J` is optional). Files: `zodi_emulator_v2.jld2`, `export_emulator_v2.jl`,
`test_emulator_v2.jl` → `emulator_v2_checks.log` (7/7 checks, incl. v1 still reproducing exactly). Details and the
evidence: notebook 10142026. The rest of this README describes v1.

| file | what it is |
|---|---|
| `zodi_emulator_v1.jld2` | the model: 5 networks' weights (plain arrays), feature normalization, feature training ranges, metadata (163 KB) |
| `ZodiEmulator.jl` | self-contained module: `load_emulator`, `predict_zodi`, `out_of_range`, `load_ephemeris`, `emulator_features` |
| `example_usage.jl` | minimal example |
| `export_emulator.jl` | how the `.jld2` was made from `sweeps/results/final_base_s42..46.jls` |
| `test_emulator.jl` | verification + physical checks → `emulator_checks.log`, `emulator_checks.png` |

## Usage
```julia
include("emulator/ZodiEmulator.jl"); using .ZodiEmulator
em  = load_emulator("emulator/zodi_emulator_v1.jld2")
out = predict_zodi(em, nvec; S, E, vS, vE, J)    # nvec: 3×M unit vectors; S,E,J: AU; vS,vE: any units
out.mean       # MJy/sr (ensemble mean)        out.std   # spread across the 5 networks
out.in_domain  # true where every input feature is inside its training range — trust only these
out_of_range(em, out, k)                         # which features put direction k out of domain
```
Frame: barycentric ecliptic. Each of `S, E, vS, vE, J` can be one 3-vector (a single epoch for all directions)
or a 3×M matrix (one epoch per direction). `load_ephemeris(vectors_h5, idx)` pulls them from the project data.

## Model
8 look-direction features `n·S, n·z, n·E, n·v̂S, n·v̂E, n·J, n·x, n·y` → 64-64-32-16 gelu MLP; batch 512, Adam,
one-cycle LR (peak 1e-3), 100 epochs, MSE; 5 seeds (42–46) averaged. Trained on mission days 0–111.4 (JD range in metadata).

## Verified (see `emulator_checks.log`)
**Reproduction** — identical to the saved sweep ensemble on all 423,607 exposures (max |Δ| = 0); the module's own
feature computation matches the notebook's exactly.

**Accuracy** — 80/20 chronological test MSE 9.40e-5 (median |error| 0.54%); all-sky (epoch 13170) in-domain
33% of the sky, rms 0.0067 MJy/sr, median |error| 0.54%.

**Physical behaviour, model vs Kelsall truth (in-domain all-sky, epoch 13170)**
* positive everywhere on the sky (min 0.278 MJy/sr; truth 0.266) — no positivity constraint needed;
* brightness vs ecliptic latitude matches truth to < 3% in every 10° band, brightest at the ecliptic;
* brightness vs solar elongation near the ecliptic matches truth (correlation 1.000), fainter away from the Sun;
* **north/south asymmetry from the ~2° cloud tilt**: same sign and pattern (north brighter, +7.4% model vs +9.0%
  truth, pattern correlation 0.77) — the model reproduces ~84% of the amplitude;
* **Earth-trailing feature**: at matched elongation the trailing side is brighter in both (95–100°: +4.1% model vs
  +4.3% truth; 100–110°: +2.8% vs +2.0%);
* every direction within 60° of the Sun is flagged out-of-domain (their median error is 46%).

## Known limitations (all trace to the same physics)
1. **Extrapolation in time.** Accuracy is flat to ~5 days beyond the training data, then degrades
   (pole exposures: −2.4% by days 111–125, −4.9% by 125–140). Train on data covering the period you predict.
2. **Within ~2° of the ecliptic poles** errors scatter more (5–95%: ±2–3% north, up to −7/+4% south) though the median
   is ≈ 0. There every `n·(in-plane vector)` feature → 0, so the inputs barely change while the pole brightness varies
   with Earth's orbital phase relative to the tilted cloud (0.35–0.47 MJy/sr) — the network can't see the season.
   The same blind spot explains the ~16% shortfall in north/south asymmetry.
3. **Out of domain** (toward the Sun, or sky regions not observed before day 111) predictions are extrapolations;
   the ensemble spread does **not** warn there. Use `in_domain` / `out_of_range`. The strict range check also flags the
   exact pole (n·z = 1.0000 > max 0.99999…), which is harmless.
4. Speed: ~12 μs per direction for the 5-network ensemble on a laptop CPU (full 786k-pixel sky ≈ 9 s, single
   direction ≈ 23 μs). Not optimized (single-threaded Flux, no GPU).
