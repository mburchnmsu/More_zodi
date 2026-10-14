# Round 15 (2026-10-14, overnight): round 14's model still UNDERFITS (train ≈ test MSE on 30-day blocks; a bigger network
# did not help). Two candidate reasons, one arm each (+ both):
#   ep300  : the round-14 model trained 3× longer (300 epochs)
#   bb     : + blackbody-shape inputs log10 B_λ(250 K), log10 B_λ(300 K) relative to 5 μm (the thermal Wien tail)
#   bb300  : both
# Same data / tests / recipe otherwise (ENV["ZODI_DATA"] = "z115multi"); compare with m13_sunphase_*.
include(joinpath(@__DIR__, "extra_splits.jl"))
@assert ZODI_DATA == "z115multi" "configs_v15.jl needs ENV[\"ZODI_DATA\"] = \"z115multi\""
const R15 = (; arch=:mlp, hidden=(64, 64, 32, 16), batchsize=512, epochs=100, schedule=:onecycle, lr_max=1e-3, target=:relmse)
const ARMS15 = [("ep300", (; features=:sunseason_lambda_phase, epochs=300)),
                ("bb", (; features=:sunseason_lambda_phase_bb)),
                ("bb300", (; features=:sunseason_lambda_phase_bb, epochs=300))]
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46, (arm, kw) in ARMS15, (test, sp) in [("chan", "held-out channels"), ("blk", "30 day split")]
    test == "chan" && arm != "bb" && continue          # time budget: the 300-epoch arms only on the underfitting test (blocks)
    CONFIGS["m13_$(arm)_$(test)_s$s"] = (; R15..., kw..., split_name=sp, seed=s)
end
