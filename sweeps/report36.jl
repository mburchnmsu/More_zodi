# Rounds 35–36 report: cos×exp learning-rate schedule (peak 2e-3, with warm-up) vs one-cycle (peak 1e-3) at 500 epochs,
# and one-cycle at 2000 epochs (round 34), parallax band layer, on every shift where cos×exp has finished (all 5 seeds).
# Per-shift ensemble test MSE, per-seed means, out-of-sample sky maps (interpolation windows) and their statistics.
#     julia --project=. sweeps/report36.jl → figures/r36_sky.png
ENV["ZODI_DATA"] = "z500"; ENV["ZODI_HELIO"] = "1"
using LinearAlgebra; BLAS.set_num_threads(2)
redirect_stdout(devnull) do
    include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
    for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "shift_helpers.jl"); include(joinpath(@__DIR__, f)); end
    include(joinpath(@__DIR__, "configs_v24.jl"))
end
using CairoMakie, JLD2
include(joinpath(@__DIR__, "plot_sky_common.jl"))
const FAMS = (("z500h_bandplx_kelsall_shift", "one-cycle, 500 epochs"), ("z500h_bandplx_cosexp_shift", "cos×exp, 500 epochs"),
              ("z500h_bandplx2k_shift", "one-cycle, 2000 epochs"))
done = [Δ for Δ in SHIFTS24 if length(runs16("z500h_bandplx_cosexp_shift$Δ")) == 5]
println("cos×exp finished shifts: ", done)
β = abs.(Float64.(ecliptic_latitude_deg))
function skymap(fam)
    s = zeros(N); n = zeros(Int, N); per = Dict{Int, Float64}(); seeds = Dict{Int, Vector{Float64}}()
    for Δ in done
        rs = runs16("$fam$Δ"); te = rs[1].te_idx; inn = is_interior(Δ, te); e = ensemble_pred(rs)
        per[Δ] = mean(abs2, e[te] .- y[te]); seeds[Δ] = [mean(abs2, r.ypred[te] .- y[te]) for r in rs]
        s[te[inn]] .+= e[te[inn]]; n[te[inn]] .+= 1
    end
    E = 100 .* (ifelse.(n .> 0, s ./ max.(n, 1), NaN) .- y) ./ y; ok = .!isnan.(E); a = abs.(E[ok]); b = β[ok]
    (; G=footprint_stat(E, x -> median(abs.(x)); radius=1.75), per, seeds,
       st=(med=median(a), p95=quantile(a, 0.95), ecl=median(a[b .< 2]), pole=median(a[b .>= 60])))
end
S = [skymap(f) for (f, _) in FAMS]
println("\nensemble test MSE per shift (×10⁻⁸):")
@printf("%-24s %s\n", "", join((@sprintf("%10s", "shift $Δ") for Δ in done), ""))
for ((_, lbl), s) in zip(FAMS, S)
    @printf("%-24s %s\n", lbl, join((@sprintf("%10.2f", 1e8s.per[Δ]) for Δ in done), ""))
end
println("\nper-seed mean ± std (×10⁻⁸):")
for ((_, lbl), s) in zip(FAMS, S)
    @printf("%-24s %s\n", lbl, join((@sprintf("  %.2f±%.2f", 1e8mean(s.seeds[Δ]), 1e8std(s.seeds[Δ])) for Δ in done), ""))
end
println("\nsky map (interpolation windows of the finished shifts):")
for ((_, lbl), s) in zip(FAMS, S)
    @printf("%-24s median %.4f%%  p95 %.3f%%  |β|<2° %.4f%%  |β|≥60° %.4f%%\n", lbl, s.st...)
end
set_theme!(merge(Theme(fontsize=17), theme_black()))
fig = Figure(size=(2700, 1250)); hm = nothing
for (c, ((_, lbl), s)) in enumerate(zip(FAMS, S))
    ax = Axis(fig[1, c], aspect=DataAspect(), title=lbl, titlesize=21); hidedecorations!(ax); hidespines!(ax)
    xs, ys, img = moll_raster(s.G)
    global hm = heatmap!(ax, xs, ys, img, colormap=:viridis, colorrange=(0.0, 0.08), nan_color=(:grey35, 1.0),
                         highclip=Makie.to_colormap(:viridis)[end]); graticule!(ax)
    Label(fig[2, c], @sprintf("median %.4f%%  ·  p95 %.3f%%\nwithin 2° of the ecliptic %.4f%%  ·  above 60° %.4f%%", s.st...),
          fontsize=16, tellwidth=false)
end
Colorbar(fig[1, 4], hm, label="median |error| (%)", height=Relative(0.8))
for (c, (j, ttl)) in enumerate(((1, "cos×exp − one-cycle (both 500 epochs)"), (3, "cos×exp 500 − one-cycle 2000 epochs")))
    ax = Axis(fig[3, c], aspect=DataAspect(), title=ttl, titlesize=21); hidedecorations!(ax); hidespines!(ax)
    xs, ys, img = moll_raster(S[2].G .- S[j].G)
    global hd = heatmap!(ax, xs, ys, img, colormap=Reverse(:RdBu_9), colorrange=(-0.02, 0.02), nan_color=(:grey35, 1.0)); graticule!(ax)
end
Colorbar(fig[3, 3], hd, label="Δ median |error| (%)  (blue = cos×exp better)", height=Relative(0.8), tellwidth=false, halign=:left)
Label(fig[0, 1:3], "Learning-rate schedules, parallax band layer — shifts $(join(done, ", ")) (grey = not covered)", font=:bold, fontsize=22)
save(joinpath(@__DIR__, "..", "figures", "r36_sky.png"), fig, px_per_unit=2)
jldsave(joinpath(RESULTS_DIR, "r36_summary.jld2"); done, st=[s.st for s in S], per=[collect(s.per) for s in S])
println("ok")
