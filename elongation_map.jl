# ==============================================================================
# SOLAR ELONGATION SKY COVERAGE — Mollweide maps in ecliptic coordinates
# Run the ZODI SETUP cell first, then `include("elongation_map.jl")`.
#
# Every exposure is binned into a HEALPix pixel (by boresight direction) and we map
#   1. how many exposures landed in each pixel,
#   2. the mean solar elongation they were taken at,
#   3. the spread (max − min) of elongations seen in each pixel.
# Grey = never observed. Small spread = that patch of sky was only ever seen at
# one Sun angle, so the model has little information about how zodi changes there.
# ==============================================================================
using Healpix

# Pixel size: these are boresight points only, and neighbouring scan lines are more
# than 1° apart, so finer pixels show false "gaps" between scans. nside 16 (3.7°)
# is about one SPHEREx exposure footprint (~3.5°). Sky observed: 82% at nside 16,
# 64% at 32, 32% at 64.
ELONG_NSIDE = 16          # 3,072 pixels, ~3.7° across

# --- Solar elongation of every exposure --------------------------------------
# Positions are barycentric; we take the Sun ≈ barycenter, so the Sun direction
# from SPHEREx is −Ŝ. (Sun–barycenter offset ≲ 0.01 AU → ≲ 0.6° error.)
S_unit          = spherex_positions ./ sqrt.(sum(spherex_positions .^ 2, dims=1))
solar_elong_deg = acosd.(clamp.(-dot_prod_matrix(nvec_unit_cartesian, S_unit), -1.0, 1.0))
@printf("Solar elongation over all exposures: %.1f° – %.1f° (median %.1f°)\n",
        extrema(solar_elong_deg)..., median(solar_elong_deg))

# --- Bin exposures into HEALPix pixels (ecliptic frame) ----------------------
elong_res = Healpix.Resolution(ELONG_NSIDE)
npix      = Healpix.nside2npix(ELONG_NSIDE)
pix_count = zeros(Int, npix)
pix_sum   = zeros(npix)
pix_min   = fill(Inf, npix)
pix_max   = fill(-Inf, npix)
for i in 1:N
    nx, ny, nz = nvec_unit_cartesian[1, i], nvec_unit_cartesian[2, i], nvec_unit_cartesian[3, i]
    p = Healpix.ang2pixRing(elong_res, acos(clamp(nz, -1.0, 1.0)), mod(atan(ny, nx), 2π))
    e = solar_elong_deg[i]
    pix_count[p] += 1
    pix_sum[p]   += e
    pix_min[p]    = min(pix_min[p], e)
    pix_max[p]    = max(pix_max[p], e)
end
seen       = pix_count .> 0
pix_mean   = ifelse.(seen, pix_sum ./ max.(pix_count, 1), NaN)
pix_spread = ifelse.(seen, pix_max .- pix_min, NaN)
pix_logn   = ifelse.(seen, log10.(max.(pix_count, 1)), NaN)
@printf("Sky observed at least once: %.1f%% of %d pixels\n", 100mean(seen), npix)
@printf("Pixels seen at < 5° elongation spread: %.1f%% of observed sky\n",
        100mean(pix_spread[seen] .< 5))

# --- Mollweide projection ----------------------------------------------------
# Ecliptic longitude 0° at the centre, increasing to the LEFT (sky-view convention).
function mollweide(lon_deg, lat_deg)
    λ = deg2rad(mod(lon_deg + 180, 360) - 180)
    φ = deg2rad(lat_deg)
    θ = φ
    if abs(φ) < π/2 - 1e-9            # Newton solve of 2θ + sin 2θ = π sin φ
        for _ in 1:50
            Δ = (2θ + sin(2θ) - π * sin(φ)) / (2 + 2cos(2θ))
            θ -= Δ
            abs(Δ) < 1e-12 && break
        end
    end
    return (-2√2 / π * λ * cos(θ), √2 * sin(θ))
end

# (x, y) on the Mollweide plane → (lon, lat) in degrees; NaN outside the ellipse
function inv_mollweide(x, y)
    abs(y) > √2 && return (NaN, NaN)
    θ   = asin(y / √2)
    lon = -rad2deg(π * x / (2√2 * cos(θ)))
    abs(lon) > 180 && return (NaN, NaN)
    return (lon, asind(clamp((2θ + sin(2θ)) / π, -1.0, 1.0)))
end

# rasterise a HEALPix-ordered vector onto the Mollweide plane
function mollweide_raster(vals; nx=1600, ny=800)
    xs  = range(-2√2, 2√2, length=nx)
    ys  = range(-√2, √2, length=ny)
    img = fill(NaN, nx, ny)
    for (j, yv) in enumerate(ys), (i, xv) in enumerate(xs)
        lon, lat = inv_mollweide(xv, yv)
        isnan(lon) && continue
        p = Healpix.ang2pixRing(elong_res, deg2rad(90 - lat), deg2rad(mod(lon, 360)))
        img[i, j] = vals[p]
    end
    return xs, ys, img
end

# graticule: parallels every 30°, meridians every 60°, plus the outline
function draw_graticule!(ax)
    for lat in -60:30:60
        pts = [Point2f(mollweide(lon, lat)...) for lon in range(-179.999, 179.999, length=361)]
        lines!(ax, pts, color=(:white, lat == 0 ? 0.6 : 0.25), linewidth=lat == 0 ? 1.0 : 0.6)
    end
    for lon in -120:60:180
        pts = [Point2f(mollweide(lon == 180 ? 179.999 : lon, lat)...) for lat in -90:0.5:90]
        lines!(ax, pts, color=(:white, 0.25), linewidth=0.6)
    end
    for lon in (-179.999, 179.999)    # outline
        lines!(ax, [Point2f(mollweide(lon, lat)...) for lat in -90:0.5:90], color=:white, linewidth=1)
    end
    for lon in -120:60:120             # longitude labels along the ecliptic
        text!(ax, Point2f(mollweide(lon, 0)...), text="$(mod(lon, 360))°",
              fontsize=11, color=(:white, 0.8), align=(:center, :bottom), offset=(0, 3))
    end
    for lat in (-60, -30, 30, 60)      # latitude labels at the left edge
        text!(ax, Point2f(mollweide(179.999, lat)...), text="$(lat)°",
              fontsize=11, color=(:white, 0.8), align=(:right, :center), offset=(-4, 0))
    end
end

function mollweide_panel!(fig, row, vals, title, cmap, label; colorrange=nothing)
    ax = Axis(fig[row, 1], title=title, aspect=DataAspect())
    hidedecorations!(ax); hidespines!(ax)
    xs, ys, img = mollweide_raster(vals)
    cr = colorrange === nothing ? extrema(filter(!isnan, img)) : colorrange
    hm = heatmap!(ax, xs, ys, img, colormap=cmap, colorrange=cr, nan_color=(:grey45, 1.0))
    draw_graticule!(ax)
    Colorbar(fig[row, 2], hm, label=label, height=Relative(0.8))
    return ax
end

fig_elong = Figure(size=(1000, 1500))
mollweide_panel!(fig_elong, 1, pix_logn,   "Exposure count per pixel (nside = $ELONG_NSIDE)",
                 :viridis, "log₁₀ exposures")
mollweide_panel!(fig_elong, 2, pix_mean,   "Mean solar elongation of exposures",
                 :plasma, "elongation (°)")
mollweide_panel!(fig_elong, 3, pix_spread, "Range of solar elongations observed (max − min)",
                 :magma, "Δ elongation (°)")
Label(fig_elong[0, :], "SPHEREx boresight coverage — ecliptic coordinates, Mollweide (grey = never observed)",
      fontsize=18, font=:bold)
fig_elong
