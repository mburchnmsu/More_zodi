# Round 40 report: cos×exp 2000 epochs with AdamW weight decay (λ = 1e-4, 1e-3, 1e-2; Discovery) vs no decay (round 39)
# and cos×exp 1000 (rounds 37–38), parallax band layer, shifts 0, 30, 40. Per-shift ensemble test MSE, per-seed means,
# sky-map statistics over the interpolation windows of those 3 shifts (numbers only, no figure).
#     julia --project=. sweeps/report40.jl
ENV["ZODI_DATA"] = "z500"; ENV["ZODI_HELIO"] = "1"
using LinearAlgebra; BLAS.set_num_threads(2)
redirect_stdout(devnull) do
    include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
    for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "shift_helpers.jl"); include(joinpath(@__DIR__, f)); end
    include(joinpath(@__DIR__, "configs_v24.jl"))
end
using JLD2
const FAMS = (("z500h_bandplx_cosexp1k_shift", "cos×exp 1000"), ("z500h_bandplx_cosexp2k_shift", "cos×exp 2000"),
              ("z500h_bandplx_cosexp2k_aw1e-4_shift", "  + AdamW 1e-4"), ("z500h_bandplx_cosexp2k_aw1e-3_shift", "  + AdamW 1e-3"),
              ("z500h_bandplx_cosexp2k_aw1e-2_shift", "  + AdamW 1e-2"))
done = [0, 30, 40]
@assert all(length(runs16("$(f)$Δ")) == 5 for (f, _) in FAMS, Δ in done)
β = abs.(Float64.(ecliptic_latitude_deg))
function stats(fam)
    s = zeros(N); n = zeros(Int, N); per = Dict{Int, Float64}(); seeds = Dict{Int, Vector{Float64}}()
    for Δ in done
        rs = runs16("$fam$Δ"); te = rs[1].te_idx; inn = is_interior(Δ, te); e = ensemble_pred(rs)
        per[Δ] = mean(abs2, e[te] .- y[te]); seeds[Δ] = [mean(abs2, r.ypred[te] .- y[te]) for r in rs]
        s[te[inn]] .+= e[te[inn]]; n[te[inn]] .+= 1
        empty!(_R16)                                     # free the 5 runs before loading the next shift
    end
    E = 100 .* (ifelse.(n .> 0, s ./ max.(n, 1), NaN) .- y) ./ y; ok = .!isnan.(E); a = abs.(E[ok]); b = β[ok]
    (; per, seeds, st=(med=median(a), p95=quantile(a, 0.95), ecl=median(a[b .< 2]), pole=median(a[b .>= 60])))
end
S = [stats(f) for (f, _) in FAMS]
println("\nensemble test MSE per shift (×10⁻⁸):")
@printf("%-18s %s   mean\n", "", join((@sprintf("%10s", "shift $Δ") for Δ in done), ""))
for ((_, lbl), s) in zip(FAMS, S)
    @printf("%-18s %s %7.2f\n", lbl, join((@sprintf("%10.2f", 1e8s.per[Δ]) for Δ in done), ""), 1e8mean(s.per[Δ] for Δ in done))
end
println("\nper-seed mean ± std [min–max] (×10⁻⁸):")
for ((_, lbl), s) in zip(FAMS, S)
    @printf("%-18s %s\n", lbl, join((@sprintf("  %.2f±%.2f [%.2f–%.2f]", 1e8mean(s.seeds[Δ]), 1e8std(s.seeds[Δ]),
                                             1e8minimum(s.seeds[Δ]), 1e8maximum(s.seeds[Δ])) for Δ in done), ""))
end
println("\nsky map (interpolation windows of shifts 0, 30, 40):")
for ((_, lbl), s) in zip(FAMS, S)
    @printf("%-18s median %.4f%%  p95 %.3f%%  |β|<2° %.4f%%  |β|≥60° %.4f%%\n", lbl, s.st...)
end
jldsave(joinpath(RESULTS_DIR, "r40_summary.jld2"); done, st=[s.st for s in S], per=[collect(s.per) for s in S])
println("ok")
