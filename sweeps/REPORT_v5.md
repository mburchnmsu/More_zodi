# Round 5 — what is the "Jupiter null" feature n·J doing? (2026-10-07)

Validation protocol (fit days 0–100, validate 100–111.4, test 111.4–139.7); 64-64-32-16, one-cycle 1e-3, 100 epochs,
5 seeds each. `n·J` replaced by: the moving unit vector `n·Ĵ`, a FIXED axis along Jupiter's mission-mean direction
`n·Ĵfix` (ecliptic lon 93.8° ≈ +y), or a fixed control axis 90° away `n·Ĵ⊥fix` (≈ −x). Code: `configs_v5.jl`, `analyze_v5.jl`.

| variant | val ens. | test seed median | test ens. | late-test bias | bad seeds (>2e-3) |
|---|---|---|---|---|---|
| n·J (baseline) | 3.1e-5 | 4.5e-4 | **2.7e-4** | −0.014 | 0 |
| n·Ĵ moving unit vector | 3.1e-5 | 4.3e-4 | **2.7e-4** | −0.015 | 0 |
| n·Ĵfix fixed axis (≈ n·y) | 3.4e-5 | 7.8e-4 | 9.0e-4 | −0.028 | 2 |
| n·Ĵ⊥fix control (≈ −n·x) | 2.1e-5 | 1.1e-3 | 3.6e-4 | +0.006 | 1 |
| no Jupiter feature | 3.0e-5 | 1.6e-3 | 6.8e-4 | −0.019 | 1 |

## Geometry facts (checked)
* Jupiter: |J| = 5.12–5.17 AU, ecliptic longitude 87.9° → 99.7° over the mission (12° of motion), latitude ≈ −0.2°.
* corr(n·J, n·Ĵ) = 1.0000 → Jupiter's distance is irrelevant; n·J is effectively a *direction*.
* Regressing each candidate on (n·x, n·y, n·z): the fixed axes are exact linear combinations (residual 1e-15);
  `n·J` leaves a small residual (rms 0.074 of 2.2, ≈3%) — **Jupiter's 12° motion, i.e. a slowly varying,
  time-dependent term**. That is the only information `n·J` adds beyond the fixed inertial frame.
* All of n·J, n·Ĵ, n·Ĵfix, n·y are ~25% out of their training range in the test period — because SPHEREx looks
  at sky regions it never observed before day 111 (sky coverage), not because Jupiter moved.

## Interpretation
1. `n·Ĵ` ≡ `n·J` (identical performance) — as expected from the 1.0000 correlation.
2. **Fixed axes don't recover n·J's benefit, even though they carry the same static information** — and they make
   training less stable (near-duplicates of n·y / n·x: correlation 0.997 / −0.999 → ill-conditioned inputs, bad seeds).
3. So the part of `n·J` that helps is plausibly its **slow time dependence**: Jupiter's motion acts as a weak
   *clock* / season proxy that partly compensates for the n·* features' lack of orbital phase. The baseline's
   smaller late-test drift than "no Jupiter" (−0.014 vs −0.019) is consistent with that.
4. Caveat: 5 seeds each with large seed scatter; removing a feature also changes the network's input layer. The
   evidence is consistent and physically coherent, but moderate.

## Why it matters
**The Jupiter "null test" is not a clean null in this setup.** Kelsall has no Jupiter, yet `n·J` helps — because it
leaks time information, not because of any Jupiter physics. On real SPHEREx data a Jupiter-correlated signal would be
confounded with season unless the null feature carries no time information (e.g. decorrelate it from time, or
compare against a time-matched control feature). Avoid near-duplicate input features (fixed axes ≈ existing ones).
