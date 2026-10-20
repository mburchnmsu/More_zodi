# One-slide summary ("model card") of the current poster model, dark theme → figures/10192026_model_card.png
#   julia --project=. sweeps/plot_model_card.jl
using CairoMakie, Printf
const R = "C:/JuliaProjects/More_zodi"
# --- the model (configs_v21.jl / mb_train.jl) ---
inputs = ["n·S", "n·E", "n·z", "n·vS", "n·vE", "n·x⊕", "n·y⊕", "sin λ⊕", "cos λ⊕"]
layers = [9, 64, 64, 32, 16, 1]
nparams = sum(layers[i] * layers[i+1] + layers[i+1] for i in 1:length(layers)-1)
epochs, batch, ntrain = 750, 512, 243_441                     # poster split (30-day blocks): 243,441 training pointings
steps_per_epoch = cld(ntrain, batch); S = epochs * steps_per_epoch
lr_max, pct, div, final_div = 1e-3, 0.3, 25.0, 1e4            # one-cycle (mb_train.jl lr_at)
function lr_at(t)
    lo, hi, fin = lr_max / div, lr_max, lr_max / final_div
    t <= pct && return lo + (hi - lo) * 0.5 * (1 - cos(π * t / pct))
    u = (t - pct) / (1 - pct); fin + (hi - fin) * 0.5 * (1 + cos(π * u))
end

set_theme!(merge(Theme(fontsize=20), theme_black()))
fig = Figure(size=(1900, 1050))
Label(fig[0, 1:2], "The poster model: a geometrically constrained neural network", font=:bold, fontsize=30)

# --- architecture diagram ---
ax = Axis(fig[1, 1], title="Architecture: fully connected, $(join(layers, " → ")) ($(nparams) parameters)",
          titlesize=20, limits=((-1.7, 6.4), (-2.0, 10.2)), width=880, height=820); hidedecorations!(ax); hidespines!(ax)
shown = [9, 10, 10, 8, 6, 1]                                   # nodes drawn per layer (big layers abbreviated with "⋮")
cols = [:deepskyblue, :mediumpurple1, :mediumpurple1, :mediumpurple1, :mediumpurple1, :hotpink]
# abbreviated layers: two groups of nodes with a gap in the middle for the "⋮"
ypos(n, full) = n == 1 ? [5.0] : n == full ? collect(range(9.5, 0.5, length=n)) :
                vcat(collect(range(9.5, 6.3, length=n ÷ 2)), collect(range(3.7, 0.5, length=n - n ÷ 2)))
P = [[(Float64(i - 1), yy) for yy in ypos(shown[i], layers[i])] for i in 1:length(layers)]
for i in 1:length(layers)-1, a in P[i], b in P[i+1]
    lines!(ax, [a[1], b[1]], [a[2], b[2]], color=(:white, 0.06), linewidth=0.8)
end
for (i, pts) in enumerate(P)
    scatter!(ax, first.(pts), last.(pts), color=cols[i], markersize=i == 1 || i == length(P) ? 26 : 20, strokecolor=:white, strokewidth=1)
    shown[i] < layers[i] && text!(ax, i - 1.0, 5.0, text="⋮", align=(:center, :center), fontsize=30, color=:white)
    text!(ax, i - 1.0, -0.55, text=i == 1 ? "9 inputs" : i == length(P) ? "output" : "$(layers[i])", align=(:center, :top),
          fontsize=18, color=:white, font=:bold)
end
for (k, (x, yy)) in enumerate(P[1]); text!(ax, x - 0.25, yy, text=inputs[k], align=(:right, :center), fontsize=17, color=:deepskyblue); end
text!(ax, 5.25, 5.0, text="brightness\n(MJy/sr)", align=(:left, :center), fontsize=17, color=:hotpink)
text!(ax, 2.5, -1.45, text="hidden layers: GELU activation", align=(:center, :center), fontsize=18, color=:mediumpurple1)

# --- learning-rate schedule ---
ax2 = Axis(fig[1, 2][1, 1], yscale=log10, title="Learning-rate schedule (one-cycle)", titlesize=20,
           xlabel="training pass (epoch)", ylabel="learning rate", limits=((0, epochs), (5e-8, 1e-2)), height=380,
           yticks=([1e-7, 1e-6, 1e-5, 1e-4, 1e-3, 1e-2], ["10⁻⁷", "10⁻⁶", "10⁻⁵", "10⁻⁴", "10⁻³", "10⁻²"]), xticks=0:150:750)
t = range(0, 1, length=2000)
lines!(ax2, epochs .* t, lr_at.(t), color=:gold, linewidth=4)
vlines!(ax2, [pct * epochs], color=(:white, 0.4), linestyle=:dash)
text!(ax2, pct * epochs + 8, 3e-3, text="peak 10⁻³ at epoch $(round(Int, pct * epochs))", fontsize=17, color=:gold, align=(:left, :center))
text!(ax2, 12, 6e-6, text="warm-up from 4×10⁻⁵", fontsize=16, color=:white, align=(:left, :center))
text!(ax2, 640, 4e-7, text="anneal to 10⁻⁷", fontsize=16, color=:white, align=(:right, :center))

# --- settings table ---
rows = [("Inputs", "9 viewing-geometry numbers (dot products of the look direction n)"),
        ("Frame", "ecliptic coordinates; x⊕ = Sun → Earth, y⊕ = Earth's motion, z = ecliptic north"),
        ("Network", "4 hidden layers 64-64-32-16, GELU; linear output"),
        ("Loss / optimizer", "mean squared error (MJy/sr)²; Adam"),
        ("Batches", @sprintf("mini-batches of %d pointings (%d updates per epoch)", batch, steps_per_epoch)),
        ("Training", @sprintf("%d epochs = %s updates; one-cycle LR (peak 10⁻³)", epochs, replace(string(S), r"(\d)(?=(\d{3})+$)" => s"\1,"))),
        ("Ensemble", "5 networks (different random seeds), predictions averaged"),
        ("Data", "ZodiPy (Kelsall 1998), 423,607 simulated SPHEREx pointings, 5 μm"),
        ("Test", "whole 30-day months withheld: median error 0.018%, 97.5% within 0.1%")]
gl = fig[1, 2][2, 1] = GridLayout()
for (k, (a, b)) in enumerate(rows)
    Label(gl[k, 1], a, halign=:right, font=:bold, fontsize=18, color=:gold)
    Label(gl[k, 2], b, halign=:left, fontsize=18)
end
colgap!(gl, 18); rowgap!(gl, 8)
resize_to_layout!(fig)
save(joinpath(R, "figures", "10192026_model_card.png"), fig, px_per_unit=2)
println("parameters $nparams, steps/epoch $steps_per_epoch, total updates $S")
