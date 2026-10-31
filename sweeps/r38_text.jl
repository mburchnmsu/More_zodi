# Cell contents for 10302026.ipynb — Oct 30: round 38 (cos×exp at 1000 epochs on all 6 shifts, sweeps/report38.jl), real
# SPHEREx data at a mid-latitude point (30° above the ecliptic, realdata/), and the NMSU Discovery cluster set-up.
#     julia --project=. sweeps/build_nb.jl sweeps/r38_text.jl 10302026.ipynb
CELLS = Pair{String,String}[

"markdown" => raw"""
# cos×exp at 1000 epochs on all 6 splits, a mid-latitude point in real SPHEREx data, and the cluster (Oct 30, 2026)

### Summary
* **Round 38 (§1):** cos×exp at 1000 epochs, now on all 6 splits, **ties one-cycle at 2000 epochs with half the training**.
  Mean ensemble test MSE is 1.52 vs 1.74 × 10⁻⁸ (1.51 vs 1.53 without shift 30, where one-cycle 2000 overfits). Sky-map
  median 0.0130% for both. One-cycle 2000 is still a little better within 2° of the ecliptic (0.0162% vs 0.0181%).
* **Real data, 30° above the ecliptic (§2):** 15 SPHEREx exposures (June 2025, January 2026, June 2026). The point is
  **1.8× brighter in January** (90° from the Sun) than in June (120°), and ZodiPy predicts it. The image fits
  **1.11 × ZodiPy + 0.11 MJy/sr** (rms 0.008), almost the same relation as at the pole.
* **Cluster (§3):** NMSU Discovery is set up (Julia 1.12.6, data checked by checksum). A first job repeats a round 37
  set (shift 0, 5 seeds) to check that the cluster reproduces the laptop.
""",

"code" => raw"""
using CairoMakie
const R = joinpath(@__DIR__, "..")
struct PNGFile; path::String; end; Base.show(io::IO, ::MIME"image/png", p::PNGFile) = write(io, read(p.path))   # raw PNG bytes: renders in any Jupyter front end
showpng(f) = PNGFile(joinpath(R, "figures", f))
""",

"markdown" => raw"""
## 1. Round 38: cos×exp at 1000 epochs on all 6 splits (`sweeps/configs_v38.jl`, report `sweeps/report38.jl`)
Round 37 ran shifts 0 and 30. Round 38 ran the other four (10, 20, 40, 50 × 5 seeds; 5 at a time on the ThinkPad,
Oct 29 23:59 → Oct 30 21:40, ~5.4 h per shift). Same schedule: 5% warm-up, peak 2e-3, decay 3, parallax band layer.

| ensemble test MSE (×10⁻⁸) | shift 0 | 10 | 20 | 30 | 40 | 50 | mean |
|---|---|---|---|---|---|---|---|
| one-cycle, 500 epochs | 2.44 | 2.37 | 2.40 | 2.53 | 2.43 | 2.37 | 2.42 |
| cos×exp, 500 epochs | 1.93 | 1.96 | 2.25 | 2.32 | 2.28 | 2.10 | 2.14 |
| **cos×exp, 1000 epochs** | **1.38** | **1.46** | 1.70 | **1.57** | **1.50** | 1.53 | **1.52** |
| one-cycle, 2000 epochs (round 34) | 1.47 | 1.48 | **1.54** | 2.80 | 1.73 | **1.43** | 1.74 |

| per seed, mean ± std (×10⁻⁸) | shift 0 | 10 | 20 | 30 | 40 | 50 |
|---|---|---|---|---|---|---|
| cos×exp, 1000 epochs | 1.75 ± 0.24 | 1.82 ± 0.14 | 2.17 ± 0.12 | 2.12 ± 0.14 | 1.98 ± 0.14 | 1.93 ± 0.16 |
| one-cycle, 2000 epochs | 1.82 ± 0.19 | 1.82 ± 0.13 | 1.87 ± 0.09 | 3.51 ± 0.91 | 2.09 ± 0.17 | 1.71 ± 0.06 |

| sky map, all 6 shifts | median | p95 | within 2° of the ecliptic | above 60° |
|---|---|---|---|---|
| one-cycle, 500 epochs | 0.0157% | 0.049% | 0.0285% | 0.0134% |
| cos×exp, 500 epochs | 0.0147% | 0.046% | 0.0247% | 0.0128% |
| cos×exp, 1000 epochs | **0.0130%** | 0.038% | 0.0181% | **0.0118%** |
| one-cycle, 2000 epochs | **0.0130%** | **0.035%** | **0.0162%** | 0.0120% |

* **A tie with half the training.** Per seed, cos×exp 1000 is much better on shift 30, slightly better on 40 (~1 standard
  error), equal on 0 and 10, and worse on 20 and 50 (by ~4.5 and ~3 standard errors). Without shift 30 the ensemble means are 1.51 vs 1.53.
* **It never overfits.** All 30 seeds sit at 1.5–2.3; one-cycle 2000 had two seeds near 4.5 on shift 30.
* **The ecliptic is where one-cycle 2000 still wins** (red along the ecliptic in the lower-right map). Doubling the
  epochs again (cos×exp 2000, round 39, prepared for the cluster) is the natural test.
* Doubling cos×exp from 500 to 1000 epochs cut the error 29% on average, and 27% on the ecliptic (lower-left map, blue).
""",

"code" => raw"""
showpng("10302026_r38_sky.png")
""",

"markdown" => raw"""
## 2. Real data 30° above the ecliptic (ecliptic longitude 210°)
The model matters most away from both the pole and the ecliptic. `realdata/scan_ecliptic.py` counted, every 30° of
longitude at ecliptic latitude 30° and 40°, the D6 images that see the point at 4.9–5.1 μm. Chosen: **β = 30°,
λ = 210°** (RA 218.487°, Dec 16.649°): the most frames (18 selected, **15 at 4.9–5.1 μm**) and far from the Milky Way
(Galactic latitude +64°). Longitudes 90°, 270° and 300° had similar counts but lie within 15° of the Galactic plane.
All 15 frames are from qr2, in three visits: June 2025, January 2026, June 2026. Movie
`figures/10302026_b30l210_movie.mp4` (git-ignored; `julia --project=. realdata/make_movie.jl 10302026 all b30l210`).
""",

"code" => raw"""
showpng("10302026_b30l210_montage.png")
""",

"markdown" => raw"""
* **January is ~1.8× brighter than June** (ZodiPy ~0.60–0.72 vs ~0.36 MJy/sr), in both the data and ZodiPy. The reason
  is the direction to the Sun, not distance: in January the line of sight is ~91° from the Sun and passes through the
  dense inner dust cloud; in June it is ~119°. At the pole this angle hardly changes, which is why the pole only varies
  by ±15%.
* **Image = 1.11 × ZodiPy + 0.11 MJy/sr, rms 0.008 MJy/sr.** At the pole (qr2): 1.06–1.09 × ZodiPy + 0.10. The same scale
  and offset at a very different place on the sky suggests both are real: a scale difference between the data and the
  Kelsall model, plus ~0.1 MJy/sr of light that isn't zodi.
* That constant offset is why image / ZodiPy drops from ~1.42 in June to ~1.28 in January.
* **SPHEREx's own zodi model = 1.055 × ZodiPy** (1.037–1.074), like the pole (1.04) and the ecliptic point (1.06–1.07) in qr2.
""",

"code" => raw"""
showpng("10302026_b30l210_lightcurve.png")
""",

"markdown" => raw"""
## 3. The NMSU Discovery cluster (`pipeline/cluster/`)
* SSH alias `discovery`, repo at `~/More_zodi`, Julia 1.12.6 (juliaup). The four z500 data files were copied and
  checked by sha256 against the laptop. Nothing heavy runs on the login node: everything goes through `sbatch`.
* `pipeline/cluster/threaded.sbatch` runs `sweeps/run_threaded.jl` exactly as on the laptop (K trainings in one Julia
  process, 1 BLAS thread each, K = `--cpus-per-task`). Finished runs are skipped, so resubmitting is safe.
* Training logs now print a progress line every 50 epochs (`PROGRESS_EVERY`): epoch, losses, learning rate, minutes per
  epoch and ETA (`tail -f logs/zodi-train_<job>.out`).
* Results are copied back with `pipeline/cluster/fetch_results.ps1`; notebooks are built on the ThinkPad.
* **Validation job 689233:** round 37's shift 0 (cos×exp 1000, 5 seeds) on one node with 5 CPUs, to compare with the
  laptop (ensemble 1.38 × 10⁻⁸; seeds 1.52, 1.71, 1.79, 1.60, 2.14). Still running when this notebook was built; it
  started before the progress-line commit, so its log stays silent until it finishes. CPU use (~4.8 cores) shows it is
  training normally.
""",
]
