# Round 13 (2026-10-14, overnight follow-on): a multi-wavelength emulator, 1.25–5.0 μm (64 channels, one per exposure).
# Data: ENV["ZODI_DATA"] = "z115multi" (zodipy_gen/generate_multi.py) → results in sweeps/results_z115multi/.
#   arms : recommended inputs + logλ, linear MSE | same, squared FRACTIONAL error (:relmse — the brightness spans 27×
#          across wavelengths) | same, bigger network (128-128-64-32) | old season inputs + logλ, :relmse
#   tests: held-out channels (16 of 64 wavelengths never seen) | 30-day blocks (all wavelengths)
include(joinpath(@__DIR__, "extra_splits.jl"))
@assert ZODI_DATA == "z115multi" "configs_v13.jl needs ENV[\"ZODI_DATA\"] = \"z115multi\""
const R13 = (; arch=:mlp, hidden=(64, 64, 32, 16), batchsize=512, epochs=100, schedule=:onecycle, lr_max=1e-3)
const ARMS13 = [("sunlin", (; features=:sunseason_lambda, target=:linear)),
                ("sunrel", (; features=:sunseason_lambda, target=:relmse)),
                ("sunrelbig", (; features=:sunseason_lambda, target=:relmse, hidden=(128, 128, 64, 32))),
                ("seasonrel", (; features=:season_lambda, target=:relmse))]
const TESTS13 = [("chan", "held-out channels"), ("blk", "30 day split")]
CONFIGS = Dict{String, NamedTuple}()
for s in 42:46, (arm, kw) in ARMS13, (test, sp) in TESTS13
    CONFIGS["m13_$(arm)_$(test)_s$s"] = (; R13..., kw..., split_name=sp, seed=s)
end
