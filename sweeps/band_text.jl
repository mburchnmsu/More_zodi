# Cell contents for 10132026.ipynb — dust-band features + real-data pipeline.
CELLS = Pair{String,String}[

"markdown" => raw"""
# Dust-band features and real-data preparation (Oct 13, 2026)

**Part A — can a dust-band feature remove the β = 0 stripe?** The 10/10 sky-patch test left the season model's largest
error in a thin stripe along the ecliptic. Kelsall's three dust bands are the narrowest structures there, so we give the
network the bands' own vertical shape (Kelsall 1998 / ZodiPy parameters):

$$n_B \propto \tfrac{1}{R}\, e^{-u^6}\,(v + u^4)\,\big[1-e^{-(R/\delta_R)^{20}}\big],\qquad u = \zeta/\delta_\zeta,\ \ \zeta = |Z_B|/R$$

| band | δζ | v | i | Ω | δR |
|---|---|---|---|---|---|
| 1 | 8.78° | 0.10 | 0.56° | 80° | 1.5 AU |
| 2 | 1.99° | 0.90 | 1.2° | 30.3° | 0.94 AU |
| 3 | 15.0° | 0.05 | 0.8° | 80° | 1.5 AU |

* **Why not the plain band-plane normals?** n·n̂_B = cos i (n·z) + sin i (sin Ω n·x − cos Ω n·y) is an *exact* linear
  combination of features the model already has (checked: max difference 6e-15), so it adds nothing a first layer can't
  already compute. The features below are **nonlinear and sharp** instead.
* **sharp** (3 features): g(u) with ζ = latitude above each band plane *as seen from SPHEREx* (fixed on the sky).
* **parallax** (9 features): ζ at the point where the line of sight reaches heliocentric distance R = 1.25, 1.5, 2.0 AU —
  where the 5 μm band emission comes from (hot dust just outside each band's inner edge). These move with SPHEREx.
* **both** (12). All on top of the season model (n·* + sin/cos λ⊕), 5 seeds, same recipe as before.
* Tests: 30-day blocks, the three 12° sky patches from 10/10, and the 80/20 chronological split.

**Part B — real-data preparation** (`pipeline/`): one code path from a table of real exposures to the training features,
verified on the simulated data, plus a SLURM template for the cluster. A pipeline check turned up a model dependence on
SPHEREx's *orbital velocity direction* (n·vS), so a **season − n·vS** control was added to Part A.

### Summary
SUMMARY_PLACEHOLDER
""",

"code" => raw"""
include(joinpath(@__DIR__, "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl", "extra_splits.jl", "nb_verify_fns.jl", "summary_helpers.jl",
          "checks_helpers.jl", "band_helpers.jl")
    include(joinpath(@__DIR__, "sweeps", f))
end
include(joinpath(@__DIR__, "pipeline", "ZodiPipeline.jl")); using .ZodiPipeline
""",

"markdown" => raw"""
## A1. Do the band features look like the bands?
Before training: compare each feature with ZodiPy's own per-band brightness map at the all-sky epoch (13170). The parallax
versions should track the true band brightness much better than the fixed-on-the-sky ones, because the bands are seen from
inside, from ~1 AU, and the near side of a band appears far from its plane.
""",

"code" => raw"""
bfc = band_feature_check()
println("median share of the total 5 μm brightness within 10° of the ecliptic: band1 $(bfc.share[1])%, band2 $(bfc.share[2])%, band3 $(bfc.share[3])%")
bfc.table
""",

"code" => raw"""
bfc.fig
""",

"markdown" => raw"""
## A2. Accuracy: dust-band features and the n·vS control vs the season model
`vs_season` = ensemble test MSE ÷ the season model's on the same test (< 1 is better). `seeds_better` = how many of the 5
seeds beat the season model *with the same seed*. `ecliptic_err_pct` = median |error| of test exposures within 2° of the
ecliptic (only tests that contain such exposures).
""",

"code" => raw"""
BT = band_table()
""",

"code" => raw"""
band_fig()
""",

"markdown" => raw"""
## A3. The β = 0 stripe
Median |error| vs ecliptic latitude, for the held-out ecliptic patch (where the stripe was found on 10/10) and for the
30-day blocks.
""",

"code" => raw"""
stripe_fig()
""",

"markdown" => raw"""
## A4. All-sky test (epoch 13170, 30-day-block ensembles)
In-domain accuracy, and the correlation of each ensemble's in-domain residual with ZodiPy's component maps. If a band
feature works, the residual's correlation with that band should shrink toward 0.
""",

"code" => raw"""
AT, AF = band_allsky_table()
AT
""",

"code" => raw"""
AF["season"]
""",

"markdown" => raw"""
## A5. Does the network use the band features? (permutation importance)
Ensemble test MSE after shuffling one feature (÷ unshuffled), on 20,000 test exposures of the 30-day blocks, for the
**both** model. A ratio near 1 = feature ignored.
""",

"code" => raw"""
let rs = runs9("both", "blk"), te = rs[1].te_idx
    perm_importance(rs, te[1:max(1, length(te) ÷ 20_000):end])
end
""",

"markdown" => raw"""
## A6. Verification
Integrity (no train/test overlap, finite outputs, every member's split identical) and residual structure for the
held-out ecliptic patch ensembles.
""",

"code" => raw"""
V9 = Dict{String, Any}()
for (a, al) in ARMS9L
    rs = runs9(a, "p1"); isempty(rs) || (V9[al] = as_ensemble(rs, al))
end
for (a, al) in ARMS9L, (t, tl) in TESTS9L
    rs = runs9(a, t); isempty(rs) && continue
    @assert all(r -> r.tr_idx == rs[1].tr_idx && r.te_idx == rs[1].te_idx, rs) "$a/$t: members disagree on the split"
    @assert isempty(intersect(rs[1].tr_idx, rs[1].te_idx)) && all(r -> all(isfinite, r.ypred), rs)
end
println("integrity: every (variant, test) ensemble has 5 members on one split, disjoint train/test, finite predictions ✓")
verify_residuals(V9, [last(a) for a in ARMS9L if haskey(V9, last(a))]; tag="_bands")
""",

"markdown" => raw"""
## B. Real-data preparation (`pipeline/`)
`pipeline/ZodiPipeline.jl`: exposure table (time, pointing as a vector or RA/Dec, sky level, uncertainty, wavelength, keep
flag) → star-mask hook (**off**, `mode = :none`) → ephemerides from JPL Horizons vector tables (Hermite interpolation) →
the training features. `pipeline/cluster/`: SLURM job-array template + a lane script that shares a sweep's pending runs
between array tasks. Details and the Horizons request settings: `pipeline/README.md`. The checks (rerun with
`julia --project=. pipeline/test_pipeline.jl`):
""",

"code" => raw"""
for l in readlines(joinpath(@__DIR__, "pipeline", "pipeline_checks.log"))
    (occursin(r"^\[(PASS|FAIL)\]", l) || occursin("checks passed", l)) && println(l)
end
""",

"markdown" => raw"""
### What if the real data come without a SPHEREx ephemeris?
Then the pipeline puts SPHEREx at Earth's centre (S = E, v̂S = v̂E). The position shift (≤ 5e-5 AU) is harmless, but the
**velocity direction** swings by up to 15° around the 94-min orbit, and the season model uses it. The n·vS-free control
shows whether dropping the feature removes the dependence without costing accuracy.
""",

"code" => raw"""
ephemeris_sensitivity()
""",

"markdown" => raw"""
## Conclusions
CONCLUSIONS_PLACEHOLDER
""",
]
