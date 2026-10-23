# After round 31: pick the band layer for the full sky map — parallax (z500h_bandplx_kelsall_shift0) vs no parallax
# (z500h_band_kelsall_shift0, round 30), poster split. Winner = lower ecliptic (<2°) median error; ensemble test MSE breaks
# near-ties (< 3% apart). Writes "band" or "bandplx" to sweeps/results_z500_helio/R31_WINNER.txt.
ENV["ZODI_DATA"] = "z500"; ENV["ZODI_HELIO"] = "1"
using LinearAlgebra; BLAS.set_num_threads(2)
redirect_stdout(devnull) do
    include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
    for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "shift_helpers.jl"); include(joinpath(@__DIR__, f)); end
end
β = abs.(Float64.(ecliptic_latitude_deg))
res = Dict{String, NamedTuple}()
for (w, key) in (("band", "z500h_band_kelsall_shift0"), ("bandplx", "z500h_bandplx_kelsall_shift0"))
    rs = runs16(key); te = rs[1].te_idx; e = ensemble_pred(rs); rel = abs.(100 .* (e[te] .- y[te]) ./ y[te]); b = β[te]
    res[w] = (med=median(rel), p95=quantile(rel, 0.95), ecl=median(rel[b .< 2]), pole=median(rel[b .>= 60]), mse=mean(abs2, e[te] .- y[te]))
    @printf("%-8s median %.4f%%  p95 %.3f%%  |β|<2° %.4f%%  |β|≥60° %.4f%%  ens MSE %.2e\n", w, res[w]...)
    rs[1].arch === :bandplx && println("   fitted parallax params (seed mean): ",
        map(nm -> round.(mean(reduce(hcat, [getfield(band_params(r.model[1]), nm) for r in rs]), dims=2)[:], digits=3), (i=:i, Ω=:Ω, δζ=:δζ, v=:v, R=:R)))
end
a, p = res["band"], res["bandplx"]
winner = abs(p.ecl - a.ecl) / a.ecl < 0.03 ? (p.mse < a.mse ? "bandplx" : "band") : (p.ecl < a.ecl ? "bandplx" : "band")
write(joinpath(RESULTS_DIR, "R31_WINNER.txt"), winner)
println("winner: ", winner)
