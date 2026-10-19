# Round 22 (2026-10-18, overnight): can the model fix the ecliptic stripe (dust bands), the error that longer training
# did not touch (round 20: |β| < 2° 0.094% → 0.090%)? On the poster's 30-day split (shift 0), 300 epochs, 5 seeds,
# compared with the round-20 baseline z115_m300_shift0 (Sun frame + sin/cos λ⊕, 64-64-32-16):
#   bands    — + the 3 sharp dust-band profiles of round 9 (:sunseason_bandsharp)
#   big      — wider network 128-128-64-32 (4× the parameters)
#   bigbands — both
@assert ZODI_DATA == "z115"
const R22 = (; arch=:mlp, batchsize=512, epochs=300, schedule=:onecycle, lr_max=1e-3, split_name="30 day split",
             evals_per_epoch=10, eval_sub=50_000, keep_snaps=false)
const ARMS22 = [("bands", :sunseason_bandsharp, (64, 64, 32, 16)), ("big", :sunframe_season, (128, 128, 64, 32)),
                ("bigbands", :sunseason_bandsharp, (128, 128, 64, 32))]
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46, (tag, feats, hid) in ARMS22
    CONFIGS["z115_r22_$(tag)_s$s"] = (; R22..., features=feats, hidden=hid, seed=s)
end
