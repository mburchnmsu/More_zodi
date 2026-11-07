# Round 46 ablation figure from RESULTS_DIR/r46_summary.csv (written by sweeps/report46.jl). Light: no data loading.
#     julia --project=. sweeps/plot46.jl [tag]      → figures/<tag>_r46_ablation.png
using CairoMakie, DelimitedFiles
function plot46(tag; csv=joinpath(@__DIR__, "results_z500_helio", "r46_summary.csv"))
    A, h = readdlm(csv, ',', header=true); h = vec(h); col(c) = A[:, findfirst(==(c), h)]
    names_ = Dict("full" => "full model", "noS" => "− n·S", "noz" => "− n·z", "noE" => "− n·E", "novS" => "− n·vS",
                  "novE" => "− n·vE", "noxy" => "− n·x⊕, n·y⊕", "noseason" => "− sin/cos λ⊕", "noband" => "− band layer")
    v = String.(col("variant")); o = sortperm(Float64.(col("ratio_to_full"))); v = v[o]; full = findfirst(==("full"), v)
    set_theme!(merge(Theme(fontsize=17), theme_black()))
    fig = Figure(size=(1750, 700))
    for (c, (ttl, cname, lab)) in enumerate((("ensemble test MSE ÷ full model (shifts 0 + 30)", "ratio_to_full", "× full model"),
                                            ("median |error| on the ecliptic (|β| < 2°)", "ecliptic_pct", "%"),
                                            ("median |error|, whole sky", "median_pct", "%")))
        x = Float64.(col(cname))[o]
        ax = Axis(fig[1, c], title=ttl, yticks=(1:length(v), [names_[s] for s in v]), xlabel=lab, xscale=log10)
        barplot!(ax, 1:length(v), x, direction=:x, fillto=minimum(x) / 2, color=[s == "full" ? :orange : :steelblue for s in v])
        vlines!(ax, [x[full]], color=:orange, linestyle=:dash); xlims!(ax, minimum(x) / 2, maximum(x) * 6)
        for (i, xi) in enumerate(x)
            text!(ax, xi, i; text=c == 1 ? (xi < 10 ? string(round(xi, digits=2)) : string(round(Int, xi))) : string(round(xi, digits=4)),
                  align=(:left, :center), offset=(6, 0), fontsize=14, color=:white)
        end
        c > 1 && hideydecorations!(ax, grid=false)
    end
    Label(fig[0, 1:3], "Round 46: the best model with one input (or the band layer) removed — 3 seeds × shifts 0 and 30, withheld months",
          font=:bold, fontsize=20)
    save(joinpath(@__DIR__, "..", "figures", "$(tag)_r46_ablation.png"), fig, px_per_unit=1.5)
end
abspath(PROGRAM_FILE) == (@__FILE__) && plot46(isempty(ARGS) ? "r46" : ARGS[1])
