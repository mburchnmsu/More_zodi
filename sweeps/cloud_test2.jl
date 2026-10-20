# Mentor's validation test 2 (round 26): the poster model without the Earth dot products vs the poster model (both 140 days,
# 750 epochs, 6 month splits × 5 seeds). Sky-error maps side by side + per-shift table + trailing-cloud stack.
#   julia --project=. sweeps/cloud_test2.jl → figures/10212026_cloud_test2_skymap.png, figures/10212026_cloud_test2_stack.png
ENV["ZODI_DATA"] = "z115"
using LinearAlgebra; BLAS.set_num_threads(2)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "configs_v16.jl", "shift_helpers.jl", "r17_20_helpers.jl", "r21_22_helpers.jl")
    include(joinpath(@__DIR__, f))
end
famNE(Δ) = "z115_noEarth_shift$Δ"
fams = ((fam750, "poster model (750 epochs)"), (famNE, "without Earth dot products"))
save(joinpath(@__DIR__, "..", "figures", "10212026_cloud_test2_skymap.png"), skymap_grid_fig(fams); px_per_unit=2)
show(stdout, MIME("text/plain"), m300_table(((fam750, "poster"), (famNE, "noEarth"))); allcols=true); println()
fig, df = trailing_stack_fig(((fam750, 750), (famNE, 751)))     # 751 = label slot for the no-Earth model
save(joinpath(@__DIR__, "..", "figures", "10212026_cloud_test2_stack.png"), fig; px_per_unit=2)
show(stdout, MIME("text/plain"), df; allrows=true); println()
for (fam, lbl) in fams
    S = sky_stats(oos_interior(fam))
    @printf("%-28s median %.4f%%  p95 %.3f%%  |β|<2° %.4f%%  |β|≥60° %.4f%%\n", lbl, S.med, S.p95, S.ecl, S.pole)
end
