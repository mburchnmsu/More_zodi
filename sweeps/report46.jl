# Round 46: one-at-a-time ablation of the best model (sweeps/configs_v46.jl). For the full model (rounds 37–38) and each
# variant: 3-seed ensemble (42–44) test MSE on shifts 0 and 30, and the sky-map errors on the interpolation windows of
# both shifts (median, p95, |β| < 2°, |β| > 60°).
#     julia --project=. sweeps/report46.jl [tag]      → figures/<tag>_r46_ablation.png, RESULTS_DIR/r46_summary.csv
ENV["ZODI_DATA"] = "z500"; ENV["ZODI_HELIO"] = "1"
using LinearAlgebra; BLAS.set_num_threads(2)
redirect_stdout(devnull) do
    include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
    for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "shift_helpers.jl"); include(joinpath(@__DIR__, f)); end
    include(joinpath(@__DIR__, "configs_v46.jl"))
end
using CairoMakie
tag = isempty(ARGS) ? "r46" : ARGS[1]
aβ = abs.(Float64.(ecliptic_latitude_deg))
VAR = [("full", "full model", "z500h_bandplx_cosexp1k_shift"),
       [(v, "− " * Dict("noS" => "n·S", "noz" => "n·z", "noE" => "n·E", "novS" => "n·vS", "novE" => "n·vE",
                         "noxy" => "n·x⊕, n·y⊕", "noseason" => "sin/cos λ⊕", "noband" => "band layer")[v],
         "z500h_abl46_$(v)_cosexp1k_shift") for v in VARIANTS46]...]
rows = []
for (v, lbl, fam) in VAR
    s = zeros(N); n = zeros(Int, N); mse = Float64[]; seedmse = Float64[]
    for Δ in (0, 30)
        rs = [deserialize(joinpath(RESULTS_DIR, "$fam$(Δ)_s$sd.jls")) for sd in 42:44]
        te = rs[1].te_idx; p = ensemble_pred(rs)
        push!(mse, mean(abs2, p[te] .- y[te])); append!(seedmse, [mean(abs2, r.ypred[te] .- y[te]) for r in rs])
        te = te[is_interior(Δ, te)]; s[te] .+= p[te]; n[te] .+= 1
        rs = nothing; GC.gc()
    end
    k = n .> 0; e = abs.(100 .* (s[k] ./ n[k] .- y[k]) ./ y[k]); b = aβ[k]
    push!(rows, (; v, lbl, mse0=mse[1], mse30=mse[2], mse=mean(mse), seed_se=std(seedmse) / sqrt(length(seedmse)),
                 med=median(e), p95=quantile(e, 0.95), ecl=median(e[b .< 2]), hi=median(e[b .> 60])))
end
f0 = rows[1]
@printf("%-14s %8s %8s %8s %7s  %8s %7s %8s %8s\n", "variant", "MSE s0", "MSE s30", "mean", "×full", "median", "p95", "|β|<2°", "|β|>60°")
for r in rows
    @printf("%-14s %8.2f %8.2f %8.2f %7.2f  %7.4f%% %6.3f%% %7.4f%% %7.4f%%\n", r.lbl, 1e8r.mse0, 1e8r.mse30, 1e8r.mse,
            r.mse / f0.mse, r.med, r.p95, r.ecl, r.hi)
end
open(joinpath(RESULTS_DIR, "r46_summary.csv"), "w") do io
    println(io, "variant,mse_shift0,mse_shift30,mse_mean,ratio_to_full,median_pct,p95_pct,ecliptic_pct,highlat_pct")
    for r in rows; println(io, join((r.v, r.mse0, r.mse30, r.mse, r.mse / f0.mse, r.med, r.p95, r.ecl, r.hi), ",")); end
end

include(joinpath(@__DIR__, "plot46.jl"))      # the figure, from r46_summary.csv (redraw alone: julia sweeps/plot46.jl tag)
plot46(tag)
println("ok")
