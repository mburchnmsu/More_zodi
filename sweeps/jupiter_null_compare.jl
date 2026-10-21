ENV["ZODI_DATA"] = "z500"; ENV["ZODI_HELIO"] = "1"
using LinearAlgebra; BLAS.set_num_threads(2)
redirect_stdout(devnull) do
    include("C:/JuliaProjects/More_zodi/zodi_setup.jl")
    for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "shift_helpers.jl"); include("C:/JuliaProjects/More_zodi/sweeps/$f"); end
    include("C:/JuliaProjects/More_zodi/sweeps/configs_v27.jl")
end
β = abs.(Float64.(ecliptic_latitude_deg))
using Serialization
load(dir, key) = [deserialize(joinpath(dir, "$(key)_s$s.jls")) for s in 42:46]
base = replace(RESULTS_DIR, "_helio" => "")
for (dir, key, lbl) in ((base, "z500_nJ_shift0", "barycentric + n·J (round 24)"), (base, "z500_noJ_shift0", "barycentric, no n·J (round 25)"),
                        (RESULTS_DIR, "z500h_noJ_shift0", "heliocentric, no n·J (round 27)"),
                        (RESULTS_DIR, "z500h_nJ_shift0", "heliocentric + n·J (round 28, null)"))
    rs = load(dir, key); te = rs[1].te_idx; e = ensemble_pred(rs); rel = abs.(100 .* (e[te] .- y[te]) ./ y[te]); b = β[te]; d = t_rel[te]
    @printf("%-34s median %.4f%%  p95 %.3f%%  |β|<2° %.4f%%  |β|≥60° %.4f%%  ens MSE %.2e | days 0–100 %.4f%%, 400–500 %.4f%%\n", lbl,
            median(rel), quantile(rel, 0.95), median(rel[b .< 2]), median(rel[b .>= 60]), mean(abs2, e[te] .- y[te]),
            median(rel[d .< 100]), median(rel[d .>= 400]))
end
