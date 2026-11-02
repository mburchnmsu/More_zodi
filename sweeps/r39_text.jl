# Cell contents for 11012026.ipynb — Nov 1: round 39 (cos×exp at 2000 epochs on all 6 shifts, the first round trained on
# NMSU Discovery; sweeps/report39.jl) and round 40 (AdamW weight decay, submitted).
#     julia --project=. sweeps/build_nb.jl sweeps/r39_text.jl 11012026.ipynb
CELLS = Pair{String,String}[

"markdown" => raw"""
# cos×exp at 2000 epochs: the first cluster round (Nov 1, 2026)

### Summary
* **Cluster validation:** Discovery reproduces the laptop exactly. Round 37's shift 0 rerun there gave the same test MSE
  for all 5 seeds, to every printed digit. Cluster cores are ~1.5× slower each, but it runs many jobs at once.
* **Round 39** (cos×exp, 2000 epochs, all 6 shifts × 5 seeds; 6 jobs, Oct 31 08:25 → Nov 1 05:09): **the best sky map so
  far, tied with one-cycle 2000.** Median 0.0129%, p95 0.035%, ecliptic **0.0163%** (vs 0.0181% at 1000 epochs). But
  the overfitting is back on shifts 30 and 40, so its mean ensemble MSE (1.61) is worse than at 1000 epochs (1.52).
* **Round 40** (submitted Nov 1): the same with AdamW weight decay at 3 strengths on shifts 0, 30 and 40, to see if
  decay keeps the ecliptic gain without the overfitting.
""",

"code" => raw"""
const R = joinpath(@__DIR__, "..")
struct PNGFile; path::String; end; Base.show(io::IO, ::MIME"image/png", p::PNGFile) = write(io, read(p.path))   # raw PNG bytes: renders in any Jupyter front end
showpng(f) = PNGFile(joinpath(R, "figures", f))
""",

"markdown" => raw"""
## 1. Cluster validation (job 689233)
Round 37's shift 0 (cos×exp 1000, seeds 42–46) rerun on Discovery node c17 with the same `sweeps/run_threaded.jl`:

| seed | 42 | 43 | 44 | 45 | 46 |
|---|---|---|---|---|---|
| laptop test MSE (×10⁻⁸) | 1.5204 | 1.7110 | 1.7876 | 1.5979 | 2.1394 |
| Discovery test MSE (×10⁻⁸) | 1.5204 | 1.7110 | 1.7876 | 1.5979 | 2.1394 |

Same Julia (1.12.6), same package versions (Manifest), 1 BLAS thread per training: the arithmetic is reproducible.
~37,000 s per run vs ~25,000 s on the laptop, plus ~16 min of package precompiling on the first job on a node.

## 2. Round 39: cos×exp at 2000 epochs (`sweeps/configs_v39.jl`, report `sweeps/report39.jl`)
One Discovery job per shift (5 CPUs, 5 trainings at once), 13–21 h each depending on the node.

| ensemble test MSE (×10⁻⁸) | shift 0 | 10 | 20 | 30 | 40 | 50 | mean |
|---|---|---|---|---|---|---|---|
| cos×exp, 500 epochs | 1.93 | 1.96 | 2.25 | 2.32 | 2.28 | 2.10 | 2.14 |
| cos×exp, 1000 epochs | **1.38** | **1.46** | 1.70 | **1.57** | **1.50** | 1.53 | **1.52** |
| **cos×exp, 2000 epochs** | 1.39 | **1.46** | 1.58 | 2.12 | 1.68 | **1.43** | 1.61 |
| one-cycle, 2000 epochs | 1.47 | 1.48 | **1.54** | 2.80 | 1.73 | **1.43** | 1.74 |

| per seed, mean ± std (×10⁻⁸) | shift 0 | 10 | 20 | 30 | 40 | 50 |
|---|---|---|---|---|---|---|
| cos×exp, 1000 epochs | 1.75 ± 0.24 | 1.82 ± 0.14 | 2.17 ± 0.12 | 2.12 ± 0.14 | 1.98 ± 0.14 | 1.93 ± 0.16 |
| cos×exp, 2000 epochs | 1.75 ± 0.26 | 1.87 ± 0.22 | 1.98 ± 0.03 | 2.96 ± 0.79 | 2.17 ± 0.29 | 1.81 ± 0.08 |

| sky map, all 6 shifts | median | p95 | within 2° of the ecliptic | above 60° |
|---|---|---|---|---|
| cos×exp, 500 epochs | 0.0147% | 0.046% | 0.0247% | 0.0128% |
| cos×exp, 1000 epochs | 0.0130% | 0.038% | 0.0181% | **0.0118%** |
| **cos×exp, 2000 epochs** | **0.0129%** | **0.035%** | 0.0163% | 0.0119% |
| one-cycle, 2000 epochs | 0.0130% | **0.035%** | **0.0162%** | 0.0120% |

* **The extra 1000 epochs help near the ecliptic** (0.0181% → 0.0163%, the blue stripe in the lower-left map) and on
  shifts 20 and 50, where cos×exp 1000 was behind.
* **But overfitting returns on shifts 30 and 40.** Shift 30's seeds spread from 1.89 to 3.94 (at 1000 epochs: 1.95–2.31);
  shift 40's from 1.76 to 2.43. Same pattern as one-cycle 2000: the training loss keeps falling, the withheld months don't.
* cos×exp 2000 and one-cycle 2000 end up nearly identical on the sky map (lower-right map is almost white); on the
  ensemble MSE cos×exp is better on shift 30 (2.12 vs 2.80) and otherwise within noise.
* **So:** 1000 epochs is the safe choice; 2000 epochs is better near the ecliptic if the overfitting can be controlled.
""",

"code" => raw"""
showpng("11012026_r39_sky.png")
""",

"markdown" => raw"""
## 3. Round 40 (submitted Nov 1): weight decay (`sweeps/configs_v40.jl`)
New `adamw = λ` option in `train_mb`: AdamW, where each step shrinks the MLP weights by lr·λ, so the decay follows the
learning-rate schedule and stops when it does. The band layer is **not** decayed (its parameters are physical:
inclination, node, width, distance). Checked on a toy model: band layer unchanged, MLP shrink exactly lr·λ per step,
λ = 0 identical to Adam. Smoke test on Discovery (job 691126, 2 epochs of a real config): OK.

Round 39's setup plus λ = 1e-4, 1e-3, 1e-2 on shifts 0 (reference), 30 and 40 (the overfitting ones) × 5 seeds:
45 runs, 9 Discovery jobs (691131–691139), ~13–21 h each. Over the whole schedule the learning rates add up to ~1500,
so without gradients λ would shrink the weights by ×0.86, ×0.22 and ×3 × 10⁻⁷ (from mild to strong).
""",
]
