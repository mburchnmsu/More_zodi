# Round 24 (500-day data, poster model + n·J, 500 epochs): out-of-sample sky-error grids, statistics and epoch-averaged
# loss curves → sweeps/results_z500/r24_summary.jld2 (plotted with the 140-day results by sweeps/plot_r24.jl).
# Uses whichever of the 30 runs have finished (a shift counts once all 5 seeds are done).
#   julia --project=. sweeps/r24_data.jl
ENV["ZODI_DATA"] = "z500"
get!(ENV, "ZODI_HELIO", "0")          # round 24 was barycentric; set ZODI_HELIO=1 + R24_FAM for the heliocentric runs
using LinearAlgebra; BLAS.set_num_threads(2)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "shift_helpers.jl")
    include(joinpath(@__DIR__, f))
end
include(joinpath(@__DIR__, "configs_v24.jl"))
using JLD2
const FAM24 = get(ENV, "R24_FAM", "z500_nJ_shift")      # e.g. "z500h_noJ_shift" with ENV["ZODI_HELIO"] = "1" (round 27/28)
fam(Δ) = "$(FAM24)$Δ"
done = [Δ for Δ in SHIFTS24 if length(runs16(fam(Δ))) == 5]
println("complete shifts: ", done)
# out-of-sample prediction from the between-month windows, averaged over the versions that held each exposure out
s = zeros(N); n = zeros(Int, N); per_shift = Dict{Int, Any}()
for Δ in done
    rs = runs16(fam(Δ)); te = rs[1].te_idx; inn = is_interior(Δ, te)
    e = ensemble_pred(rs); rel = 100 .* (e[te] .- y[te]) ./ y[te]
    per_shift[Δ] = (between=median(abs.(rel[inn])), ends=any(.!inn) ? median(abs.(rel[.!inn])) : NaN,
                    ens_mse=mean(abs2, e[te] .- y[te]))
    s[te[inn]] .+= e[te[inn]]; n[te[inn]] .+= 1
end
E = 100 .* (ifelse.(n .> 0, s ./ max.(n, 1), NaN) .- y) ./ y; ok = .!isnan.(E)
a = abs.(E[ok]); b = abs.(Float64.(ecliptic_latitude_deg[ok]))
stats = (n=sum(ok), frac=mean(ok), med=median(a), p95=quantile(a, 0.95), ecl=median(a[b .< 2]), pole=median(a[b .>= 60]))
G = footprint_stat(E, x -> median(abs.(x)); radius=1.75); G7 = footprint_stat(E, x -> median(abs.(x)); radius=3.5)
# epoch-averaged loss curves of the poster split (shift 0)
function epoch_avg(r)
    tr = zeros(r.epochs); te = zeros(r.epochs)
    for ep in 1:r.epochs
        k = findall(x -> ep - 1 < x <= ep + 1e-9, r.fine_epoch); tr[ep] = mean(r.tr_fine[k]); te[ep] = mean(r.te_fine[k])
    end
    tr, te
end
r0 = runs16(fam(0))
TR = reduce(hcat, [epoch_avg(r)[1] for r in r0]); TE = reduce(hcat, [epoch_avg(r)[2] for r in r0])
spe = cld(length(r0[1].tr_idx), 512)                         # updates per epoch
jldsave(joinpath(RESULTS_DIR, get(ENV, "R24_OUT", "r24_summary.jld2")); G, G7, stats, done, per_shift=collect(per_shift), TR, TE, spe,
        ntrain=length(r0[1].tr_idx), span=span_days, N)
@printf("sky map: %d exposures (%.1f%%), median %.4f%%, p95 %.3f%%, |β|<2° %.4f%%, |β|≥60° %.4f%%\n", stats.n, 100stats.frac,
        stats.med, stats.p95, stats.ecl, stats.pole)
for Δ in done
    p = per_shift[Δ]; @printf("shift %2d: between-month median %.4f%%, ends %.4f%%, ensemble test MSE %.2e\n", Δ, p.between, p.ends, p.ens_mse)
end
@printf("shift 0 final epoch-averaged train/test MSE %.2e / %.2e; %d updates per epoch\n", mean(TR[end, :]), mean(TE[end, :]), spe)
