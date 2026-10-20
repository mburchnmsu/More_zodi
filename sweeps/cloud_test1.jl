# Mentor's validation test 1 (Oct 20): remake the trailing-cloud plots with the Earth-linked dust REMOVED (Kelsall's
# circumsolar ring + Earth-trailing blob, both stored per pointing in the corrected 140-day data). No new ZodiPy runs.
#   (a) mean ZodiPy brightness vs angle from Earth's motion: full model vs model without ring + blob;
#   (b) the shares of the blob and the ring vs angle (with them removed, both are zero by construction);
#   (c) the poster network (750 epochs, trained WITH the cloud) minus the cloud-free ZodiPy, on pointings it never saw:
#       if the network learned the cloud, this reproduces the ring + blob curve.
#   julia --project=. sweeps/cloud_test1.jl → figures/10202026_cloud_test1.png
ENV["ZODI_DATA"] = "z115"
using LinearAlgebra; BLAS.set_num_threads(2)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "configs_v16.jl", "shift_helpers.jl", "r17_20_helpers.jl", "r21_22_helpers.jl")
    include(joinpath(@__DIR__, f))
end
blob = h5open(f -> read(f["emission_earth_trailing_feature"]), emission_file)
ring = h5open(f -> read(f["emission_circum_solar_ring"]), emission_file)
ync = y .- blob .- ring                                       # ZodiPy without the Earth-linked dust
x = trailing_axes().ahead                                     # angle between pointing and Earth's motion (°)
E = oos_interior(fam750); P = y .* (1 .+ E ./ 100); ok = .!isnan.(E)   # the poster network's out-of-sample prediction
set_theme!(merge(Theme(fontsize=18), theme_black()))
fig = Figure(size=(1700, 1150))
a1 = Axis(fig[1, 1], ylabel="mean brightness (MJy/sr)", title="(a) ZodiPy brightness, with and without the Earth-linked dust")
for (v, col, lbl) in ((y, :white, "full Kelsall model"), (ync, :deepskyblue, "without ring + trailing blob"))
    X, M = gapped(stack(x, v, ok)[1:2]...); scatterlines!(a1, X, M, color=col, linewidth=3, markersize=6, label=lbl)
end
axislegend(a1, position=:rt)
a2 = Axis(fig[1, 2], ylabel="share of the total (%)", title="(b) what was removed")
for (v, col, lbl) in ((100 .* blob ./ y, :hotpink, "trailing blob"), (100 .* ring ./ y, :gold, "circumsolar ring"))
    X, M = gapped(stack(x, v, ok)[1:2]...); scatterlines!(a2, X, M, color=col, linewidth=3, markersize=6, label=lbl)
end
axislegend(a2, position=:lt)
a3 = Axis(fig[2, 1:2], xlabel="angle between the pointing vector and Earth's direction of motion (°): 0 = ahead, 180 = behind",
          ylabel="share of the total (%)",
          title="(c) the poster network minus cloud-free ZodiPy (pointings it never saw) vs the true ring + blob share")
X, M = gapped(stack(x, 100 .* (blob .+ ring) ./ y, ok)[1:2]...)
lines!(a3, X, M, color=:hotpink, linewidth=6, label="true ring + blob (ZodiPy)")
X, M, S = gapped(stack(x, 100 .* (P .- ync) ./ y, ok)...)
band!(a3, X, M .- S, M .+ S, color=(:white, 0.3)); scatterlines!(a3, X, M, color=:white, linewidth=2.5, markersize=6,
                                                               label="network − cloud-free ZodiPy")
axislegend(a3, position=:lt)
for a in (a1, a2, a3); xlims!(a, 0, 180); end
Label(fig[0, 1:2], "Validation test 1: is the trailing-cloud signal real? (140-day data, poster model, 750 epochs)", font=:bold, fontsize=22)
save(joinpath(@__DIR__, "..", "figures", "10202026_cloud_test1.png"), fig, px_per_unit=2)
d = (P .- ync) .- (blob .+ ring)
@printf("network − cloud-free ZodiPy vs true ring+blob: mean difference %.2e MJy/sr (%.4f%% of the total), rms %.2e\n",
        mean(d[ok]), 100mean(d[ok] ./ y[ok]), sqrt(mean(abs2, d[ok])))
