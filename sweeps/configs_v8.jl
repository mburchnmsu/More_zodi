# Round 8 (2026-10-10): block-length sweep, sky-patch holdouts, learning curve — baseline n·* vs n·* + sin/cos λ⊕.
# 3 seeds (42–44). Reuses existing runs where the config is identical:
#   30-day blocks: sp_blk30_* (baseline), se_blk_* (season);  7-day blocks: sp_wk7_* (baseline).
include(joinpath(@__DIR__, "extra_splits.jl"))
const R8 = (; arch=:mlp, hidden=(64, 64, 32, 16), batchsize=512, epochs=100, schedule=:onecycle, lr_max=1e-3)
const MODELS8 = [("base", :look_dir), ("season", :look_dir_season)]
CONFIGS = Dict{String, NamedTuple}()
for s in 42:44, (mt, fs) in MODELS8
    for (L, sp) in BLOCK_LENGTHS
        (L == 30 || (L == 7 && mt == "base")) && continue                     # already have these
        CONFIGS["bl$(L)_$(mt)_s$s"] = (; R8..., features=fs, split_name=sp, seed=s)
    end
    for (i, (nm, _, _)) in enumerate(PATCHES)
        CONFIGS["patch$(i)_$(mt)_s$s"] = (; R8..., features=fs, split_name="patch $nm", seed=s)
    end
    # learning curve: same number of optimizer steps as the full run (≈100 epochs of the full training set)
    for f in LC_FRACTIONS[1:end-1]
        ep = round(Int, 100 / f)
        CONFIGS["lc$(f)_$(mt)_s$s"] = (; R8..., features=fs, split_name=lc_split(f), seed=s, epochs=ep,
                                         eval_every=max(1, ep ÷ 100))
    end
end
