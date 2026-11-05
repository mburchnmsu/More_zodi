# Round 45, the mentor's "with + without the Earth-trailing cloud" (Week 13): the best model (parallax band layer, cos×exp
# 1000, 6 shifts × 5 seeds) trained on the sky WITH Kelsall's Earth-trailing cloud (rounds 37–38) and WITHOUT it
# (ZODI_NOCLOUD: y − cloud, sweeps/configs_v45.jl). Each family is judged against its own target. The difference of the two
# networks' predictions should be the cloud itself: (ensemble on − ensemble off) vs Kelsall's cloud.
# Mollweide maps of the out-of-sample residual (interpolation windows, all 6 shifts) in the Earth-motion and ecliptic frames.
#     julia --project=. sweeps/report45.jl [tag]       → figures/<tag>_r45_cloud_onoff.png
ENV["ZODI_DATA"] = "z500"; ENV["ZODI_HELIO"] = "1"
using LinearAlgebra; BLAS.set_num_threads(2)
redirect_stdout(devnull) do
    include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
    for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "shift_helpers.jl"); include(joinpath(@__DIR__, f)); end
    include(joinpath(@__DIR__, "configs_v24.jl"))
end
using CairoMakie, HDF5
include(joinpath(@__DIR__, "plot_sky_common.jl"))
tag = isempty(ARGS) ? "r45" : ARGS[1]
@assert !@isdefined(Y_WITHCLOUD) "run without ZODI_NOCLOUD: y must be the sky with the cloud"
TF = h5open(f -> read(f["emission_earth_trailing_feature"]), emission_file)
β = Float64.(ecliptic_latitude_deg); aβ = abs.(β)

"""Ensemble prediction on the interpolation windows of all 6 shifts (NaN elsewhere), and the per-shift ensemble test MSE
against `target`."""
function oos_pred(fam, target)
    s = zeros(N); n = zeros(Int, N); per = Float64[]
    for Δ in SHIFTS24
        rs = runs16("$fam$Δ"); @assert length(rs) == 5 "$fam$Δ: $(length(rs)) runs"
        te = rs[1].te_idx; p = ensemble_pred(rs)
        push!(per, mean(abs2, p[te] .- target[te]))
        te = te[is_interior(Δ, te)]; s[te] .+= p[te]; n[te] .+= 1
        empty!(_R16); GC.gc()
    end
    ifelse.(n .> 0, s ./ max.(n, 1), NaN), per
end
Pon, per_on = oos_pred("z500h_bandplx_cosexp1k_shift", y)
Poff, per_off = oos_pred("z500h_nocloud_bandplx_cosexp1k_shift", y .- TF)
Eon = 100 .* (Pon .- y) ./ y                         # % of the full sky
Eoff = 100 .* (Poff .- (y .- TF)) ./ y
D = 100 .* (Pon .- Poff) ./ y                        # what the networks say the cloud is
C = 100 .* TF ./ y                                   # what Kelsall says it is
ok = .!isnan.(Pon) .& .!isnan.(Poff)

for (lbl, per, e) in (("cloud ON  (rounds 37–38)", per_on, Eon), ("cloud OFF (round 45)", per_off, Eoff))
    a = abs.(e[ok])
    @printf("%s: ensemble test MSE ×10⁻⁸ per shift %s (mean %.2f); median |error| %.4f%%, p95 %.3f%%, |β|<2° %.4f%%\n", lbl,
            join((@sprintf("%.2f", 1e8x) for x in per), " "), 1e8mean(per), median(a), quantile(a, 0.95), median(abs.(e[ok .& (aβ .< 2)])))
end
for (kl, k) in (("|β| < 15°", ok .& (aβ .< 15)), ("whole sky", ok))
    slope = [C[k] ones(sum(k))] \ D[k]
    @printf("on − off vs Kelsall's cloud (%s): slope %.4f, intercept %+.5f%%, rms(on − off − cloud) %.5f%% (cloud rms %.4f%%)\n",
            kl, slope[1], slope[2], sqrt(mean(abs2, D[k] .- C[k])), sqrt(mean(abs2, C[k])))
end

# Earth-motion frame (as earth2d.jl): x̂ = Earth's velocity in the ecliptic plane, ẑ = ecliptic north
v = copy(v_earth_unit); v[3, :] .= 0; v ./= sqrt.(sum(abs2, v, dims=1)); nv = nvec_unit_cartesian
yv = vcat(-v[2:2, :], v[1:1, :], zeros(1, N))
φE = mod.(atand.(vec(sum(nv .* yv, dims=1)), vec(sum(nv .* v, dims=1))), 360)
λ = mod.(Float64.(ecliptic_longitude_deg), 360)
const W = 3.0
nφ, nb = round(Int, 360 / W), round(Int, 180 / W)
function grid(v, lon; lon0=0.0, minn=30)
    S = zeros(nφ, nb); Cn = zeros(Int, nφ, nb)
    for i in eachindex(v)
        isnan(v[i]) && continue
        a = clamp(floor(Int, mod(lon[i] - lon0, 360) / W) + 1, 1, nφ); b = clamp(floor(Int, (β[i] + 90) / W) + 1, 1, nb)
        S[a, b] += v[i]; Cn[a, b] += 1
    end
    ifelse.(Cn .>= minn, S ./ max.(Cn, 1), NaN)
end

set_theme!(merge(Theme(fontsize=17), theme_black()))
nanif(x) = ifelse.(ok, x, NaN)
panels = [("residual, cloud ON (vs sky with cloud)", nanif(Eon), 0.03), ("residual, cloud OFF (vs sky without cloud)", nanif(Eoff), 0.03),
          ("Kelsall's trailing cloud (% of sky)", nanif(C), 4.0), ("networks: ON − OFF (% of sky)", nanif(D), 4.0),
          ("(ON − OFF) − Kelsall's cloud", nanif(D .- C), 0.03)]
frames = (("Earth-motion frame (centre = behind Earth)", φE, 180.0), ("ecliptic frame", λ, 0.0))
fig = Figure(size=(820 * length(panels), 1150))
for (r, (fttl, lon, lon0)) in enumerate(frames), (c, (pttl, e, lim)) in enumerate(panels)
    ax = Axis(fig[2r - 1, c], aspect=DataAspect(), title="$pttl\n$fttl", titlesize=17); hidedecorations!(ax); hidespines!(ax)
    xs, ys, img = moll_raster(grid(e, lon; lon0))
    cmap = lim > 1 ? :magma : Reverse(:RdBu_9); cr = lim > 1 ? (0.0, lim) : (-lim, lim)
    hm = heatmap!(ax, xs, ys, img, colormap=cmap, colorrange=cr, nan_color=(:grey35, 1.0),
                  lowclip=Makie.to_colormap(cmap)[1], highclip=Makie.to_colormap(cmap)[end])
    graticule!(ax)
    r == 2 && Colorbar(fig[5, c], hm, vertical=false, width=Relative(0.7), label="%")
    k = .!isnan.(e); Label(fig[2r, c], @sprintf("mean %+.4f%%  ·  median |value| %.4f%%", mean(e[k]), median(abs.(e[k]))), fontsize=15, tellwidth=false)
end
Label(fig[0, 1:length(panels)], "Round 45: the best model trained with and without Kelsall's Earth-trailing cloud (withheld months, 6 shifts × 5 seeds, 3° cells)",
      font=:bold, fontsize=21)
save(joinpath(@__DIR__, "..", "figures", "$(tag)_r45_cloud_onoff.png"), fig, px_per_unit=1.2)
println("ok")
