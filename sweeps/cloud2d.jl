# The mentor's "2-D residuals with + without the Earth cloud" in the round-43 layout (sweeps/earth2d.jl): the best model trained
# WITH Kelsall's Earth-trailing cloud (rounds 37–38) and WITHOUT it (round 45, ZODI_NOCLOUD), each judged against its own
# target, and their difference. Same withheld months (interpolation windows of all 6 shifts, 5-network ensembles), 3° cells.
#     julia --project=. sweeps/cloud2d.jl [tag]       → figures/<tag>_cloud2d_moll.png
ENV["ZODI_DATA"] = "z500"; ENV["ZODI_HELIO"] = "1"
using LinearAlgebra; BLAS.set_num_threads(2)
redirect_stdout(devnull) do
    include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
    for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "shift_helpers.jl"); include(joinpath(@__DIR__, f)); end
    include(joinpath(@__DIR__, "configs_v24.jl"))
end
using CairoMakie, HDF5, JLD2
include(joinpath(@__DIR__, "plot_sky_common.jl"))
tag = isempty(ARGS) ? "cloud2d" : ARGS[1]
@assert !@isdefined(Y_WITHCLOUD) "run without ZODI_NOCLOUD: y must be the sky with the cloud"
TF = h5open(f -> read(f["emission_earth_trailing_feature"]), emission_file)
β = Float64.(ecliptic_latitude_deg); aβ = abs.(β)

function oos_pred(fam)
    s = zeros(N); n = zeros(Int, N)
    for Δ in SHIFTS24
        rs = runs16("$fam$Δ"); @assert length(rs) == 5 "$fam$Δ: $(length(rs)) runs"
        te = rs[1].te_idx; p = ensemble_pred(rs)
        te = te[is_interior(Δ, te)]; s[te] .+= p[te]; n[te] .+= 1
        empty!(_R16); GC.gc()
    end
    ifelse.(n .> 0, s ./ max.(n, 1), NaN)
end
cache = joinpath(RESULTS_DIR, "cloud2d_P.jld2")
if isfile(cache)
    Pon, Poff = load(cache, "Pon", "Poff")
else
    Pon = oos_pred("z500h_bandplx_cosexp1k_shift"); Poff = oos_pred("z500h_nocloud_bandplx_cosexp1k_shift"); jldsave(cache; Pon, Poff)
end
ok = .!isnan.(Pon) .& .!isnan.(Poff)
Eon = ifelse.(ok, 100 .* (Pon .- y) ./ y, NaN)                  # % of the full sky
Eoff = ifelse.(ok, 100 .* (Poff .- (y .- TF)) ./ y, NaN)        # vs the sky without the cloud, still in % of the full sky
Ed = Eoff .- Eon

v = copy(v_earth_unit); v[3, :] .= 0; v ./= sqrt.(sum(abs2, v, dims=1)); nv = nvec_unit_cartesian
yv = vcat(-v[2:2, :], v[1:1, :], zeros(1, N))
φE = mod.(atand.(vec(sum(nv .* yv, dims=1)), vec(sum(nv .* v, dims=1))), 360)
λ = mod.(Float64.(ecliptic_longitude_deg), 360)
for (lbl, e) in (("cloud ON ", Eon), ("cloud OFF", Eoff), ("OFF − ON ", Ed))
    k = .!isnan.(e); a = abs.(e[k])
    bh = k .& (150 .<= φE .< 210) .& (aβ .< 15); ah = k .& ((φE .>= 330) .| (φE .< 30)) .& (aβ .< 15)
    @printf("%s: %d exposures, mean %+.5f%%, median |·| %.4f%%, p95 %.4f%%, |β|<2° %.4f%%; behind %+.5f%%, ahead %+.5f%% (|β|<15°)\n",
            lbl, sum(k), mean(e[k]), median(a), quantile(a, 0.95), median(abs.(e[k .& (aβ .< 2)])), mean(e[bh]), mean(e[ah]))
end

const W = 3.0
nφ, nb = round(Int, 360 / W), round(Int, 180 / W)
function grid(v, lon; lon0=0.0, minn=30)
    S = zeros(nφ, nb); C = zeros(Int, nφ, nb)
    for i in eachindex(v)
        isnan(v[i]) && continue
        a = clamp(floor(Int, mod(lon[i] - lon0, 360) / W) + 1, 1, nφ); b = clamp(floor(Int, (β[i] + 90) / W) + 1, 1, nb)
        S[a, b] += v[i]; C[a, b] += 1
    end
    ifelse.(C .>= minn, S ./ max.(C, 1), NaN)
end
function frame_labels!(ax, lon0, names)
    for (l, txt) in names
        d = mod(l - lon0 + 180, 360) - 180
        for dd in (abs(d) > 170 ? (-168.0, 168.0) : (d,))
            x, y0 = moll_fwd(dd, 0)
            text!(ax, x, y0 + 0.05; text=txt, color=:yellow, fontsize=19, font=:bold, align=(:center, :bottom))
        end
    end
end
set_theme!(merge(Theme(fontsize=17), theme_black()))
frames = (("Earth-motion frame (centre = behind Earth, 180°)", φE, 180.0), ("Ecliptic frame (centre = ecliptic longitude 0°)", λ, 0.0))
panels = [("with the trailing cloud (vs sky with it)", Eon), ("without the trailing cloud (vs sky without it)", Eoff), ("without − with", Ed)]
fig = Figure(size=(900 * 3 + 250, 1150)); hm = nothing
for (r, (fttl, lon, lon0)) in enumerate(frames), (c, (pttl, e)) in enumerate(panels)
    ax = Axis(fig[2r - 1, c], aspect=DataAspect(), title="$pttl\n$fttl", titlesize=18); hidedecorations!(ax); hidespines!(ax)
    xs, ys, img = moll_raster(grid(e, lon; lon0))
    global hm = heatmap!(ax, xs, ys, img, colormap=Reverse(:RdBu_9), colorrange=(-0.03, 0.03), nan_color=(:grey35, 1.0),
                         lowclip=Makie.to_colormap(Reverse(:RdBu_9))[1], highclip=Makie.to_colormap(Reverse(:RdBu_9))[end])
    graticule!(ax)
    r == 1 && frame_labels!(ax, lon0, ((0, "ahead"), (90, "Sun"), (180, "behind"), (270, "anti-Sun")))
    k = .!isnan.(e)
    Label(fig[2r, c], @sprintf("mean %+.4f%%  ·  median |residual| %.4f%%", mean(e[k]), median(abs.(e[k]))), fontsize=15, tellwidth=false)
end
Colorbar(fig[1:3, 4], hm, label="mean residual, network − its target (% of sky)", height=Relative(0.7))
Label(fig[0, 1:3], "2-D residuals with vs without Kelsall's Earth-trailing cloud (withheld months, 6 splits × 5 seeds), 3° cells; grey = not covered",
      font=:bold, fontsize=21)
save(joinpath(@__DIR__, "..", "figures", "$(tag)_cloud2d_moll.png"), fig, px_per_unit=1.5)
println("ok")
