# Round 30: learnable dust-band layer vs the heliocentric baseline (round 27), poster split; fitted band parameters vs
# Kelsall's values (and the perturbed start).   julia --project=. sweeps/band_compare.jl
ENV["ZODI_DATA"] = "z500"; ENV["ZODI_HELIO"] = "1"
using LinearAlgebra; BLAS.set_num_threads(2)
redirect_stdout(devnull) do
    include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
    for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "shift_helpers.jl"); include(joinpath(@__DIR__, f)); end
    include(joinpath(@__DIR__, "configs_v30.jl"))
end
β = abs.(Float64.(ecliptic_latitude_deg))
for (key, lbl) in (("z500h_noJ_shift0", "heliocentric, no bands (round 27)"), ("z500h_band_kelsall_shift0", "learnable bands, Kelsall start"),
                   ("z500h_band_perturb_shift0", "learnable bands, perturbed start"))
    rs = runs16(key); isempty(rs) && continue
    te = rs[1].te_idx; e = ensemble_pred(rs); rel = abs.(100 .* (e[te] .- y[te]) ./ y[te]); b = β[te]
    @printf("%-36s %d seeds: median %.4f%%  p95 %.3f%%  |β|<2° %.4f%%  |β|≥60° %.4f%%  ens MSE %.2e\n", lbl, length(rs),
            median(rel), quantile(rel, 0.95), median(rel[b .< 2]), median(rel[b .>= 60]), mean(abs2, e[te] .- y[te]))
    if rs[1].arch === :bandmlp
        P = [band_params(r.model[1]) for r in rs]
        for (nm, true_, start) in ((:i, KELSALL_BANDS.i, key == "z500h_band_perturb_shift0" ? PERTURBED_BANDS.i : KELSALL_BANDS.i),
                                   (:Ω, KELSALL_BANDS.Ω, key == "z500h_band_perturb_shift0" ? PERTURBED_BANDS.Ω : KELSALL_BANDS.Ω),
                                   (:δζ, KELSALL_BANDS.δζ, key == "z500h_band_perturb_shift0" ? PERTURBED_BANDS.δζ : KELSALL_BANDS.δζ),
                                   (:v, KELSALL_BANDS.v, key == "z500h_band_perturb_shift0" ? PERTURBED_BANDS.v : KELSALL_BANDS.v))
            M = reduce(hcat, [getfield(p, nm) for p in P])
            println(@sprintf("   %-3s", nm), join([@sprintf("band%d: Kelsall %7.3f, start %7.3f → fitted %7.3f ± %.3f", k, true_[k], start[k],
                                                          mean(M[k, :]), std(M[k, :])) for k in 1:3], " | "))
        end
    end
end
