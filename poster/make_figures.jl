# Poster figures, each in a light and a dark version → poster/fig/<name>_{light,dark}.png
#   julia --project=. poster/make_figures.jl
# Inputs: poster/fig_accuracy.jld2 (data_accuracy.jl), poster/fig_spectra.jld2 (data_spectra.jl),
#         data/zodipy115_5um_healpix_components.h5 (all-sky map), speed numbers from bench_zodipy.py / bench_emulator.jl.
using CairoMakie, JLD2, HDF5, Healpix, Statistics, Printf
const OUT = joinpath(@__DIR__, "fig"); mkpath(OUT)
const ROOT = joinpath(@__DIR__, "..")

# poster palettes (must match build_poster.py)
const PAL = Dict(
    :light => (bg=colorant"#ffffff", fg=colorant"#1b1f24", sub=colorant"#5a6472", grid=colorant"#e3e7ec",
               a1=colorant"#1e5aa8", a2=colorant"#8c0b42", a3=colorant"#e08a00", cmap=:inferno),
    :dark  => (bg=colorant"#0f2036", fg=colorant"#eef3f8", sub=colorant"#a9b6c6", grid=colorant"#22385a",
               a1=colorant"#5fb0ff", a2=colorant"#ff6f91", a3=colorant"#ffb000", cmap=:inferno))
const FS = 30           # base font size (figure units); figures are ~15 in wide on the poster at 100 units/in

function themed(t)
    p = PAL[t]
    Theme(fontsize=FS, backgroundcolor=p.bg, textcolor=p.fg,
          Axis=(backgroundcolor=p.bg, xgridcolor=p.grid, ygridcolor=p.grid, leftspinecolor=p.sub, bottomspinecolor=p.sub,
                topspinevisible=false, rightspinevisible=false, xtickcolor=p.sub, ytickcolor=p.sub,
                xlabelsize=FS, ylabelsize=FS, titlesize=FS + 2, titlefont=:bold),
          Legend=(backgroundcolor=p.bg, framevisible=false, labelcolor=p.fg),
          Colorbar=(tickcolor=p.sub, labelsize=FS))
end
save2(name, fig) = save(joinpath(OUT, name * ".png"), fig, px_per_unit=2)

# ---------------------------------------------------------------- 1. all-sky map of the zodiacal light (Mollweide)
const SKY = h5open(joinpath(ROOT, "data", "zodipy115_5um_healpix_components.h5")) do f
    (; pix=read(f["pixels"]), y=read(f["emission"]), lat=read(f["ecliptic_latitude_deg"]), lon=read(f["ecliptic_longitude_deg"]))
end
const RES = Healpix.Resolution(256)
let k = 1:7919:length(SKY.pix)          # check: the stored pixels are RING-ordered 0..N-1 at the stored lat/lon
    @assert SKY.pix == 0:length(SKY.pix)-1
    @assert all(Healpix.ang2pixRing(RES, deg2rad(90 - SKY.lat[i]), deg2rad(SKY.lon[i])) == i for i in k)
end
function mollweide_raster(v; nx=1800, lon0=0.0)
    ny = nx ÷ 2; img = fill(NaN, nx, ny)
    for ix in 1:nx, iy in 1:ny
        x = (ix - 0.5) / nx * 4√2 - 2√2; yy = (iy - 0.5) / ny * 2√2 - √2
        (x / (2√2))^2 + (yy / √2)^2 > 1 && continue
        θ = asin(yy / √2); lat = asin((2θ + sin(2θ)) / π)
        lon = lon0 - π * x / (2√2 * cos(θ))                    # longitude increases to the LEFT (sky convention)
        img[ix, iy] = v[Healpix.ang2pixRing(RES, π / 2 - lat, mod(lon, 2π))]
    end
    img
end
function moll_xy(lon_deg, lat_deg; lon0=0.0)
    φ = deg2rad(lat_deg); θ = φ
    for _ in 1:50; abs(φ) > π/2 - 1e-9 && break; Δ = (2θ + sin(2θ) - π * sin(φ)) / (2 + 2cos(2θ)); θ -= Δ; abs(Δ) < 1e-12 && break; end
    λ = mod(deg2rad(lon_deg) - lon0 + π, 2π) - π
    (-2√2 / π * λ * cos(θ), √2 * sin(θ))
end

function fig_sky(t)
    p = PAL[t]
    with_theme(themed(t)) do
        fig = Figure(size=(1000, 600), figure_padding=10)
        ax = Axis(fig[1, 1], aspect=DataAspect()); hidedecorations!(ax); hidespines!(ax)
        # centre the map on the Sun (brightest pixel); grey out the 20° around it (far too bright, never observed)
        i = argmax(SKY.y); l0 = deg2rad(SKY.lon[i]); b0 = deg2rad(SKY.lat[i])
        cosel = sind.(SKY.lat) .* sin(b0) .+ cosd.(SKY.lat) .* cos(b0) .* cosd.(SKY.lon .- rad2deg(l0))
        v = ifelse.(cosel .> cosd(20), Inf, SKY.y)
        img = log10.(mollweide_raster(v; lon0=l0, nx=2400))
        hm = heatmap!(ax, range(-2√2, 2√2, length=size(img, 1)), range(-√2, √2, length=size(img, 2)), img,
                      colormap=p.cmap, colorrange=(log10(0.25), log10(20.0)), nan_color=(:white, 0.0), highclip=p.sub)
        g = (p.fg == PAL[:dark].fg ? p.fg : colorant"#ffffff")                       # lines over the map: always light
        for lat in -60:30:60                                      # graticule
            xy = [moll_xy(l, lat; lon0=l0) for l in -179.9:1:179.9]; lines!(ax, first.(xy), last.(xy), color=(g, 0.3), linewidth=1)
        end
        for lon in -150:30:180
            xy = [moll_xy(rad2deg(l0) + lon, b; lon0=l0) for b in -89.9:1:89.9]; lines!(ax, first.(xy), last.(xy), color=(g, 0.3), linewidth=1)
        end
        xy = [moll_xy(rad2deg(l0) + l, 0; lon0=l0) for l in -179.9:1:179.9]; lines!(ax, first.(xy), last.(xy), color=(g, 0.8), linewidth=2.5, linestyle=:dash)
        text!(ax, -2.55, 0.06, text="ecliptic", color=g, fontsize=FS - 2, align=(:left, :bottom))
        text!(ax, 0.0, 0.0, text="Sun", color=PAL[:light].fg, fontsize=FS, font=:bold, align=(:center, :center))
        text!(ax, 2.3, -0.12, text="looking away\nfrom the Sun", color=g, fontsize=FS - 6, align=(:right, :top))
        Colorbar(fig[1, 2], hm, label="5 μm brightness (MJy/sr)", ticks=(log10.([0.3, 1, 3, 10]), ["0.3", "1", "3", "10"]),
                 height=Relative(0.8))
        resize_to_layout!(fig)                    # drop the empty bands above/below the 2:1 map
        fig
    end
end

# ---------------------------------------------------------------- 2. schematic: Sun, dust cloud, Earth, SPHEREx's line of sight
function fig_schematic(t)
    p = PAL[t]
    with_theme(themed(t)) do
        fig = Figure(size=(1000, 720))
        ax = Axis(fig[1, 1], aspect=DataAspect(), limits=(-1.75, 1.75, -1.25, 1.25)); hidedecorations!(ax); hidespines!(ax)
        xs = range(-1.75, 1.75, length=700); ys = range(-1.25, 1.25, length=500)
        dust = [(r = hypot(x, y); exp(-r / 0.55) / (r + 0.12)) for x in xs, y in ys]       # brighter toward the Sun
        heatmap!(ax, xs, ys, dust ./ maximum(dust), colormap=cgrad([p.bg, p.a3]), colorrange=(0, 0.25))
        # a speckle of dust grains
        rng = 1:600; gx = [1.7 * (2 * ((i * 0.6180339887) % 1) - 1) for i in rng]; gy = [1.2 * (2 * ((i * 0.7548776662) % 1) - 1) for i in rng]
        scatter!(ax, gx, gy, color=(p.fg, 0.35), markersize=2.5)
        arc = range(0, 2π, length=400); lines!(ax, cos.(arc), sin.(arc), color=(p.sub, 0.9), linewidth=2, linestyle=:dash)
        scatter!(ax, [0.0], [0.0], color=colorant"#ffd23f", markersize=70, strokecolor=colorant"#ff9f1c", strokewidth=3)
        text!(ax, 0.0, -0.17, text="Sun", align=(:center, :top), color=p.fg, fontsize=FS + 2, font=:bold)
        E = (cosd(35), sind(35))
        scatter!(ax, [E[1]], [E[2]], color=p.a1, markersize=28, strokecolor=p.fg, strokewidth=2)
        text!(ax, E[1] + 0.1, E[2] - 0.04, text="Earth +\nSPHEREx", color=p.fg, fontsize=FS, font=:bold, align=(:left, :top))
        for (ang, lbl) in ((155, "line of sight"),)                                         # an example line of sight
            d = (cosd(ang), sind(ang)); L = ang == 155 ? 1.15 : 0.55
            arrows2d!(ax, [E[1]], [E[2]], [L * d[1]], [L * d[2]], color=p.a2, shaftwidth=6, tipwidth=30, tiplength=34)
            lbl == "" || text!(ax, E[1] + 0.55d[1] + 0.09d[2], E[2] + 0.55d[2] - 0.09d[1], text=lbl, color=p.a2, fontsize=FS, font=:bold, rotation=deg2rad(ang - 180))
        end
        text!(ax, cosd(-50) + 0.04, sind(-50) - 0.04, text="Earth's orbit", color=p.sub, fontsize=FS - 4, align=(:left, :top))
        fig
    end
end

# ---------------------------------------------------------------- 3. accuracy of the emulator on exposures it never saw
const ACC = JLD2.load(joinpath(@__DIR__, "fig_accuracy.jld2"))
function fig_accuracy(t)
    p = PAL[t]; e, dte = ACC["err_pct"], ACC["days_test"]; er = ACC["err_pct_random"]
    dg, st, D = ACC["dgrid"], ACC["test_status"], ACC["mission_days"]
    # contiguous train / test periods along the mission
    segs = Tuple{Float64, Float64, Bool}[]; a = dg[1]
    for i in 2:length(st); st[i] != st[i-1] && (push!(segs, (a, dg[i], st[i-1])); a = dg[i]); end
    push!(segs, (a, D, st[end]))
    lim = 0.3
    with_theme(themed(t)) do
        fig = Figure(size=(1600, 800))
        ax1 = Axis(fig[1, 1], xlabel="mission day", ylabel="error (%)", title="Error through the mission",
                   limits=((0, D), (-lim, lim)), xticks=0:30:150)
        for (a, b, test) in segs
            vspan!(ax1, a, b, color=(test ? p.a2 : p.a1, 0.12))
            text!(ax1, (a + b) / 2, 0.97lim, text=test ? "TESTED\n(never seen)" : "TRAINED", align=(:center, :top),
                  color=test ? p.a2 : p.a1, font=:bold, fontsize=FS - 6)
        end
        scatter!(ax1, dte, clamp.(e, -lim, lim), color=(p.fg, 0.05), markersize=3)
        hlines!(ax1, [0], color=p.sub, linewidth=1.5)
        ax2 = Axis(fig[1, 2], xlabel="error (%)", ylabel="number of pointings", title="How big are the errors?",
                   limits=((-lim, lim), (0, nothing)))
        hist!(ax2, filter(x -> abs(x) < lim, e), bins=range(-lim, lim, length=121), color=p.a2, strokewidth=0)   # (0.5% of errors lie beyond ±0.3%)
        m = median(abs.(e))
        text!(ax2, 0.98, 0.96, space=:relative, align=(:right, :top), color=p.fg, fontsize=FS - 4,
              text=@sprintf("%s pointings from\nthe 2 withheld months\n\nmedian error %.3f%%\n%.0f%% within 0.1%%",
                            replace(string(length(e)), r"(\d)(?=(\d{3})+$)" => s"\1,"), m, 100mean(abs.(e) .< 0.1)))
        colsize!(fig.layout, 1, Auto(1.25))
        fig
    end
end

# ---------------------------------------------------------------- 4. speed (poster/bench_*: same 20,000 pointings, 1 CPU core)
const SPEED = (zp_single=21.6e-3, em_single=11.1e-6, zp_batch=32.0e-6, em_batch=7.7e-6)   # seconds per pointing
function fig_speed(t)
    p = PAL[t]
    with_theme(themed(t)) do
        fig = Figure(size=(1250, 620))
        ax = Axis(fig[1, 1], xscale=log10, xlabel="time per pointing (seconds, log scale)", yticks=(1:2, ["many at once\n(20,000)", "one at a time"]),
                  xticks=([1e-5, 1e-4, 1e-3, 1e-2], ["10 μs", "100 μs", "1 ms", "10 ms"]), limits=((3e-6, 2.0), (0.4, 2.6)))
        h = 0.32
        barplot!(ax, [2 + h/2, 1 + h/2], [SPEED.zp_single, SPEED.zp_batch], width=h, direction=:x, color=p.sub, fillto=1e-6, label="ZodiPy (physics model)")
        barplot!(ax, [2 - h/2, 1 - h/2], [SPEED.em_single, SPEED.em_batch], width=h, direction=:x, color=p.a1, fillto=1e-6, label="neural network")
        for (yy, z, m) in ((2, SPEED.zp_single, SPEED.em_single), (1, SPEED.zp_batch, SPEED.em_batch))
            r = z / m; lbl = r > 100 ? "~$(round(Int, round(r, sigdigits=1)))× faster" : @sprintf("~%.0f× faster", r)
            text!(ax, z * 1.25, yy + h/2, text=replace(lbl, "2000" => "2,000"), align=(:left, :center), color=p.a2, fontsize=FS + 4, font=:bold)
        end
        axislegend(ax, position=:rb, labelsize=FS - 2)
        fig
    end
end

# ---------------------------------------------------------------- 5. multi-wavelength: predicted spectra vs ZodiPy
const SPC = JLD2.load(joinpath(@__DIR__, "fig_spectra.jld2"))
function fig_spectra(t)
    p = PAL[t]; w, Y, P, lat = SPC["w"], SPC["ytrue"], SPC["ypred"], SPC["lat"]
    pick = [1, 3, 5]; cols = [p.a3, p.a2, p.a1]
    with_theme(themed(t)) do
        fig = Figure(size=(1500, 1000))
        ax = Axis(fig[1, 1], ylabel="brightness (MJy/sr)", xscale=log10, yscale=log10, xticks=[1.25, 1.5, 2, 2.5, 3, 4, 5],
                  yticks=([0.05, 0.1, 0.2, 0.3, 0.5], ["0.05", "0.1", "0.2", "0.3", "0.5"]), title="One network, every wavelength from 1.25 to 5 μm")
        ax2 = Axis(fig[2, 1], xlabel="wavelength (μm)", ylabel="difference (%)", xscale=log10, xticks=[1.25, 1.5, 2, 2.5, 3, 4, 5])
        for (c, i) in zip(cols, pick)
            lines!(ax, w, Y[i, :], color=c, linewidth=6, label=@sprintf("ZodiPy, %.0f° from the ecliptic", abs(lat[i])))
            lines!(ax, w, P[i, :], color=p.fg, linewidth=2.5, linestyle=:dash)
            lines!(ax2, w, 100 .* (P[i, :] .- Y[i, :]) ./ Y[i, :], color=c, linewidth=3)
        end
        lines!(ax, [NaN], [NaN], color=p.fg, linewidth=2.5, linestyle=:dash, label="neural network")
        hlines!(ax2, [0], color=p.sub, linewidth=1.5)
        text!(ax, 1.35, minimum(Y) * 1.05, text="scattered sunlight", color=p.sub, fontsize=FS - 2)
        text!(ax, 4.9, minimum(Y) * 1.05, text="dust's heat glow", color=p.sub, fontsize=FS - 2, align=(:right, :bottom))
        axislegend(ax, position=:ct, labelsize=FS - 4)
        ylims!(ax2, -1.2, 1.2); linkxaxes!(ax, ax2); hidexdecorations!(ax, grid=false)
        rowsize!(fig.layout, 2, Relative(0.28))
        fig
    end
end

for t in (:light, :dark)
    for (name, f) in (("sky", fig_sky), ("schematic", fig_schematic), ("accuracy", fig_accuracy), ("speed", fig_speed), ("spectra", fig_spectra))
        save2("$(name)_$(t)", f(t)); println("wrote fig/$(name)_$(t).png")
    end
end
