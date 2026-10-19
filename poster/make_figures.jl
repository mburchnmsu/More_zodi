# Poster figures, each in a light and a dark version → poster/fig/<name>_{light,dark}.png
#   julia --project=. poster/make_figures.jl
# Inputs: poster/fig_accuracy.jld2 (data_accuracy.jl), poster/fig_spectra.jld2 (data_spectra.jl),
#         poster/fig_skyerror.jld2 (data_skyerror.jl), poster/fig_training.jld2 (data_training.jl),
#         poster/fig_components.jld2 (data_components.jl),
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

# ---------------------------------------------------------------- 2. the geometry the network sees (top view, not to scale)
# Sun, Earth, SPHEREx, Moon, Jupiter; the look direction n̂ and the vectors it is dotted with.
arc!(ax, c, r, a1, a2; kw...) = (θ = range(deg2rad(a1), deg2rad(a2), length=60); lines!(ax, c[1] .+ r .* cos.(θ), c[2] .+ r .* sin.(θ); kw...))
function vec!(ax, a, b, col; shrink=0.0, kw...)
    d = b .- a; L = hypot(d...); u = d ./ L
    arrows2d!(ax, [a[1]], [a[2]], [(L - shrink) * u[1]], [(L - shrink) * u[2]]; color=col, shaftwidth=5, tipwidth=24, tiplength=26, kw...)
end
function fig_geometry(t)
    p = PAL[t]
    cS, cE, cv, cJ = p.a1, colorant"#2e9d5b", colorant"#8e5bd1", colorant"#b5651d"
    with_theme(themed(t)) do
        fig = Figure(size=(1500, 1020), figure_padding=8)
        X, Y = (-2.15, 2.05), (-1.32, 1.45)
        ax = Axis(fig[1, 1], aspect=DataAspect(), limits=(X..., Y...)); hidedecorations!(ax); hidespines!(ax)
        xs = range(X..., length=820); ys = range(Y..., length=560)
        dust = [(r = hypot(x, y); exp(-r / 0.6) / (r + 0.12)) for x in xs, y in ys]
        heatmap!(ax, xs, ys, dust ./ maximum(dust), colormap=cgrad([p.bg, p.a3]), colorrange=(0, 0.3))
        θ = range(0, 2π, length=400)
        lines!(ax, cos.(θ), sin.(θ), color=(p.sub, 0.9), linewidth=2, linestyle=:dash)                       # Earth's orbit
        arc!(ax, (0, 0), 1.85, 112, 212, color=(p.sub, 0.9), linewidth=2, linestyle=:dot)                 # Jupiter's orbit (part)
        # fixed reference direction and Earth's orbital angle λ⊕
        lines!(ax, [0.0, 1.95], [0.0, 0.0], color=(p.sub, 0.9), linewidth=2, linestyle=:dash)
        text!(ax, 1.95, -0.04, text="fixed direction x̂", color=p.sub, fontsize=FS - 6, align=(:right, :top))
        λ = 30.0; E = (cosd(λ), sind(λ))
        arc!(ax, (0, 0), 0.32, 0, λ, color=p.fg, linewidth=3)
        text!(ax, 0.36cosd(λ / 2), 0.36sind(λ / 2), text="λ⊕", color=p.fg, fontsize=FS + 2, font=:bold, align=(:left, :center))
        # bodies
        Sp = E .+ 0.25 .* (cosd(-35), sind(-35))                         # SPHEREx (distance from Earth exaggerated)
        Mo = E .+ 0.30 .* (cosd(165), sind(165))
        Ju = 1.85 .* (cosd(158), sind(158))
        arc!(ax, E, 0.25, 0, 360, color=(p.sub, 0.7), linewidth=1.5, linestyle=:dot)
        # vectors from the Sun
        vec!(ax, (0.0, 0.0), E, cE; shrink=0.06)
        vec!(ax, (0.0, 0.0), Sp, cS; shrink=0.05)
        vec!(ax, (0.0, 0.0), Ju, (cJ, 0.8); shrink=0.09)
        text!(ax, 0.55E[1] - 0.03, 0.55E[2] + 0.06, text="E", color=cE, fontsize=FS + 4, font=:bold, align=(:right, :bottom))
        text!(ax, 0.6Sp[1] + 0.04, 0.6Sp[2] - 0.06, text="S", color=cS, fontsize=FS + 4, font=:bold, align=(:left, :top))
        text!(ax, 0.55Ju[1], 0.55Ju[2] + 0.06, text="J", color=cJ, fontsize=FS + 4, font=:bold, align=(:center, :bottom))
        scatter!(ax, [0.0], [0.0], color=colorant"#ffd23f", markersize=64, strokecolor=colorant"#ff9f1c", strokewidth=3)
        text!(ax, 0.0, -0.16, text="Sun", align=(:center, :top), color=p.fg, fontsize=FS, font=:bold)
        scatter!(ax, [E[1]], [E[2]], color=colorant"#2f6fd0", markersize=30, strokecolor=p.fg, strokewidth=2)
        text!(ax, E[1] + 0.05, E[2] + 0.07, text="Earth", color=p.fg, fontsize=FS, font=:bold, align=(:left, :bottom))
        scatter!(ax, [Mo[1]], [Mo[2]], color=colorant"#9aa3ad", markersize=16, strokecolor=p.fg, strokewidth=1)
        text!(ax, Mo[1] - 0.05, Mo[2], text="Moon", color=p.sub, fontsize=FS - 4, align=(:right, :center))
        scatter!(ax, [Ju[1]], [Ju[2]], color=colorant"#d39a5c", markersize=44, strokecolor=p.fg, strokewidth=1.5)
        text!(ax, Ju[1], Ju[2] - 0.12, text="Jupiter\n(5.2 AU, not to scale)", color=p.fg, fontsize=FS - 4, font=:bold, align=(:center, :top))
        scatter!(ax, [Sp[1]], [Sp[2]], color=p.fg, marker=:diamond, markersize=20)
        text!(ax, Sp[1] + 0.05, Sp[2] - 0.04, text="SPHEREx", color=p.fg, fontsize=FS - 2, font=:bold, align=(:left, :top))
        # motion and look direction
        vdir = λ + 90; nd = 62.0; φS = atand(Sp[2], Sp[1])
        vec!(ax, E, E .+ 0.55 .* (cosd(vdir), sind(vdir)), cv)
        text!(ax, E[1] + 0.58cosd(vdir), E[2] + 0.58sind(vdir), text="v (orbital motion)", color=cv, fontsize=FS - 4, font=:bold, align=(:right, :bottom))
        vec!(ax, Sp, Sp .+ 0.95 .* (cosd(nd), sind(nd)), p.a2)
        text!(ax, Sp[1] + 0.95cosd(nd) - 0.08, Sp[2] + 0.95sind(nd) + 0.02, text="n̂ = where SPHEREx looks", color=p.a2, fontsize=FS - 2, font=:bold, align=(:right, :center))
        lines!(ax, [Sp[1], Sp[1] + 0.55cosd(φS)], [Sp[2], Sp[2] + 0.55sind(φS)], color=(cS, 0.7), linewidth=2, linestyle=:dash)   # S direction, extended
        arc!(ax, Sp, 0.30, φS, nd, color=cS, linewidth=3)
        text!(ax, Sp[1] + 0.40cosd((φS + nd) / 2), Sp[2] + 0.40sind((φS + nd) / 2), text="n·S", color=cS, fontsize=FS, font=:bold, align=(:left, :center))
        # ẑ out of the page
        zc = (-1.95, 1.25)
        scatter!(ax, [zc[1]], [zc[2]], marker=:circle, markersize=34, color=(p.bg, 0.0), strokecolor=p.fg, strokewidth=3)
        scatter!(ax, [zc[1]], [zc[2]], markersize=9, color=p.fg)
        text!(ax, zc[1] + 0.1, zc[2], text="ẑ points out of the page (north of the planets' plane): n·z = how high above it n̂ looks",
              color=p.fg, fontsize=FS - 6, align=(:left, :center))
        text!(ax, -2.1, -1.28, text="Each input is a dot product n·a:\n+1 = looking along a, 0 = sideways, −1 = opposite",
              color=p.fg, fontsize=FS - 4, align=(:left, :bottom))
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

# ---------------------------------------------------------------- 3b. accuracy: error through the mission + network vs ZodiPy 1:1
function fig_accuracy2(t)
    p = PAL[t]; e, dte = ACC["err_pct"], ACC["days_test"]; yt, yp = ACC["ytrue"], ACC["ypred"]
    dg, st, D = ACC["dgrid"], ACC["test_status"], ACC["mission_days"]
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
        lo, hi = 0.3, 1.15
        ax2 = Axis(fig[1, 2], xlabel="ZodiPy brightness (MJy/sr)", ylabel="network brightness (MJy/sr)",
                   title="Network vs. ZodiPy", aspect=1, limits=((lo, hi), (lo, hi)))
        lines!(ax2, [lo, hi], [lo, hi], color=p.sub, linewidth=2, linestyle=:dash)
        scatter!(ax2, yt, yp, color=(p.a2, 0.08), markersize=4)
        text!(ax2, 0.04, 0.96, space=:relative, align=(:left, :top), color=p.fg, fontsize=FS - 4,
              text=@sprintf("%s pointings never\nseen in training\nmedian error %.3f%%",
                            replace(string(length(e)), r"(\d)(?=(\d{3})+$)" => s"\1,"), median(abs.(e))))
        # zoomed inset: a 0.01 MJy/sr window (~100× magnified) around 0.7 MJy/sr
        z0, z1 = 0.700, 0.706
        k = (z0 .<= yt .<= z1)
        ax3 = Axis(fig[1, 2], width=Relative(0.40), height=Relative(0.40), halign=0.97, valign=0.10,
                   limits=((z0, z1), (z0, z1)), xticksvisible=false, yticksvisible=false, xticklabelsvisible=false,
                   yticklabelsvisible=false, backgroundcolor=p.bg, title="zoomed ~100×", titlesize=FS - 8,
                   leftspinecolor=p.fg, bottomspinecolor=p.fg, rightspinevisible=true, topspinevisible=true,
                   rightspinecolor=p.fg, topspinecolor=p.fg)
        lines!(ax3, [z0, z1], [z0, z1], color=p.sub, linewidth=2, linestyle=:dash)
        scatter!(ax3, yt[k], yp[k], color=(p.a2, 0.35), markersize=4)
        colsize!(fig.layout, 1, Auto(1.35))
        fig
    end
end

# ---------------------------------------------------------------- 9. what makes up the zodiacal light (Kelsall components)
const CMP = JLD2.load(joinpath(@__DIR__, "fig_components.jld2"))
function fig_components(t)
    p = PAL[t]; keep = [1, 4, 5, 6]                                   # plane, poles, ahead of Earth, behind Earth
    S = CMP["share"][keep, :]; rl = CMP["row_labels"][keep]; pl = CMP["part_labels"]; sm = CMP["smooth_share"][keep]
    cols = [p.a3, p.a1, p.a2]; n = length(rl)
    ypos = [1, 2, 3.5, 4.5]                                           # gap before the ahead/behind rows
    with_theme(themed(t)) do
        fig = Figure(size=(1500, 600))
        ax = Axis(fig[1, 1], yticks=(ypos, rl), yreversed=true, xlabel="share of the total brightness (%)",
                  title="The other 5–12%: everything except the smooth cloud", limits=((0, 16.5), (0.4, ypos[end] + 0.6)),
                  xticks=0:2:12, ygridvisible=false, yticklabelsize=FS - 4)
        for i in 1:n
            x0 = 0.0
            for j in 1:length(pl)
                barplot!(ax, [ypos[i]], [S[i, j]], fillto=x0, offset=x0, direction=:x, width=0.7, color=cols[j],
                         label=i == 1 ? pl[j] : nothing)
                x0 += S[i, j]
            end
            text!(ax, x0 + 0.25, ypos[i], text=@sprintf("+ smooth cloud %.0f%%", sm[i]), align=(:left, :center),
                  color=p.sub, fontsize=FS - 6)
        end
        Legend(fig[0, 1], [PolyElement(color=c) for c in cols], pl, orientation=:horizontal, labelsize=FS - 4, framevisible=false)
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

# ---------------------------------------------------------------- 6. where on the sky the errors are (out-of-sample, round 16)
const SKE = JLD2.load(joinpath(@__DIR__, "fig_skyerror.jld2"))
function fig_skyerror(t; key="G")             # key = "G" (3.5° patches) or "G7" (7° blend)
    p = PAL[t]; G = SKE[key]; res = SKE["res"]
    with_theme(themed(t)) do
        fig = Figure(size=(1500, 760), figure_padding=10)
        ax = Axis(fig[1, 1], aspect=DataAspect()); hidedecorations!(ax); hidespines!(ax)
        nx = 2400; ny = nx ÷ 2; img = fill(NaN, nx, ny); out = fill(false, nx, ny)
        for ix in 1:nx, iy in 1:ny
            x = (ix - 0.5) / nx * 4√2 - 2√2; yy = (iy - 0.5) / ny * 2√2 - √2
            (x / (2√2))^2 + (yy / √2)^2 > 1 && (out[ix, iy] = true; continue)
            θ = asin(yy / √2); lat = asind(clamp((2θ + sin(2θ)) / π, -1, 1))
            lon = mod(-rad2deg(π * x / (2√2 * cos(θ))), 360)       # longitude 0 in the centre, increasing to the LEFT
            img[ix, iy] = G[clamp(floor(Int, lon / res) + 1, 1, size(G, 1)), clamp(floor(Int, (lat + 90) / res) + 1, 1, size(G, 2))]
        end
        unobs = t == :light ? colorant"#c9ced6" : colorant"#33465f"
        img2 = ifelse.(out, NaN, ifelse.(isnan.(img), -1.0, img))     # −1 → "not tested" colour; outside the ellipse transparent
        xs = range(-2√2, 2√2, length=nx); ys = range(-√2, √2, length=ny)
        heatmap!(ax, xs, ys, ifelse.(img2 .== -1, 1.0, NaN), colormap=[unobs, unobs], colorrange=(0, 2), nan_color=(:white, 0.0))
        hm = heatmap!(ax, xs, ys, ifelse.(img2 .== -1, NaN, img2), colormap=:viridis, colorrange=(0.0, 0.08),
                      highclip=Makie.to_colormap(:viridis)[end], nan_color=(:white, 0.0))
        g = p.fg
        for lat in (-60, -30, 30, 60)
            xy = [moll_xy(l, lat) for l in -179.9:1:179.9]; lines!(ax, first.(xy), last.(xy), color=(g, 0.25), linewidth=1)
        end
        for lon in -150:30:180
            xy = [moll_xy(lon, b) for b in -89.9:1:89.9]; lines!(ax, first.(xy), last.(xy), color=(g, 0.25), linewidth=1)
        end
        xy = [moll_xy(l, 0) for l in -179.9:1:179.9]; lines!(ax, first.(xy), last.(xy), color=(g, 0.7), linewidth=2, linestyle=:dash)
        xy = [moll_xy(l, b) for (l, b) in vcat([(179.99, b) for b in -90:1:90], [(-179.99, b) for b in 90:-1:-90])]
        lines!(ax, first.(xy), last.(xy), color=p.sub, linewidth=2)
        text!(ax, -1.78, 0.06, text="plane of the\nplanets", color=g, fontsize=FS - 4, align=(:center, :bottom))
        text!(ax, -1.78, -0.08, text="(grey: not tested)", color=p.sub, fontsize=FS - 8, align=(:center, :top))
        Colorbar(fig[1, 2], hm, label="size of the error (%)", height=Relative(0.8), ticks=0:0.02:0.08,
                 tickformat=v -> [@sprintf("%.2f", x) for x in v])
        resize_to_layout!(fig)
        fig
    end
end

# ---------------------------------------------------------------- 7. train and test MSE during training (5 seeds; thick = mean)
const TRN = JLD2.load(joinpath(@__DIR__, "fig_training.jld2"))
function fig_training(t)
    p = PAL[t]
    with_theme(themed(t)) do
        fig = Figure(size=(1500, 620), figure_padding=(10, 45, 10, 10))
        panels = (("Whole months withheld", TRN["blk_tr"], TRN["blk_te"]),)
        lo = minimum(TRN["blk_tr"]) / 1.5; hi = 3e-4
        axs = Axis[]
        for (c, (ttl, tr, te)) in enumerate(panels)    # epoch-averaged curves: row e = epoch e (1-based)
            ax = Axis(fig[1, c], yscale=log10, title=ttl, xlabel="training pass (epoch)", ylabel=c == 1 ? "error (MSE, log scale)" : "",
                      limits=((0, size(tr, 1)), (lo, hi)),
                      yticks=([1e-8, 1e-7, 1e-6, 1e-5, 1e-4], ["10⁻⁸", "10⁻⁷", "10⁻⁶", "10⁻⁵", "10⁻⁴"]))
            push!(axs, ax); ep = 1:size(tr, 1)
            for s in 1:size(tr, 2)
                lines!(ax, ep, tr[:, s], color=(p.a1, 0.3), linewidth=1.5); lines!(ax, ep, te[:, s], color=(p.a2, 0.3), linewidth=1.5)
            end
            lines!(ax, ep, vec(mean(tr, dims=2)), color=p.a1, linewidth=5, label="training data")
            lines!(ax, ep, vec(mean(te, dims=2)), color=p.a2, linewidth=5, label="withheld data")
            c == 1 && axislegend(ax, position=:rt, labelsize=FS - 2)
        end
        fig
    end
end

# ---------------------------------------------------------------- 8. the six shifted versions of the 30-day split
function fig_shifts(t)
    p = PAL[t]; st, g, sh = TRN["status"], TRN["grid"], TRN["shifts"]; D = TRN["span"]
    cols = (p.a1, p.a2, p.a3); n = length(sh)
    with_theme(themed(t)) do
        fig = Figure(size=(1600, 720))
        ax = Axis(fig[1, 1], xlabel="mission day", yticks=(1:n, ["+$(Δ) days" for Δ in sh]), yreversed=true,
                  limits=((0, D + 52), (0.4, n + 0.6)), xticks=0:30:120, ygridvisible=false, xgridvisible=false)
        for row in 1:n
            a = 1
            for i in 2:length(g)
                (i == length(g) || st[row, i] != st[row, a]) || continue
                b = i == length(g) ? i : i
                poly!(ax, Rect(g[a], row - 0.36, g[b] - g[a], 0.72), color=(cols[st[row, a] + 1], st[row, a] == 0 ? 0.55 : 0.9))
                a = i
            end
            text!(ax, D + 3, row - 0.08, text=@sprintf("%.3f%%", TRN["med_in"][row]), align=(:left, :center), color=p.a2, font=:bold, fontsize=FS)
            isnan(TRN["med_edge"][row]) ||
                text!(ax, D + 3, row + 0.28, text=@sprintf("ends: %.2f%%", TRN["med_edge"][row]), align=(:left, :center), color=p.a3, fontsize=FS - 8)
        end
        text!(ax, D + 3, 0.45, text="median\nerror", align=(:left, :bottom), color=p.fg, fontsize=FS - 6, font=:bold)
        Legend(fig[0, 1], [PolyElement(color=(c, a)) for (c, a) in zip(cols, (0.55, 0.9, 0.9))],
               ["trained on", "tested: between training months", "tested: start/end of mission"], orientation=:horizontal,
               labelsize=FS - 4, framevisible=false)
        fig
    end
end

for t in (:light, :dark)
    for (name, f) in (("sky", fig_sky), ("geometry", fig_geometry), ("accuracy", fig_accuracy), ("spectra", fig_spectra),
                      ("skyerror", fig_skyerror), ("training", fig_training), ("shifts", fig_shifts),
                      ("accuracy2", fig_accuracy2), ("components", fig_components),
                      ("skyerror7", t -> fig_skyerror(t; key="G7")))
        save2("$(name)_$(t)", f(t)); println("wrote fig/$(name)_$(t).png")
    end
end
