# Poster data, part 2: full predicted spectra (best multi-wavelength ensemble, "ep300" = phase coefficients, 300 epochs,
# trained on the 30-day blocks) vs ZodiPy for the 6 reference exposures. Same computation as spectra_fig() in
# sweeps/multi_helpers.jl.   julia --project=. poster/data_spectra.jl  → poster/fig_spectra.jld2
ENV["ZODI_DATA"] = "z115multi"
using LinearAlgebra; BLAS.set_num_threads(2)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl", "extra_splits.jl", "nb_verify_fns.jl", "summary_helpers.jl", "multi_helpers.jl")
    include(joinpath(@__DIR__, "..", "sweeps", f))
end
using JLD2

arm, test = "ep300", "blk"
sp = h5open(joinpath(DATA_DIR, "zodipy115_spectra.h5")) do f
    (; idx=read(f["index_0based"]) .+ 1, w=read(f["wavelength_um"]), y=permutedims(read(f["emission"])), lat=read(f["ecliptic_latitude_deg"]))
end
rs = runs13(arm, test); fn = rs[1].feature_names; cols = [findfirst(==(nm), dot_names_all) for nm in fn]
jl = findfirst(==("logλ"), fn); jc = [findfirst(==("phC$i"), fn) for i in 1:3]
P = similar(sp.y)
for (i, k) in enumerate(sp.idx)
    F = repeat(Fd_raw[k:k, cols], length(sp.w)); F[:, jl] .= log10.(sp.w)
    for j in 1:3; jc[j] === nothing || (F[:, jc[j]] .= [phase_coeffs(w)[j] for w in sp.w]); end
    P[i, :] = vec(mean(reduce(hcat, [Float64.(predict_y(r, Float32.(((F .- r.μ') ./ r.σ')'))) for r in rs]), dims=2))
end
te, fe = fe13(rs)                                       # 30-day-block test error (%), all wavelengths
jldsave(joinpath(@__DIR__, "fig_spectra.jld2"); w=sp.w, ytrue=sp.y, ypred=P, lat=sp.lat, nseeds=length(rs),
        blk_median_pct=median(fe), blk_p95_pct=quantile(fe, 0.95))
@printf("%d seeds; 30-day blocks median %.3f%%, p95 %.2f%%; spectra max |err| per exposure: %s\n", length(rs), median(fe),
        quantile(fe, 0.95), join([@sprintf("%.2f%%", 100maximum(abs.(P[i, :] .- sp.y[i, :]) ./ sp.y[i, :])) for i in 1:6], " "))
