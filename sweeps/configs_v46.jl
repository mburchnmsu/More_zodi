# Round 46 (Nov 6): one-at-a-time ablation of the best model (parallax band layer + MLP, cos×exp 1000, rounds 37–38).
# Each variant drops one MLP input (or pair) or the band layer; shifts 0 and 30 (together every day is withheld once)
# × seeds 42–44. The full model at the same shifts/seeds is rounds 37–38 (z500h_bandplx_cosexp1k_shift{0,30}_s*).
# One job per variant (6 trainings):
#     sbatch --cpus-per-task=6 --mem=14G pipeline/cluster/threaded.sbatch sweeps/configs_v46.jl --only <the variant's 6 runs>
@assert ZODI_HELIO "configs_v46.jl is for heliocentric inputs"
@assert !NOCLOUD && INJECT_A == 0 "configs_v46.jl: the plain sky"
include(joinpath(@__DIR__, "configs_v24.jl"))
const FULL46 = FEATURE_SETS[:sunseason_learnband_plx]
const MLP46 = FULL46[1:end-6]                       # the MLP's 9 inputs; the band layer's 6 are last
const DROPS46 = ["noS" => ["n·S"], "noz" => ["n·z"], "noE" => ["n·E"], "novS" => ["n·vS"], "novE" => ["n·vE"],
                 "noxy" => ["n·x⊕", "n·y⊕"], "noseason" => ["sinλE", "cosλE"]]
for (v, drop) in DROPS46
    FEATURE_SETS[Symbol("abl46_$v")] = vcat(filter(∉(drop), MLP46), FULL46[end-5:end])
end
FEATURE_SETS[:abl46_noband] = MLP46                  # plain MLP, no band layer (arch = :mlp)
const VARIANTS46 = vcat(first.(DROPS46), "noband")
CONFIGS = Dict{String, NamedTuple}()
for v in VARIANTS46, Δ in (0, 30), s in 42:44
    CONFIGS["z500h_abl46_$(v)_cosexp1k_shift$(Δ)_s$s"] = (; R24..., epochs=1000, arch=v == "noband" ? :mlp : :bandplx,
                                                         features=Symbol("abl46_$v"), schedule=:cosexpw, lr_max=2e-3,
                                                         sched_kw=(; decay=3.0, warm=0.05), split_name=split_name24(Δ), seed=s)
end
