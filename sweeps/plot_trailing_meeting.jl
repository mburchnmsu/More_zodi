ENV["ZODI_DATA"] = "z115"
using LinearAlgebra; BLAS.set_num_threads(2)
const R = "C:/JuliaProjects/More_zodi"
redirect_stdout(devnull) do
    include("$R/zodi_setup.jl")
    for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "configs_v16.jl", "shift_helpers.jl", "r17_20_helpers.jl", "r21_22_helpers.jl")
        include("$R/sweeps/$f")
    end
end
x = trailing_axes().ahead; ftf = 100 .* TF_EMISSION ./ y
E = oos_interior(fam750); ok = .!isnan.(E)
mf = missing_fraction(fam750, trues(N))
set_theme!(merge(Theme(fontsize=20), theme_black()))
fig = Figure(size=(1300, 1000))
a1 = Axis(fig[1, 1], ylabel="trailing cloud\n(% of the total light)", title="What Kelsall predicts: the Earth-trailing cloud's share of the light",
          xticklabelsvisible=false, limits=((0, 180), (0, 8.5)), xticks=0:30:180)
X, M = gapped(stack(x, ftf, ok)[1:2]...)
band!(a1, X, zero(M), M, color=(:crimson, 0.3)); lines!(a1, X, M, color=:crimson, linewidth=4)
a2 = Axis(fig[2, 1], xlabel="angle between where SPHEREx looks and Earth's direction of motion (°)",
          ylabel="network − ZodiPy (%)", title="What the network leaves behind on months it never saw (750 epochs, mean ± 1 s.e.)",
          limits=((0, 180), (-0.24, 0.10)), xticks=(0:30:180, ["0\nahead of Earth", "30", "60", "90", "120", "150", "180\nbehind Earth"]))
for (frac, ls, lbl) in ((0.01, :dot, "if the network missed 1% of the cloud"), (0.03, :dash, "if it missed 3%"))
    lines!(a2, X, -frac .* (M .- mean(filter(!isnan, M))), color=(:hotpink, 0.9), linewidth=3, linestyle=ls, label=lbl)
end
X2, M2, S2 = gapped(stack(x, E, ok)...)
band!(a2, X2, M2 .- S2, M2 .+ S2, color=(:white, 0.25)); scatterlines!(a2, X2, M2, color=:white, linewidth=3, markersize=8, label="network residual")
hlines!(a2, [0], color=:grey60, linewidth=1.5)
axislegend(a2, position=:lb, labelsize=17)
text!(a2, 0.98, 0.95, space=:relative, align=(:right, :top), fontsize=18,
      text=@sprintf("fitted fraction of the cloud left in the residuals:\n%.2f ± %.2f %%  (< 0.2%% of the cloud)", 100mf.a, 100mf.a_std))
rowsize!(fig.layout, 1, Relative(0.38)); linkxaxes!(a1, a2)
a1.width = 1080; a2.width = 1080
Label(fig[0, 1], "Is the Earth-trailing cloud modelled well?", font=:bold, fontsize=24)
save("$R/figures/10192026_trailing_meeting.png", fig, px_per_unit=2)
@printf("missing fraction %.4f ± %.4f\n", mf.a, mf.a_std)
