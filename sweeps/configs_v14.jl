# Round 14 (2026-10-14, overnight): diagnosis of round 13. ZodiPy takes the phase-function coefficients C1–C3 from the
# nearest DIRBE band → steps in the spectrum at 1.725, 2.85, 4.2 μm, exactly where round 13's errors peak. If those
# steps are the problem, handing the network the coefficients (phC1–3) should remove most of the error.
# Same data / tests / recipe as round 13 (ENV["ZODI_DATA"] = "z115multi"); compare with m13_sunrel_*.
include(joinpath(@__DIR__, "extra_splits.jl"))
@assert ZODI_DATA == "z115multi" "configs_v14.jl needs ENV[\"ZODI_DATA\"] = \"z115multi\""
const R14 = (; arch=:mlp, hidden=(64, 64, 32, 16), batchsize=512, epochs=100, schedule=:onecycle, lr_max=1e-3)
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46, (test, sp) in [("chan", "held-out channels"), ("blk", "30 day split")]
    CONFIGS["m13_sunphase_$(test)_s$s"] = (; R14..., features=:sunseason_lambda_phase, target=:relmse, split_name=sp, seed=s)
end
