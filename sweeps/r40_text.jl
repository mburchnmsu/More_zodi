# Cell contents for 11022026.ipynb — Nov 2: round 40 (AdamW weight decay, sweeps/report40.jl), meeting prep for Nov 3
# (last week's four tasks, the precision figure without the SPHEREx rows), and rounds 41–42 submitted (best-epoch selection).
#     julia --project=. sweeps/build_nb.jl sweeps/r40_text.jl 11022026.ipynb
CELLS = Pair{String,String}[

"markdown" => raw"""
# Weight decay, best-epoch selection, and the Nov 3 meeting (Nov 2, 2026)

### Summary
* **Round 40 (§1):** AdamW weight decay on cos×exp 2000, shifts 0/30/40. **It does not cure the overfitting.** λ = 1e-3
  helps shift 30 but loses the ecliptic gain; λ = 1e-4 keeps the ecliptic gain and gives the best shift 0 yet (1.29 × 10⁻⁸);
  λ = 1e-2 cannot fit. The bad seeds stay bad whatever λ is, so the problem is not weight size.
* **Best-epoch selection (§2)** is now in `train_mb`: a whole training window is held out as validation, and the epoch with
  the lowest validation loss is kept. Round 42 tests it; round 41 runs λ = 1e-4 on the other 3 shifts.
* **Meeting prep (§3):** last week's four tasks, the numbers for the slides, and the precision figure without the SPHEREx rows.
""",

"code" => raw"""
const R = joinpath(@__DIR__, "..")
struct PNGFile; path::String; end; Base.show(io::IO, ::MIME"image/png", p::PNGFile) = write(io, read(p.path))   # raw PNG bytes: renders in any Jupyter front end
showpng(f) = PNGFile(joinpath(R, "figures", f))
""",

"markdown" => raw"""
## 1. Round 40: AdamW weight decay (`sweeps/configs_v40.jl`, report `sweeps/report40.jl`)
Round 39's setup (cos×exp, warm-up 5%, peak 2e-3, decay 3; 2000 epochs; parallax band layer) plus AdamW: each step
shrinks the MLP weights by lr·λ, so the decay follows the learning-rate schedule. The band layer is not decayed (its
parameters are physical). The learning rates sum to ~1500 over a run, so without gradients λ = 1e-4, 1e-3, 1e-2 would shrink
the weights by ×0.86, ×0.22, ×3 × 10⁻⁷. Shifts 0, 30, 40 × 5 seeds: 45 runs, 9 Discovery jobs (691131–691139), Nov 1
19:29 → Nov 2 16:03.

| ensemble test MSE (×10⁻⁸) | shift 0 | 30 | 40 | mean | within 2° of the ecliptic |
|---|---|---|---|---|---|
| cos×exp, 1000 epochs | 1.38 | **1.57** | **1.50** | **1.48** | 0.0178% |
| cos×exp, 2000 epochs (round 39) | 1.39 | 2.12 | 1.68 | 1.73 | **0.0164%** |
| + AdamW λ = 1e-4 | **1.29** | 1.99 | 1.70 | 1.66 | **0.0164%** |
| + AdamW λ = 1e-3 | 1.45 | 1.80 | 1.59 | 1.61 | 0.0190% |
| + AdamW λ = 1e-2 | 6.18 | 6.31 | 6.24 | 6.24 | 0.0653% |

| per seed, mean ± std [range] (×10⁻⁸) | shift 0 | 30 | 40 |
|---|---|---|---|
| cos×exp, 1000 epochs | 1.75 ± 0.24 | 2.12 ± 0.14 [1.95–2.31] | 1.98 ± 0.14 |
| cos×exp, 2000 epochs | 1.75 ± 0.26 | 2.96 ± 0.79 [1.89–3.94] | 2.17 ± 0.29 |
| + AdamW λ = 1e-4 | **1.60 ± 0.09** | 2.89 ± 0.98 [1.66–3.96] | 2.12 ± 0.28 |
| + AdamW λ = 1e-3 | 1.82 ± 0.27 | 2.62 ± 0.95 [1.79–4.15] | 2.04 ± 0.25 |
| + AdamW λ = 1e-2 | 6.94 ± 0.14 | 7.08 ± 0.12 | 7.01 ± 0.34 |

Sky map over the interpolation windows of these 3 shifts (median / p95 / ecliptic / above 60°): cos×exp 1000 0.0131% /
0.040% / 0.0178% / 0.0118%; cos×exp 2000 0.0135 / 0.039 / 0.0164 / 0.0126; +1e-4 0.0132 / 0.038 / 0.0164 / 0.0121;
+1e-3 0.0132 / 0.041 / 0.0190 / 0.0117; +1e-2 0.0218 / 0.070 / 0.0653 / 0.0192.

* **λ = 1e-2 is far too strong:** the training MSE stays at ~6 × 10⁻⁸, so the networks can't fit at all.
* **λ = 1e-3 trades one gain for another:** shift 30 improves (2.12 → 1.80), but the ecliptic gain from 2000 epochs is gone
  (0.0190%, worse than 1000 epochs).
* **λ = 1e-4 is the best compromise:** the ecliptic stays at 0.0164%, and shift 0's seeds are the tightest yet. But shift 30 is
  barely helped.
* **No λ beats cos×exp 1000 on shift 30** (1.57). Seed 43 on shift 30 ends at 3.5–4.2 with or without decay. Some
  trainings drift on the withheld months while the training loss keeps falling, and shrinking the weights doesn't stop
  that. Hence best-epoch selection (§2).

## 2. Best-epoch selection (new in `train_mb`) and rounds 41–42
* `val_tranges = [(t0, t1), …]`: training exposures with t0 ≤ t_rel < t1 are held out as validation. They are whole time
  windows, so the validation loss tests filling a gap in time, like the withheld months (random exposures would have
  neighbours in the training set).
* `keep_best = true`: track the validation loss every epoch, and at the end restore the weights of the best epoch (in place,
  `Flux.loadmodel!`). The result gains `best_epoch` and `te_best`; the DONE lines report `te_best`. Histories stay complete.
* **Checks** (`sweeps/smoke_best.jl`, local): 2 epochs of a round-40 config give exactly the cluster's number
  (2.3985878215171397e-4), so old runs are unchanged. The validation window for shift 30 (t_rel 270–300 d, 88,987
  exposures) lies inside a training window and overlaps neither train nor test. The best epoch matches the minimum of the
  validation history, and `te_best` matches the returned predictions.
* **Round 41** (`sweeps/configs_v41.jl`, jobs 691528–691530): λ = 1e-4 on shifts 10, 20, 50, so this setting gets a full
  6-shift sky map.
* **Round 42** (`sweeps/configs_v42.jl`, jobs 691539–691541): cos×exp 2000, no decay, validation window k = 8 of the
  30-day split (t_rel ∈ [Δ + 240, Δ + 270), ~1/8 of the training exposures), keep_best, shifts 0/30/40 × 5 seeds. Note:
  12% less training data than round 39, so the comparison is not quite like for like.

## 3. Meeting prep (Nov 3, Dr. Saydjari)
Deck organized by last week's four tasks: (1) the 2-D sky plot of residuals (no Earth-trailing-cloud signal: missing
fraction −0.0001 ± 0.0001; notebook 10282026), (2) the interpolation plot, (3) Kelsall's residuals vs ours, (4) starting on
real data (notebooks 10292026, 10302026). Then rounds 35–40 and the cluster.

**Interpolation vs extrapolation** (round 34 best model, 6 splits × 5 seeds; notebook 10282026):

| withheld windows | share of exposures | median | p95 | within 2° of ecliptic | above 60° |
|---|---|---|---|---|---|
| interpolation only | 98% | 0.0130% | 0.035% | 0.0162% | 0.0120% |
| extrapolation only (10–30 days past training) | 10% | 0.0168% | 0.043% | 0.0226% | 0.0153% |
| all withheld windows | 100% | 0.0132% | 0.035% | 0.0166% | 0.0122% |

**Our model vs Kelsall, against Kelsall vs data:**

| comparison | typical difference | × our model's error |
|---|---|---|
| our model vs Kelsall (full-sky median) | 0.013% | 1× |
| Kelsall vs DIRBE, best band (Table 5) | 0.28% | ~20× |
| Kelsall vs DIRBE, worst band | 1.49% | ~115× |
| Kelsall vs DIRBE, single pixels | 2–4% | ~150–300× |
| Kelsall vs other data, high latitude | a few % | ~150–400× |
| Kelsall vs other data, near the ecliptic | 10–30% | ~800–2300× |
| Kelsall vs SPHEREx at the pole (scatter) | ~1.5% | ~115× |
| SPHEREx zodi model vs ZodiPy | 4–21% | ~300–1600× |

The "~20×" is 0.28% ÷ 0.013%, the most conservative ratio (Kelsall's best band). The literature rows still need checking
against the papers. The figure below is the one in notebook 10292026 §9 without the SPHEREx rows
(`julia --project=. realdata/precision_compare.jl 11022026 nospherex`).
""",

"code" => raw"""
showpng("11022026_precision_compare_nospherex.png")
""",
]
