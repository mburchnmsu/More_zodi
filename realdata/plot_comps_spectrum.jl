# k (how much each Kelsall component is too faint) against wavelength, from the per-window fits of realdata/offset_comps.jl.
#     julia --project=. realdata/plot_comps_spectrum.jl [tag [LEVEL G]]  → figures/<tag>_offset_comps_spectrum_L<LEVEL>_grid<G>.png
using DelimitedFiles, CairoMakie
tag = length(ARGS) >= 1 ? ARGS[1] : "talltable"; LEVEL, G = length(ARGS) >= 3 ? parse.(Int, ARGS[2:3]) : (6, 1)
D = joinpath(@__DIR__, "..", "data", "spherex_real")
files = filter(f -> occursin(Regex("^ttbin_L$(LEVEL)_grid$(G)(_w[0-9.]+)?_comps_fit\\.csv\$"), f), readdir(D))
lamof(f) = (m = match(r"_w([0-9.]+)_comps", f); m === nothing ? 4.95 : parse(Float64, m[1]) + 0.05)
files = sort(files, by=lamof); lam = lamof.(files)
tabs = [readdlm(joinpath(D, f), ',', header=true) for f in files]
get(c, row) = [Float64(t[1][row, findfirst(==(c), vec(t[2]))]) for t in tabs]
set_theme!(merge(Theme(fontsize=17), theme_black()))
fig = Figure(size=(1900, 560))
for (j, (row, ttl)) in enumerate(((1, "smooth cloud"), (2, "dust bands"), (3, "ring"), (4, "trailing feature")))
    ax = Axis(fig[1, j], title=ttl, xlabel="wavelength (μm)", ylabel=j == 1 ? "k (fraction too faint)" : "")
    for (c, e, col, dx, lbl) in (("kA", "kA_err", :white, -0.05, "(A) across the sky"), ("kB", "kB_err", :deepskyblue, 0.0, "(B) over time"),
                                 ("kB_spherex", "kB_spherex_err", :orange, 0.05, "(B), SPHEREx zodi model as the sky"))
        errorbars!(ax, lam .+ dx, get(c, row), get(e, row), color=col); scatter!(ax, lam .+ dx, get(c, row), color=col, markersize=11, label=lbl)
    end
    hlines!(ax, [0], color=(:grey, 0.6))
    j == 1 && axislegend(ax, position=:rb, labelsize=13)
    j > 1 && ylims!(ax, -2.5, 3.5)
end
Label(fig[0, 1:4], "Which Kelsall component is too faint? measured − Kelsall = const + Σ k · component, at each wavelength ($(size(tabs[1][1], 1) - 1) components, grid $G)",
      font=:bold, fontsize=19)
save(joinpath(@__DIR__, "..", "figures", "$(tag)_offset_comps_spectrum_L$(LEVEL)_grid$(G).png"), fig, px_per_unit=1.5)
println("ok")
