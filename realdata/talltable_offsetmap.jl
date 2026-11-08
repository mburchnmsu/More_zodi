# The mentor's mean-sky question on real data: for every tall-table patch of a grid (realdata/talltable_bins.py ... grid G,
# then realdata/talltable_zodipy.py on each), how much brighter is the measured sky than our model (= Kelsall), and does that
# offset follow the ecliptic (zodi Kelsall misses) or the Galaxy (a fixed sky in l, b)?
# Per patch: b1 = median(measured − ours) (scale fixed at 1; works with few exposures), and where the patch has enough
# spread over time, the robust fit measured = a·ours + b. Our model: the 30 networks of rounds 37–38 (cos×exp 1000),
# geometry from the nearest simulated exposure, moved to each exposure's wavelength with ZodiPy's spectral shape — exactly
# as realdata/talltable_ours.jl, but loading the networks once.
#     julia --project=. realdata/talltable_offsetmap.jl LEVEL G [tag [wtag]]
#         → data/spherex_real/ttbin_L<LEVEL>_grid<G><wtag>_offsets.csv, figures/<tag>_offsetmap_L<LEVEL>_grid<G><wtag>.png, and per
#           patch ttbin_L<LEVEL>_<name><wtag>_ours.csv: every exposure with our model next to the measured flux, the SPHEREx zodi
#           column and ZodiPy (the mentor's "replace the ZodiPy column with ours"). wtag: a wavelength window of
#           realdata/talltable_bins.py (TT_LAM), e.g. _w1.25; default the 4.9–5.1 μm files.
ENV["ZODI_DATA"] = "z500"; ENV["ZODI_HELIO"] = "1"
using LinearAlgebra; BLAS.set_num_threads(2)
redirect_stdout(devnull) do
    include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
    for f in ("mb_train.jl", "extra_features.jl", "summary_helpers.jl", "shift_helpers.jl"); include(joinpath(@__DIR__, "..", "sweeps", f)); end
    include(joinpath(@__DIR__, "..", "sweeps", "configs_v24.jl"))
    include(joinpath(@__DIR__, "..", "sweeps", "plot_sky_common.jl"))
end
using DelimitedFiles, Serialization, CairoMakie
LEVEL, G = parse(Int, ARGS[1]), parse(Int, ARGS[2]); tag = length(ARGS) >= 3 ? ARGS[3] : "talltable"
wtag = length(ARGS) >= 4 ? ARGS[4] : ""
D = joinpath(@__DIR__, "..", "data", "spherex_real")
C, ch = readdlm(joinpath(D, "ttbin_L$(LEVEL)_grid$(G)_centres.csv"), ',', header=true)
names_, RA, DEC = String.(C[:, 1]), Float64.(C[:, 2]), Float64.(C[:, 3])

# the 30 networks, kept small (model + normalisation only)
nets = map(["z500h_bandplx_cosexp1k_shift$(Δ)_s$s" for Δ in SHIFTS24 for s in 42:46]) do nm
    r = deserialize(joinpath(RESULTS_DIR, nm * ".jls"))
    (; model=r.model, μ=r.μ, σ=r.σ, target=get(r, :target, :linear),
       cols=[findfirst(==(c), dot_names_all) for c in r.feature_names])
end
GC.gc()
o = sortperm(times); ts = times[o]
nearest(jd) = map(jd) do t
    k = clamp(searchsortedfirst(ts, t), 2, length(ts)); o[abs(ts[k] - t) < abs(ts[k-1] - t) ? k : k - 1]
end
ε = deg2rad(23.43929111)
icrs(ra, dec) = [cosd(dec) * cosd(ra), cosd(dec) * sind(ra), sind(dec)]
ecl(q) = [q[1], cos(ε) * q[2] + sin(ε) * q[3], -sin(ε) * q[2] + cos(ε) * q[3]]
const RG = [-0.0548755604162154 -0.8734370902348850 -0.4838350155487132    # ICRS → Galactic (Hipparcos)
             0.4941094278755837 -0.4448296299600112  0.7469822444972189
            -0.8676661490190047 -0.1980763734312015  0.4559837761750669]
function ours5(mjd, ra, dec)
    idx = nearest(mjd .+ 2400000.5); nT = repeat(ecl(icrs(ra, dec)), 1, length(mjd))
    F = hcat(dot_features(make_vectors(nT, idx))[2], extra_columns(nT, idx))
    P = reduce(hcat, [to_y(n.target, predict_batched(n.model, Float32.(((F[:, n.cols] .- n.μ') ./ n.σ')'))) for n in nets])
    vec(mean(P, dims=2)), 1440 .* abs.(times[idx] .- (mjd .+ 2400000.5))
end
mad(v) = 1.4826median(abs.(v .- median(v)))
function fitab(m, f)
    A = [m ones(length(m))]; k = trues(length(m)); p = zeros(2)
    for _ in 1:5
        p = A[k, :] \ f[k]; r = f .- A * p; k = abs.(r) .< 4max(mad(r[k]), 1e-6)
    end
    A[k, :] \ f[k]
end

rows = []
for (i, nm) in enumerate(names_)
    file = joinpath(D, "ttbin_L$(LEVEL)_$(nm)$(wtag)_zodipy.csv"); isfile(file) || continue
    T, h = readdlm(file, ',', header=true); h = vec(h); size(T, 1) == 0 && continue
    col(c) = Float64.(T[:, findfirst(==(c), h)])
    mjd, flux, zcol, zl, z5 = col("t_mid_mjd"), col("flux_median"), col("zodi_median"), col("zodipy_lam"), col("zodipy_5um")
    o5, dtm = ours5(mjd, RA[i], DEC[i]); ours = o5 .* zl ./ z5
    open(joinpath(D, "ttbin_L$(LEVEL)_$(nm)$(wtag)_ours.csv"), "w") do f
        println(f, "imageid,t_mid_mjd,wavelength,flux_median,zodi_spherex,zodipy_lam,ours_lam,ours_5um,zodipy_5um,dt_match_min")
        for k in eachindex(mjd)
            @printf(f, "%s,%.6f,%.4f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.2f\n", (x = T[k, findfirst(==("imageid"), h)]; x isa Real ? string(round(Int, x)) : string(x)), mjd[k],
                    col("wavelength")[k], flux[k], zcol[k], zl[k], ours[k], o5[k], z5[k], dtm[k])
        end
    end
    q = icrs(RA[i], DEC[i]); β = asind(ecl(q)[3]); g = RG * q; b = asind(g[3]); l = mod(atand(g[2], g[1]), 360)
    λ = mod(atand(ecl(q)[2], ecl(q)[1]), 360)
    b1 = median(flux .- ours); spreadt = quantile(ours, 0.9) - quantile(ours, 0.1)
    a_, b_ = (length(mjd) >= 10 && spreadt > 0.03) ? fitab(ours, flux) : (NaN, NaN)
    push!(rows, (; name=nm, ra=RA[i], dec=DEC[i], λ, β, l, b, n=length(mjd), ours_med=median(ours), flux_med=median(flux),
                  b1, b1_rel=b1 / median(ours), b1_spheres=median(flux .- zcol), a=a_, bfit=b_, resid=mad(flux .- ours .- b1),
                  ours_vs_zodipy=median(100 .* (o5 .- z5) ./ z5), dt_max=maximum(dtm)))
end
@printf("%d of %d patches with data\n", length(rows), length(names_))
out = joinpath(D, "ttbin_L$(LEVEL)_grid$(G)$(wtag)_offsets.csv")
open(out, "w") do f
    ks = keys(rows[1]); println(f, join(ks, ","))
    for r in rows; println(f, join((v isa AbstractFloat ? @sprintf("%.6g", v) : string(v) for v in values(r)), ",")); end
end
println("→ ", out)
println("ours vs ZodiPy at 5 μm over all patches: max |median| ", @sprintf("%.3f%%", maximum(abs(r.ours_vs_zodipy) for r in rows)))
get(f) = [getfield(r, f) for r in rows]
cor_(x, y) = (k = .!isnan.(x) .& .!isnan.(y); cor(x[k], y[k]))
@printf("offset b1 (MJy/sr): median %.4f, range %.4f–%.4f; correlation with |β| %+.2f, with |b| %+.2f, with ours %+.2f\n",
        median(get(:b1)), extrema(get(:b1))..., cor_(get(:b1), abs.(get(:β))), cor_(get(:b1), abs.(get(:b))), cor_(get(:b1), get(:ours_med)))

set_theme!(merge(Theme(fontsize=17), theme_black()))
fig = Figure(size=(2200, 1300))
cr = (0.0, quantile(get(:b1), 0.95))
for (c, (ttl, lon, lat)) in enumerate((("ecliptic frame", get(:λ), get(:β)), ("Galactic frame", get(:l), get(:b))))
    ax = Axis(fig[1, c], aspect=DataAspect(), title="offset measured − our model (MJy/sr), $ttl"); hidedecorations!(ax); hidespines!(ax)
    lines!(ax, [Point2f(moll_fwd(L, B)...) for (L, B) in [(x, 0.0) for x in range(-179.99, 179.99, length=361)]], color=(:white, 0.4))
    graticule!(ax)
    p = [Point2f(moll_fwd(L, B)...) for (L, B) in zip(lon, lat)]
    global sc = scatter!(ax, p, color=get(:b1), colormap=:magma, colorrange=cr, markersize=26, strokecolor=:white, strokewidth=0.5)
end
Colorbar(fig[1, 3], sc, label="median(measured − ours), MJy/sr")
ax3 = Axis(fig[2, 1], xlabel="|ecliptic latitude| (°)", ylabel="offset (MJy/sr)")
ax4 = Axis(fig[2, 2], xlabel="|Galactic latitude| (°)", ylabel="offset (MJy/sr)")
for (ax, x) in ((ax3, abs.(get(:β))), (ax4, abs.(get(:b))))
    scatter!(ax, x, get(:b1), color=:white, markersize=12, label="ours (= Kelsall)")
    scatter!(ax, x, get(:b1_spheres), color=:orange, markersize=9, label="SPHEREx zodi model")
end
axislegend(ax3, position=:rt)
lamlbl = isempty(wtag) ? "4.9–5.0 μm" : "$(wtag[3:end]) μm window"
Label(fig[0, 1:3], "Tall table, $lamlbl: how much brighter the real sky is than the zodi models (one 0.$(LEVEL == 8 ? "23" : "92")° patch per grid point)",
      font=:bold, fontsize=21)
save(joinpath(@__DIR__, "..", "figures", "$(tag)_offsetmap_L$(LEVEL)_grid$(G)$(wtag).png"), fig, px_per_unit=1.5)
println("ok")
