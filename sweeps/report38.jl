# Round 38 report: cos×exp at 1000 epochs (rounds 37–38) vs cos×exp 500 (rounds 35–36), one-cycle 500 and one-cycle 2000
# (round 34), parallax band layer, all 6 shifts. Per-shift ensemble test MSE, per-seed means, sky maps (interpolation windows).
#     julia --project=. sweeps/report38.jl [tag] → figures/<tag>_r38_sky.png
ENV["ZODI_DATA"] = "z500"; ENV["ZODI_HELIO"] = "1"
using LinearAlgebra; BLAS.set_num_threads(2)
redirect_stdout(devnull) do
    include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
    for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "shift_helpers.jl"); include(joinpath(@__DIR__, f)); end
    include(joinpath(@__DIR__, "configs_v24.jl"))
end
using CairoMakie, JLD2
include(joinpath(@__DIR__, "plot_sky_common.jl"))
tag = isempty(ARGS) ? "r38" : ARGS[1]
const FAMS = (("z500h_bandplx_kelsall_shift", "one-cycle, 500 epochs"), ("z500h_bandplx_cosexp_shift", "cos×exp, 500 epochs"),
              ("z500h_bandplx_cosexp1k_shift", "cos×exp, 1000 epochs"), ("z500h_bandplx2k_shift", "one-cycle, 2000 epochs"))
done = collect(SHIFTS24)
@assert all(length(runs16("$(f)$Δ")) == 5 for (f, _) in FAMS, Δ in done)
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
println("\nsky map (interpolation windows of all 6 shifts):")
for ((_, lbl), s) in zip(FAMS, S)
    @printf("%-24s median %.4f%%  p95 %.3f%%  |β|<2° %.4f%%  |β|≥60° %.4f%%\n", lbl, s.st...)
end
set_theme!(merge(Theme(fontsize=17), theme_black()))
fig = Figure(size=(3400, 1250)); hm = nothing
for (c, ((_, lbl), s)) in enumerate(zip(FAMS, S))
    ax = Axis(fig[1, c], aspect=DataAspect(), title=lbl, titlesize=21); hidedecorations!(ax); hidespines!(ax)
    xs, ys, img = moll_raster(s.G)
    global hm = heatmap!(ax, xs, ys, img, colormap=:viridis, colorrange=(0.0, 0.08), nan_color=(:grey35, 1.0),
                         highclip=Makie.to_colormap(:viridis)[end]); graticule!(ax)
    Label(fig[2, c], @sprintf("median %.4f%%  ·  p95 %.3f%%\nwithin 2° of the ecliptic %.4f%%  ·  above 60° %.4f%%", s.st...),
          fontsize=16, tellwidth=false)
end
Colorbar(fig[1, 5], hm, label="median |error| (%)", height=Relative(0.8))
for (c, (j, ttl)) in enumerate(((2, "cos×exp 1000 − cos×exp 500"), (4, "cos×exp 1000 − one-cycle 2000")))
    ax = Axis(fig[3, c + 1], aspect=DataAspect(), title=ttl, titlesize=21); hidedecorations!(ax); hidespines!(ax)
    xs, ys, img = moll_raster(S[3].G .- S[j].G)
    global hd = heatmap!(ax, xs, ys, img, colormap=Reverse(:RdBu_9), colorrange=(-0.02, 0.02), nan_color=(:grey35, 1.0)); graticule!(ax)
end
Colorbar(fig[3, 4], hd, label="Δ median |error| (%)  (blue = cos×exp 1000 better)", height=Relative(0.8), tellwidth=false, halign=:left)
Label(fig[0, 1:4], "Round 38: cos×exp at 1000 epochs, parallax band layer — all 6 shifts (grey = not covered)", font=:bold, fontsize=22)
save(joinpath(@__DIR__, "..", "figures", "$(tag)_r38_sky.png"), fig, px_per_unit=1.5)
jldsave(joinpath(RESULTS_DIR, "r38_summary.jld2"); done, st=[s.st for s in S], per=[collect(s.per) for s in S])
println("ok")
