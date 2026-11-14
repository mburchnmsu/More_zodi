# Week 14 question: what are the grey regions in the Earth-motion frame of figures/11042026_earth2d_moll.png?
# Crops the top-left panel (without Earth-centric inputs, Earth-motion frame) and labels each grey region. No model runs.
#     julia --project=. sweeps/earth2d_gray_annot.jl   → figures/11132026_earth2d_gray_annot.png
using CairoMakie
src = joinpath(@__DIR__, "..", "figures", "11042026_earth2d_moll.png")
img = CairoMakie.FileIO.load(src)
s = size(img, 2) / 2000                                   # panel box measured on a 2000-px-wide view of the figure
x0, x1, y0, y1 = round.(Int, s .* (22, 628, 72, 375))
P = img[y0:y1, x0:x1]; H, W = size(P)
set_theme!(merge(Theme(fontsize=26), theme_black()))
fig = Figure(size=(W, H + 40))
ax = Axis(fig[1, 1], aspect=DataAspect()); hidedecorations!(ax); hidespines!(ax)
image!(ax, 0 .. W, 0 .. H, rotr90(P))
lab(x, y, t; al=(:center, :center)) = text!(ax, x, y; text=t, color=:yellow, font=:bold, fontsize=27, align=al)
px(xd, yd) = (s * (xd - 22), H - s * (yd - 72))           # 2000-px-view coordinates → crop pixels
lab(px(478, 285)..., "A: Sun side\nnever observed\n(within ~90° of the Sun:\nSun avoidance)")
lab(px(178, 175)..., "B: anti-Sun side\nnever observed\n(more than ~115°\nfrom the Sun)")
lab(px(26, 80)..., "C: off the map", al=(:left, :top))
lab(px(26, 372)..., "D: 3° cells with < 30 exposures", al=(:left, :bottom))
a0 = px(60, 358); a1 = px(56, 244)
arrows2d!(ax, [a0[1]], [a0[2]], [a1[1] - a0[1]], [a1[2] - a0[2]], color=:yellow, shaftwidth=3, tipwidth=14, tiplength=14)
Label(fig[2, 1], "Grey = no data. SPHEREx points ~90–115° from the Sun, so only the strips at 'ahead' and 'behind' fill.",
      fontsize=20, tellwidth=false)
save(joinpath(@__DIR__, "..", "figures", "11132026_earth2d_gray_annot.png"), fig, px_per_unit=1.5)
println("ok")
