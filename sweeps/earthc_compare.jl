# Round 33: the mentor's Earth-centric null test — poster inputs + n·δ̂ (Earth-limb direction) + n·M̂ (Moon direction) vs the
# poster inputs alone (round 27), heliocentric 500 days, poster split. On simulated (ZodiPy) data neither should help.
#   julia --project=. sweeps/earthc_compare.jl
ENV["ZODI_DATA"] = "z500"; ENV["ZODI_HELIO"] = "1"
using LinearAlgebra; BLAS.set_num_threads(2)
redirect_stdout(devnull) do
    include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
    for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "shift_helpers.jl"); include(joinpath(@__DIR__, f)); end
end
β = abs.(Float64.(ecliptic_latitude_deg))
for (w, key) in (("poster inputs (round 27)", "z500h_noJ_shift0"), ("+ n·δ̂ + n·M̂ (round 33)", "z500h_earthc_shift0"),
                 ("parallax band layer (round 31)", "z500h_bandplx_kelsall_shift0"))
    rs = runs16(key); te = rs[1].te_idx; e = ensemble_pred(rs); rel = abs.(100 .* (e[te] .- y[te]) ./ y[te]); b = β[te]
    mses = [mean(abs2, r.ypred[te] .- y[te]) for r in rs]
    @printf("%-31s median %.4f%%  p95 %.3f%%  |β|<2° %.4f%%  |β|≥60° %.4f%%  ens MSE %.2e  single-net MSE %.2e ± %.1e\n",
            w, median(rel), quantile(rel, 0.95), median(rel[b .< 2]), median(rel[b .>= 60]), mean(abs2, e[te] .- y[te]),
            mean(mses), std(mses))
end
