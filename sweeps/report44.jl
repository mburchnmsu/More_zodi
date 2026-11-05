# Rounds 44 / 44b, the positive control for the Earth-centric inputs: a known fake Earthshine (gE, from n·δ̂) + moonlight
# (gM = exp(−θMoon/30°)) was added to the target, A·mean(y)·(gE + gM), with A = 1e-2 and 1e-3, and three models trained
# on it (shift 0, seeds 42–44): base (no Earth-centric inputs), earthc (with n·δ̂, n·M̂) and noS (base without n·S, so the
# leak n·δ̂ ≈ f(n·S, n·E, …) is cut). On the withheld interpolation windows, how much of the injected signal does each
# ensemble reproduce? Fit  pred − y_clean = cE·(A·m·gE) + cM·(A·m·gM) + c0:  cE = cM = 1 → fully learned, 0 → missed.
#     julia --project=. sweeps/report44.jl [tag]      → figures/<tag>_r44_injection.png
ENV["ZODI_DATA"] = "z500"; ENV["ZODI_HELIO"] = "1"
using LinearAlgebra; BLAS.set_num_threads(2)
redirect_stdout(devnull) do
    include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
    for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "shift_helpers.jl"); include(joinpath(@__DIR__, f)); end
end
using CairoMakie
tag = isempty(ARGS) ? "r44" : ARGS[1]
@assert !@isdefined(Y_CLEAN) "run without ZODI_INJECT: y must be the clean target"
m = mean(y); gE, gM = inject_gE(), inject_gM()
MODELS = [("base", "base (no Earth-centric inputs)"), ("earthc", "with n·δ̂, n·M̂"), ("noS", "base without n·S (leak cut)")]
AMPS = [(0.01, "0.01"), (0.001, "0.001")]

res = Dict()
@printf("%-8s %-7s %3s  %8s %8s %9s  %12s %12s  %s\n", "A", "model", "n", "cE", "cM", "c0 (%)", "rms inj (%)", "rms left (%)", "seed spread cE/cM")
for (A, As) in AMPS, (mk, _) in MODELS
    rs = runs16("z500h_inj$(As)_bandplx_$(mk)_cosexp1k_shift0"); isempty(rs) && continue
    te = rs[1].te_idx; te = te[is_interior(0, te)]
    inj = A * m .* (gE .+ gM)
    X = [A * m .* gE[te] A * m .* gM[te] ones(length(te))]
    fit(p) = X \ (p[te] .- y[te])
    c = fit(ensemble_pred(rs)); cs = [fit(r.ypred) for r in rs]
    r = ensemble_pred(rs)[te] .- y[te]
    res[(A, mk)] = (; te, r, inj=inj[te])
    @printf("%-8s %-7s %3d  %8.3f %8.3f %+9.5f  %12.5f %12.5f  ±%.3f/±%.3f\n", As, mk, length(rs), c[1], c[2], 100c[3] / m,
            100sqrt(mean(abs2, inj[te] ./ y[te])), 100sqrt(mean(abs2, (r .- inj[te]) ./ y[te])), std(getindex.(cs, 1)), std(getindex.(cs, 2)))
end

set_theme!(merge(Theme(fontsize=17), theme_black()))
fig = Figure(size=(1900, 1150))
for (i, (A, As)) in enumerate(AMPS), (j, (mk, lbl)) in enumerate(MODELS)
    haskey(res, (A, mk)) || continue
    (; r, inj) = res[(A, mk)]
    ax = Axis(fig[i, j], title="A = $As · $lbl", xlabel="injected signal (% of y)", ylabel="network − clean Kelsall (%)")
    yt = y[res[(A, mk)].te]; x, v = 100 .* inj ./ yt, 100 .* r ./ yt
    edges = range(0, quantile(x, 0.999), length=31); xc, vc, lo, hi = Float64[], Float64[], Float64[], Float64[]
    for k in 1:30
        s = (edges[k] .<= x .< edges[k+1]); sum(s) < 30 && continue
        push!(xc, (edges[k] + edges[k+1]) / 2); push!(vc, median(v[s])); push!(lo, quantile(v[s], 0.16)); push!(hi, quantile(v[s], 0.84))
    end
    band!(ax, xc, lo, hi, color=(:steelblue, 0.4)); lines!(ax, xc, vc, color=:white, linewidth=3)
    lines!(ax, [0, edges[end]], [0, edges[end]], color=:orange, linestyle=:dash, label="fully learned")
    hlines!(ax, [0], color=:grey60, linestyle=:dot)
    i == 1 && j == 1 && axislegend(ax, position=:lt)
end
Label(fig[0, 1:3], "Positive control: does the network reproduce a fake Earthshine + moonlight it was trained on? (withheld months, shift 0, 3 seeds; median and 16–84%)",
      font=:bold, fontsize=20)
save(joinpath(@__DIR__, "..", "figures", "$(tag)_r44_injection.png"), fig, px_per_unit=1.5)
println("ok")
