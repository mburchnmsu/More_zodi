# Check the round-24 splits on the 500-day data: sizes, number of held-out windows, which windows are at the ends,
# and how often each day is tested across the 6 shifted versions.   julia --project=. sweeps/split_check24.jl
ENV["ZODI_DATA"] = "z500"
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
include(joinpath(@__DIR__, "configs_v24.jl"))
@printf("\n%d exposures over %.2f days\n", N, span_days)
ntest = zeros(Int, N)
for Δ in SHIFTS24
    tr, te = shifted_30day_split24(Δ)
    k = floor.(Int, (t_rel[te] .- Δ) ./ 30); ks = sort(unique(k))
    edge = [(30kk + Δ <= 0) || (30(kk + 1) + Δ >= span_days) for kk in ks]
    ntest[te] .+= 1
    @printf("shift %2d d: train %7d, test %7d (%.0f%%), %d held-out windows (%d at an end: %s)\n", Δ, length(tr), length(te),
            100length(te) / N, length(ks), sum(edge),
            join([@sprintf("%d–%d", max(0, 30kk + Δ), min(round(Int, span_days), 30(kk + 1) + Δ)) for (kk, e) in zip(ks, edge) if e], ", "))
end
for (a, b) in ((0, 30), (30, 60))
    _, te_a = shifted_30day_split24(a); _, te_b = shifted_30day_split24(b)
    @printf("shifts %d + %d: overlap %d, together cover %.2f%% of exposures\n", a, b, length(intersect(te_a, te_b)), 100length(union(te_a, te_b)) / N)
end
println("times each exposure is tested across the 6 shifts: ", sort(collect(countmap(ntest))))
