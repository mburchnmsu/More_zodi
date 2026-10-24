# Round 34 progress report: parallax band layer at 2000 epochs vs the same model at 500 epochs (rounds 31–32), on the
# shifts finished so far (a shift counts once all 5 seeds are done). Writes
#   figures/r34_progress_loss.png  — epoch-averaged train/test MSE of the poster split (shift 0), 2000 vs 500 epochs
#   figures/r34_progress_sky.png   — out-of-sample sky error (3.5° patches) from the finished shifts, 500 vs 2000 + difference
# and prints the statistics.   julia --project=. sweeps/report34.jl
ENV["ZODI_DATA"] = "z500"; ENV["ZODI_HELIO"] = "1"
using LinearAlgebra; BLAS.set_num_threads(2)
redirect_stdout(devnull) do
    include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
    for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "shift_helpers.jl"); include(joinpath(@__DIR__, f)); end
    include(joinpath(@__DIR__, "configs_v24.jl"))
end
using CairoMakie, JLD2
const F500, F2K = "z500h_bandplx_kelsall_shift", get(ENV, "R34_FAM", "z500h_bandplx2k_shift")   # R34_FAM: test override
done = [Δ for Δ in SHIFTS24 if length(runs16("$F2K$Δ")) == 5]
println("round 34: finished shifts ", done, " (", sum(length(runs16("$F2K$Δ")) for Δ in SHIFTS24), " of 30 runs)")
isempty(done) && exit()
β = abs.(Float64.(ecliptic_latitude_deg))
function skymap(fam)
    s = zeros(N); n = zeros(Int, N); per = Dict{Int, Float64}()
    for Δ in done
        rs = runs16("$fam$Δ"); te = rs[1].te_idx; inn = is_interior(Δ, te); e = ensemble_pred(rs)
        per[Δ] = mean(abs2, e[te] .- y[te]); s[te[inn]] .+= e[te[inn]]; n[te[inn]] .+= 1
    end
    E = 100 .* (ifelse.(n .> 0, s ./ max.(n, 1), NaN) .- y) ./ y; ok = .!isnan.(E); a = abs.(E[ok]); b = β[ok]
    (; G=footprint_stat(E, x -> median(abs.(x)); radius=1.75), per,
       st=(med=median(a), p95=quantile(a, 0.95), ecl=median(a[b .< 2]), pole=median(a[b .>= 60])))
end
A, B = skymap(F500), skymap(F2K)
for (lbl, S) in (("500 epochs ", A), ("2000 epochs", B))
    @printf("%s  median %.4f%%  p95 %.3f%%  |β|<2° %.4f%%  |β|≥60° %.4f%%  | ensemble test MSE per shift: %s\n", lbl, S.st...,
            join((@sprintf("%d: %.2e", Δ, S.per[Δ]) for Δ in done), ", "))
end
function epoch_avg(r)
    tr = zeros(r.epochs); te = zeros(r.epochs)
    for ep in 1:r.epochs
        k = findall(x -> ep - 1 < x <= ep + 1e-9, r.fine_epoch); tr[ep] = mean(r.tr_fine[k]); te[ep] = mean(r.te_fine[k])
    end
    tr, te
end
set_theme!(merge(Theme(fontsize=17), theme_black()))
fig = Figure(size=(1500, 600))
for (c, xs) in enumerate((:epoch, :frac))
    ax = Axis(fig[1, c], yscale=log10, xlabel=xs === :epoch ? "epoch" : "fraction of the training schedule",
              ylabel="MSE (MJy/sr)²", title=xs === :epoch ? "Poster split: loss vs epoch" : "Same, schedule stretched to 0–1")
    for (fam, col, lbl) in ((F500, :deepskyblue, "500 epochs"), (F2K, :orange, "2000 epochs"))
        rs = runs16("$(fam)0"); TR = reduce(hcat, first.(epoch_avg.(rs))); TE = reduce(hcat, last.(epoch_avg.(rs)))
        x = xs === :epoch ? (1:size(TR, 1)) : (1:size(TR, 1)) ./ size(TR, 1)
        lines!(ax, x, vec(mean(TR, dims=2)), color=col, linestyle=:dash, label="$lbl train")
        lines!(ax, x, vec(mean(TE, dims=2)), color=col, linewidth=2.5, label="$lbl test (withheld months)")
        c == 1 && @printf("%s: final epoch-averaged train/test MSE %.3e / %.3e\n", lbl, mean(TR[end, :]), mean(TE[end, :]))
    end
    ylims!(ax, 3e-9, 1e-5); c == 2 && axislegend(ax, position=:rt)
end
save(joinpath(@__DIR__, "..", "figures", "r34_progress_loss.png"), fig, px_per_unit=2)
include(joinpath(@__DIR__, "plot_sky_common.jl"))
fig = Figure(size=(2600, 640)); hm = nothing
for (c, (ttl, S)) in enumerate((("500 epochs (rounds 31–32)", A), ("2000 epochs (round 34)", B)))
    ax = Axis(fig[1, c], aspect=DataAspect(), title=ttl, titlesize=21); hidedecorations!(ax); hidespines!(ax)
    xs, ys, img = moll_raster(S.G)
    global hm = heatmap!(ax, xs, ys, img, colormap=:viridis, colorrange=(0.0, 0.08), nan_color=(:grey35, 1.0),
                         highclip=Makie.to_colormap(:viridis)[end]); graticule!(ax)
    Label(fig[2, c], @sprintf("median %.4f%%  ·  p95 %.3f%%\nwithin 2° of the ecliptic %.4f%%  ·  above 60° %.4f%%", S.st...),
          fontsize=16, tellwidth=false)
end
Colorbar(fig[1, 3], hm, label="median |error| (%)", height=Relative(0.8))
ax = Axis(fig[1, 4], aspect=DataAspect(), title="difference (2000 − 500 epochs)", titlesize=21); hidedecorations!(ax); hidespines!(ax)
xs, ys, img = moll_raster(B.G .- A.G)
hd = heatmap!(ax, xs, ys, img, colormap=Reverse(:RdBu_9), colorrange=(-0.02, 0.02), nan_color=(:grey35, 1.0)); graticule!(ax)
Label(fig[2, 4], "blue = 2000 epochs better", fontsize=16, tellwidth=false)
Colorbar(fig[1, 5], hd, label="Δ median |error| (%)", height=Relative(0.8))
Label(fig[0, 1:4], "Parallax band layer, 500 vs 2000 epochs — shifts finished so far: $(join(done, ", ")) (grey = not yet covered)",
      font=:bold, fontsize=22)
save(joinpath(@__DIR__, "..", "figures", "r34_progress_sky.png"), fig, px_per_unit=2)
jldsave(joinpath(RESULTS_DIR, "r34_progress.jld2"); done, A=(; A.st, per=collect(A.per)), B=(; B.st, per=collect(B.per)))
println("ok")
