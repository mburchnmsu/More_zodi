# Apply round-3/4 updates to 10062026.ipynb (preserves all other cells, incl. the user's markdown).
include(joinpath(@__DIR__, "nbedit.jl"))
path = joinpath(@__DIR__, "..", "notebooks", "10062026.ipynb")
cp(path, joinpath(@__DIR__, "..", "notebooks", "10062026.before_round34.ipynb"), force=true)      # safety copy
nb = load_nb(path)
src(id) = join(nb["cells"][cell_index(nb, id)]["source"])

# 1. train_mb cell → current sweeps/mb_train.jl (target option, predict_y, invokelatest fix)
set_source!(nb, "7bf2c399", read(joinpath(@__DIR__, "nbcells", "train_mb_cell.jl"), String))

# 2. all-sky cell: convert log-target outputs back to MJy/sr
s = src("96679c8c")
@assert occursin("predict_batched(r.model, ", s)
set_source!(nb, "96679c8c", replace(s, "predict_batched(r.model, " => "predict_y(r, "))

# 3. ensemble cell: expose the output/target choice
s = src("e9281818")
s = replace(s, "VAL_DAYS     = nothing\n" =>
               "VAL_DAYS     = nothing\nENS_TARGET   = :linear      # :linear (recommended), :log, :softplus or :relmse — see round 4\n")
s = replace(s, "seed=s, label=lbl, val_days=VAL_DAYS)" => "seed=s, label=lbl, val_days=VAL_DAYS, target=ENS_TARGET)")
s = replace(s, "#   VAL_DAYS     —" => "#   ENS_TARGET   — output handling: :linear (recommended) | :log | :softplus | :relmse\n#   VAL_DAYS     —")
@assert occursin("target=ENS_TARGET", s)
set_source!(nb, "e9281818", s)

# 4. new cell after the all-sky cell: generalization ladder
ladder = raw"""
# ==============================================================================
# GENERALIZATION LADDER — the recommended recipe on every split
# rung 1 (random) → rung 2 (time blocks) → filling a hole → extrapolating forward in time.
# RUN_LADDER = false  → load the saved sweep results (sweeps/results/sp_*, final_base_*) — ~1 min
# RUN_LADDER = true   → retrain here: 3 seeds × 9 splits × ~5 min ≈ 2.5 h on a laptop CPU
# Tables/figures come from sweeps/summary_helpers.jl (same code as the 10072026 summary notebook).
# ==============================================================================
include(joinpath(PROJECT_DIR, "sweeps", "summary_helpers.jl"))
RUN_LADDER = false
if RUN_LADDER
    for (tag, sp) in [("rand", "random split"), ("wk7", "7-day alternating"), ("blk30", "30 day split"),
                      ("mid", "50/50 mid-mission"), ("c85", "85/15 Chronological"), ("c75", "75/25 Chronological"),
                      ("c50", "50/50 Chronological"), ("c25", "25/75 Chronological")], s in 42:44
        r = train_mb(FEATURE_SETS[:look_dir]; split_name=sp, seed=s, label="$tag seed $s")
        serialize(joinpath(RES, "sp_$(tag)_s$s.jls"), r)          # overwrites the saved sweep runs
    end
end
L = ladder_data()
display(ladder_table(L))
display(ladder_fig(L))
gap_fig(L)
"""
insert_after!(nb, "96679c8c", new_cell("code", strip(ladder)))

# 5. summary markdown cell: add rounds 3 and 4
s = src("8ffbb5d6")
extra = raw"""

### Round 3 — generalization ladder (same recipe on every split; 5- or 3-seed ensembles, test MSE)
| split | median gap to training | lin+quad | NN ensemble | median frac. error |
|---|---|---|---|---|
| random 50/50 | 0 d | 1.5e-3 | **9.6e-6** | 0.10% |
| 7-day / 30-day alternating | 1.8 / 7.4 d | 1.5e-3 | **~9e-6** | 0.11–0.14% |
| 50/50 mid-mission hole | 17.7 d | 1.7e-3 | **2.6e-5** | 0.31% |
| chrono 85/15 · 80/20 · 75/25 | 11–18 d | ~4e-3 | **6.4e-5 · 9.4e-5 · 1.4e-4** | 0.48–0.75% |
| chrono 50/50 · 25/75 | 34–53 d | 0.65 · 3.1e3 | **1.9e-3 · 2.9e-3** | 2.0–6.0% |

The network **interpolates superbly** (0.1% error, 100–170× better than lin+quad) and degrades smoothly when
**extrapolating in time**: error is flat to ~5 days beyond the training data, then rises steeply (×10 by ~15 d).

### Round 4 — output transforms (80/20 chronological)
| output | val ens. | test ens. | test seed range | all-sky in-domain median err. | near-Sun median err. |
|---|---|---|---|---|---|
| **linear (recommended)** | 3.2e-5 | **9.4e-5** | **0.9–2.2e-4** | 0.54% | 46% |
| log target | **1.8e-5** | 1.35e-4 | 1.5e-4–1.3e-3 | 0.41% | **38%** |
| softplus output | 2.6e-5 | 1.05e-4 | 1.1e-4–9.8e-4 | **0.40%** | 48% |
| relative-error loss | 3.8e-5 | 1.49e-4 | 1.8–2.8e-4 | 0.80% | 44% |

No variant (including linear) ever predicts a negative value, so positivity constraints aren't needed here. Log target wins
validation and all-sky fractional error and removes the late-test negative drift, but is 1.4× worse on the chronological
test and far more seed-sensitive — the same "validation is too close to see it" pattern as dropping `n·J`. **Linear stays
the recommendation; log target is the promising alternative** (set `ENS_TARGET = :log`).
"""
set_source!(nb, "8ffbb5d6", s * extra)

save_nb(path, nb)
println("updated 10062026.ipynb: ", length(nb["cells"]), " cells (safety copy: 10062026.before_round34.ipynb)")
