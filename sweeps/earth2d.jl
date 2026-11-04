# The mentor's request (Nov 3): the 2-D residual map (sweeps/mentor1028.jl §B) redone as Mollweide maps, comparing the
# best model WITHOUT the Earth-centric inputs (cos×exp 1000, rounds 37–38) and WITH them (n·δ̂, n·M̂; round 43).
# Mean residual (network − Kelsall, %) on the interpolation windows of all 6 shifts, 5-network ensembles, in two frames:
#   Earth-motion frame: longitude from Earth's direction of motion (0 = ahead, 90 = Sun, 180 = behind), centred on 180°
#                       (where Kelsall's trailing cloud sits); ecliptic latitude up
#   ecliptic frame:     ecliptic longitude / latitude, centred on 0°, as in our other sky maps
#     julia --project=. sweeps/earth2d.jl [tag]            → figures/<tag>_earth2d_moll.png
#     EARTH2D_ONLY_WITHOUT=1 julia ... (preview before round 43 exists: the without-Earth model only)
#     EARTH2D_PLOT_ONLY=1 julia ...    (redraw from the maps cached by the last full run; no statistics)
ENV["ZODI_DATA"] = "z500"; ENV["ZODI_HELIO"] = "1"
using LinearAlgebra; BLAS.set_num_threads(2)
redirect_stdout(devnull) do
    include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
    for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "shift_helpers.jl"); include(joinpath(@__DIR__, f)); end
    include(joinpath(@__DIR__, "configs_v24.jl"))
end
using CairoMakie, HDF5, JLD2
include(joinpath(@__DIR__, "plot_sky_common.jl"))
tag = isempty(ARGS) ? "earth2d" : ARGS[1]
only_without = get(ENV, "EARTH2D_ONLY_WITHOUT", "0") == "1"
FAMS = [("z500h_bandplx_cosexp1k_shift", "without Earth-centric inputs"),
        ("z500h_bandplx_earthc_cosexp1k_shift", "with Earth-centric inputs (n·δ̂, n·M̂)")][only_without ? (1:1) : (1:2)]
β = Float64.(ecliptic_latitude_deg); aβ = abs.(β)

"""Out-of-sample % error on the interpolation windows of all 6 shifts (5-network ensemble, or one seed)."""
const PER = Dict{String, Vector{Float64}}()                   # ensemble test MSE per shift (all withheld windows)
function oos(fam; seed=nothing)
    s = zeros(N); n = zeros(Int, N)
    seed === nothing && (PER[fam] = Float64[])
    for Δ in SHIFTS24
        rs = runs16("$fam$Δ"); @assert length(rs) == 5 "$fam$Δ: $(length(rs)) runs"
        te = rs[1].te_idx
        p = seed === nothing ? ensemble_pred(rs) : rs[seed].ypred
        seed === nothing && push!(PER[fam], mean(abs2, p[te] .- y[te]))
        te = te[is_interior(Δ, te)]
        s[te] .+= p[te]; n[te] .+= 1
        empty!(_R16)
    end
    100 .* (ifelse.(n .> 0, s ./ max.(n, 1), NaN) .- y) ./ y
end

# Earth-motion frame (as mentor1028.jl): x̂ = Earth's velocity in the ecliptic plane, ẑ = ecliptic north, ŷ = ẑ × x̂
v = copy(v_earth_unit); v[3, :] .= 0; v ./= sqrt.(sum(abs2, v, dims=1))
nv = nvec_unit_cartesian
yv = vcat(-v[2:2, :], v[1:1, :], zeros(1, N))
φE = mod.(atand.(vec(sum(nv .* yv, dims=1)), vec(sum(nv .* v, dims=1))), 360)
λ = mod.(Float64.(ecliptic_longitude_deg), 360)
TF = h5open(f -> read(f["emission_earth_trailing_feature"]), emission_file); share = 100 .* TF ./ y

const W = 3.0
nφ, nb = round(Int, 360 / W), round(Int, 180 / W)
"""Per-cell mean of v over (lon, lat) cells of W degrees; lon0 = the longitude put at the map centre. < minn exposures → NaN."""
function grid(v, lon; lon0=0.0, minn=30)
    S = zeros(nφ, nb); C = zeros(Int, nφ, nb)
    for i in eachindex(v)
        isnan(v[i]) && continue
        a = clamp(floor(Int, mod(lon[i] - lon0, 360) / W) + 1, 1, nφ); b = clamp(floor(Int, (β[i] + 90) / W) + 1, 1, nb)
        S[a, b] += v[i]; C[a, b] += 1
    end
    ifelse.(C .>= minn, S ./ max.(C, 1), NaN)
end
fitA(E, k) = (i = findall(k .& .!isnan.(E)); ([share[i] ones(length(i))] \ E[i])[1])

# EARTH2D_PLOT_ONLY=1: reuse the residual maps cached by the last full run (figure tweaks only, no statistics)
cache = joinpath(RESULTS_DIR, "earth2d_E$(length(FAMS)).jld2")
plot_only = get(ENV, "EARTH2D_PLOT_ONLY", "0") == "1"
E = plot_only ? load(cache, "E") : [oos(f) for (f, _) in FAMS]
plot_only || jldsave(cache; E)
for ((f, lbl), e) in zip(FAMS, plot_only ? () : E)
    ok = .!isnan.(e); a = abs.(e[ok])
    @printf("\n%s: %d exposures, median |error| %.4f%%, p95 %.3f%%, |β|<2° %.4f%%, mean residual %+.5f%%\n", lbl, sum(ok),
            median(a), quantile(a, 0.95), median(abs.(e[ok .& (aβ .< 2)])), mean(e[ok]))
    @printf("  ensemble test MSE ×10⁻⁸, shifts %s: %s (mean %.2f)\n", join(SHIFTS24, "/"),
            join((@sprintf("%.2f", 1e8x) for x in PER[f]), " "), 1e8mean(PER[f]))
    for (kl, k) in (("|β| < 15°", aβ .< 15), ("whole sky", trues(N)))
        as = [fitA(oos(f; seed=s), k) for s in 1:5]
        @printf("  missing fraction of the trailing cloud (%s): %+.4f  (seed spread ± %.4f)\n", kl, fitA(e, k), std(as))
    end
    for (pl, k) in (("behind (φ 150–210°, |β|<15°)", (150 .<= φE .< 210) .& (aβ .< 15)),
                    ("ahead (φ 330–30°, |β|<15°)", ((φE .>= 330) .| (φE .< 30)) .& (aβ .< 15)))
        kk = k .& ok
        @printf("  %-30s mean residual %+.5f%% ± %.5f%%  median |error| %.4f%%\n", pl, mean(e[kk]), std(e[kk]) / sqrt(sum(kk)),
                median(abs.(e[kk])))
    end
end
if length(E) == 2
    ok = .!isnan.(E[1]) .& .!isnan.(E[2]); d = E[2][ok] .- E[1][ok]
    @printf("\nwith − without: mean %+.5f%%, rms %.5f%%, median |error| %.4f%% → %.4f%%\n", mean(d), sqrt(mean(abs2, d)),
            median(abs.(E[1][ok])), median(abs.(E[2][ok])))
end

# ------------------------------------------------------------------------------------------------------------- figure
# moll_raster puts the grid's longitude 0 at the centre, increasing to the left; the grids are built with lon0 at 0.
set_theme!(merge(Theme(fontsize=17), theme_black()))
frames = (("Earth-motion frame (centre = behind Earth, 180°)", φE, 180.0), ("Ecliptic frame (centre = ecliptic longitude 0°)", λ, 0.0))
panels = [(lbl, e) for ((_, lbl), e) in zip(FAMS, E)]
length(E) == 2 && push!(panels, ("with − without", E[2] .- E[1]))
fig = Figure(size=(900 * length(panels) + 250, 1150)); hm = nothing
function frame_labels!(ax, lon0, names)
    for (l, txt) in names                                       # a label at the map edge is drawn on both edges, inset
        d = mod(l - lon0 + 180, 360) - 180
        for dd in (abs(d) > 170 ? (-168.0, 168.0) : (d,))
            x, y0 = moll_fwd(dd, 0)
            text!(ax, x, y0 + 0.05; text=txt, color=:yellow, fontsize=19, font=:bold, align=(:center, :bottom))
        end
    end
end
for (r, (fttl, lon, lon0)) in enumerate(frames), (c, (pttl, e)) in enumerate(panels)
    ax = Axis(fig[2r - 1, c], aspect=DataAspect(), title="$pttl\n$fttl", titlesize=18); hidedecorations!(ax); hidespines!(ax)
    xs, ys, img = moll_raster(grid(e, lon; lon0))
    global hm = heatmap!(ax, xs, ys, img, colormap=Reverse(:RdBu_9), colorrange=(-0.03, 0.03), nan_color=(:grey35, 1.0),
                         lowclip=Makie.to_colormap(Reverse(:RdBu_9))[1], highclip=Makie.to_colormap(Reverse(:RdBu_9))[end])
    graticule!(ax)
    r == 1 && frame_labels!(ax, lon0, ((0, "ahead"), (90, "Sun"), (180, "behind"), (270, "anti-Sun")))
    ok = .!isnan.(e)
    Label(fig[2r, c], @sprintf("mean %+.4f%%  ·  median |residual| %.4f%%", mean(e[ok]), median(abs.(e[ok]))), fontsize=15, tellwidth=false)
end
Colorbar(fig[1:3, length(panels) + 1], hm, label="mean residual, network − Kelsall (%)", height=Relative(0.7))
Label(fig[0, 1:length(panels)], "2-D residuals on withheld months (interpolation windows, 6 splits × 5 seeds), 3° cells; grey = not covered",
      font=:bold, fontsize=21)
save(joinpath(@__DIR__, "..", "figures", "$(tag)_earth2d_moll.png"), fig, px_per_unit=1.5)
println("ok")
