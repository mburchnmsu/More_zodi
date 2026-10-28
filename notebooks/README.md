# Notebooks (dated MMDDYYYY)

All research notebooks of the More_zodi project, one per working day. Each starts with a setup cell that loads the
project code one folder up (`include(joinpath(@__DIR__, "..", "zodi_setup.jl"))`, then helpers from `../sweeps/`).
Most are built from a cell-text file (`julia sweeps/build_nb.jl sweeps/<x>_text.jl <MMDDYYYY>.ipynb`, written here) and
tested top to bottom with `julia --project=. sweeps/test_nb.jl <MMDDYYYY>.ipynb`.

| Notebook | What it covers |
|---|---|
| 10062026.ipynb | Working notebook, day 1: data, look-direction (n·*) features, full-batch → mini-batch training, first architectures |
| 10062026.backup.ipynb, 10062026.before_round34.ipynb | Safety copies of 10062026 (before the round-3/4 updates) |
| 10072026.ipynb | Mentor-presentation summary: recommended model, 80/20 chronological test, all-sky maps |
| 10082026.ipynb | Earth-centric control and Jupiter null checks (round 6) |
| 10092026.ipynb | Earth's orbital phase (sin/cos λ⊕) inputs: 44–65× lower interpolation error; log target revisited |
| 10102026.ipynb | Generalization tests for the mentor meeting: 30-day gaps, unseen sky patches, data-size scaling |
| 10132026.ipynb | Dust-band features (round 9) and the real-data pipeline (user-edited) |
| 10142026.ipynb | Corrected data (z115), extrapolation in time, Sun-frame inputs (rounds 10–12) |
| 10142026_multiwavelength.ipynb | Multi-wavelength emulator, 1.25–5 μm (round 13–15) |
| 10152026.ipynb | Shifted 30-day windows, train + test MSE, out-of-sample sky-error map (round 16) |
| 10172026.ipynb | Loss curves and why they are jagged, smoothing, 80/20 at 300 epochs, error vs time gap, trailing-feature check, month splits at 300 epochs (rounds 17–20) |
| 10282026.ipynb | Learning-rate schedule test: cos×exp (with warm-up) vs one-cycle at equal average learning rate, shifts 0 and 30 (round 35); the mentor's requests: interpolation-only vs interpolation + extrapolation sky maps, 2-D trailing-cloud residual map (no residual from the cloud) |
| 10272026.ipynb | Round 34 complete: 2000 vs 500 epochs on all 6 shifts, full sky map (ecliptic 0.0285% → 0.0162%), the shift-30 overfitting, fitted bands at 2000 epochs, round 35 queued |
| 10262026.ipynb | Round 34 halfway: 3 of 6 shifts at 2000 epochs, per-shift MSE (−36 to −40%), 3-shift sky map, the standby pause |
| 10242026.ipynb | Parallax band layer trained 2000 vs 500 epochs: first 2 of 6 shifts, loss curves, partial sky map (round 34) |
| 10232026.ipynb | Parallax dust-band layer, the full 500-day sky map with it (ecliptic 0.050% → 0.0285%), fitted band parameters, the mentor's Earth-centric null test (rounds 31–33) |
| 10222026.ipynb | Heliocentric default, the full heliocentric 500-day sky map, the learnable dust-band layer (rounds 29–30) |
| 10212026.ipynb | Heliocentric 500-day sky map, the Jupiter null experiment, comparison with the mentor's onboarding plan, poster review (rounds 27–28) |
| 10202026.ipynb | 500-day data, the 500-day model, the Sun's wobble (heliocentric inputs replace n·J), the mentor's trailing-cloud tests 1–2, poster redesign (rounds 24–27) |
| 10182026.ipynb | Month splits at 750 epochs, sky map with/without blending, the mentor's Earth-trailing-cloud stack, poster v6 (round 21–22) |
