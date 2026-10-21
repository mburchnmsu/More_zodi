# Shared Mollweide helpers for the sky-map plot scripts (moll_fwd, moll_raster, graticule!).
function moll_fwd(lon, lat)
    λ = deg2rad(mod(lon + 180, 360) - 180); φ = deg2rad(lat); θ = φ
    for _ in 1:50; abs(φ) > π/2 - 1e-9 && break; Δ = (2θ + sin(2θ) - π * sin(φ)) / (2 + 2cos(2θ)); θ -= Δ; abs(Δ) < 1e-12 && break; end
    (-2√2 / π * λ * cos(θ), √2 * sin(θ))
end
function moll_raster(G; nx=1400)
    res = 360 / size(G, 1); ny = nx ÷ 2; img = fill(NaN, nx, ny); xs = range(-2√2, 2√2, length=nx); ys = range(-√2, √2, length=ny)
    for (j, yv) in enumerate(ys), (i, xv) in enumerate(xs)
        (xv / (2√2))^2 + (yv / √2)^2 > 1 && continue
        θ = asin(yv / √2); lat = asind(clamp((2θ + sin(2θ)) / π, -1, 1)); lon = -rad2deg(π * xv / (2√2 * cos(θ)))
        img[i, j] = G[clamp(floor(Int, mod(lon, 360) / res) + 1, 1, size(G, 1)), clamp(floor(Int, (lat + 90) / res) + 1, 1, size(G, 2))]
    end
    xs, ys, img
end
function graticule!(ax)
    for lat in -60:30:60
        p = [Point2f(moll_fwd(l, lat)...) for l in range(-179.99, 179.99, length=361)]
        lines!(ax, p, color=(:white, lat == 0 ? 0.6 : 0.25), linewidth=lat == 0 ? 1.2 : 0.6)
    end
    for lon in -120:60:180
        lines!(ax, [Point2f(moll_fwd(lon == 180 ? 179.99 : lon, b)...) for b in -90:0.5:90], color=(:white, 0.25), linewidth=0.6)
    end
    for lon in (-179.99, 179.99); lines!(ax, [Point2f(moll_fwd(lon, b)...) for b in -90:0.5:90], color=:white, linewidth=1); end
end

