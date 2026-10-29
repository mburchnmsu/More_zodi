# How precise is each piece? Emulator error vs the Kelsall model's own error against real data, on one log scale:
#   figures/<tag>_precision_compare.png
#     julia --project=. realdata/precision_compare.jl [tag]
# Numbers: ours from round 34 (sweeps/report34*.jl sky map) and notebook 10292026 (real SPHEREx data); the literature
# rows are from the user's Kelsall-precision summary (Kelsall et al. 1998 Table 5; later independent tests) and still
# need checking against the papers (in particular the 4.9 um row of Table 5).
using CairoMakie, Printf
const R = joinpath(@__DIR__, ".."); tag = isempty(ARGS) ? "prec" : ARGS[1]

# (label, low %, high %, marked values %, note)
groups = [
    ("Our emulator vs the Kelsall model (round 34, 5-network average)", :royalblue, [
        ("Full sky", 0.0120, 0.035, [0.0130], "median 0.013% (dot); bar: median above 60° to the 95th percentile"),
        ("Within 2° of the ecliptic", 0.0162, 0.0162, [0.0162], "median per pixel"),
    ]),
    ("Kelsall model vs DIRBE data (Kelsall et al. 1998)", :darkorange, [
        ("Fit residuals, per band (Table 5)", 0.28, 1.49, Float64[], "spread of the residuals, 10 bands; 4.9 μm value to check"),
        ("Single pixels", 2.0, 4.0, Float64[], "\"2% or better\", up to ~4%"),
    ]),
    ("Kelsall model vs other data (Spitzer, AKARI, MSX, ...)", :firebrick, [
        ("High ecliptic latitude", 2.0, 5.0, Float64[], "\"a few %\""),
        ("Near the ecliptic / small elongation", 10.0, 30.0, Float64[], "plus an unknown all-sky offset"),
    ]),
    ("Kelsall (ZodiPy) vs real SPHEREx data at 5 μm (ours, notebook 10292026)", :seagreen, [
        ("Pole: scatter about image = a × ZodiPy + b (qr2)", 1.3, 1.8, [1.5], "435 frames over 15 months"),
        ("SPHEREx's zodi model ÷ ZodiPy − 1", 4.0, 21.0, [4.0, 6.5, 16.8, 20.0], "pole qr2, ecliptic qr2, pole qr3, ecliptic qr3"),
        ("Jump between releases qr2 → qr3", 12.3, 12.7, [12.5], "calibration, not the zodi model"),
    ]),
]

fig = Figure(size=(1700, 900), fontsize=17)
ax = Axis(fig[1, 1], xscale=log10, xlabel="error or difference (%)", yticksvisible=false,
          xticks=([0.01, 0.03, 0.1, 0.3, 1, 3, 10, 30], ["0.01", "0.03", "0.1", "0.3", "1", "3", "10", "30"]),
          title="Our emulator is ~20× more precise than the Kelsall model's best fit to real data",
          subtitle="So the emulator is not the limit: the zodi model itself is (a few % on the sky, more near the ecliptic)")
y = 0.0; ticks = Float64[]; labs = String[]
for (gname, col, rows) in groups
    global y
    text!(ax, 0.0042, y, text=gname, font=:bold, color=col, fontsize=16, align=(:left, :center))
    y -= 1
    for (lab, lo, hi, pts, note) in rows
        if hi > lo
            band!(ax, [lo, hi], [y - 0.22, y - 0.22], [y + 0.22, y + 0.22], color=(col, 0.35))
            lines!(ax, [lo, hi], [y, y], color=col, linewidth=3)
        end
        isempty(pts) || scatter!(ax, pts, fill(y, length(pts)), color=col, markersize=14, strokecolor=:white, strokewidth=1)
        hi > 3 ? text!(ax, lo / 1.12, y, text=note, fontsize=13, color=:grey30, align=(:right, :center)) :
                 text!(ax, hi * 1.12, y, text=note, fontsize=13, color=:grey30, align=(:left, :center))
        push!(ticks, y); push!(labs, lab); y -= 1
    end
    y -= 0.4
end
ax.yticks = (ticks, labs)
vlines!(ax, [0.0130], color=(:royalblue, 0.4), linestyle=:dash)
vlines!(ax, [0.28], color=(:darkorange, 0.4), linestyle=:dash)
text!(ax, sqrt(0.0130 * 0.28), y + 0.55, text="×20", color=:grey30, fontsize=15, align=(:center, :center))
arrows2d!(ax, [0.0145], [y + 0.25], [0.28 - 0.0145 - 0.02], [0.0], color=:grey40, shaftwidth=1.5, tipwidth=9, tiplength=9)
limits!(ax, 0.004, 60, y - 0.1, 0.6)
hidespines!(ax, :t, :r, :l)
Label(fig[2, 1], "Different rows measure different things: ours are per-pixel errors (emulator vs model) or fits to one sky point; Kelsall's Table 5 is the spread of weekly all-sky residuals.\n" *
      "Literature rows: from a summary of Kelsall et al. (1998) and later tests, not yet checked against the papers. SPHEREx's own zodi-subtraction requirement is not shown (to be added).",
      fontsize=13, color=:grey35, justification=:left, halign=:left)
save(joinpath(R, "figures", "$(tag)_precision_compare.png"), fig, px_per_unit=1.5)
println("ok")
