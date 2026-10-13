# ==============================================================================
# RUNG 3 — ALL-SKY OUT-OF-DISTRIBUTION TEST with a seed ensemble
#   julia allsky.jl <result_prefix>      e.g.  julia allsky.jl final_base
# Loads every results/<prefix>_s*.jls, evaluates each model on the full HEALPix sky
# (nside 256) at the single epoch TINDX, and compares with the Kelsall truth.
# Reports in-domain vs out-of-domain error, ensemble spread, per-component residual
# correlations, and Mollweide maps.
# ==============================================================================
using LinearAlgebra; BLAS.set_num_threads(2)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
include(joinpath(@__DIR__, "mb_train.jl"))
include(joinpath(@__DIR__, "extra_features.jl"))
using Serialization, Healpix
RES    = joinpath(@__DIR__, "results")
prefix = ARGS[1]
files  = sort(filter(f -> startswith(f, prefix * "_s") && endswith(f, ".jls"), readdir(RES)))
members = [deserialize(joinpath(RES, f)) for f in files]
println("ensemble of $(length(members)) models: ", join(files, ", "))
r1 = members[1]

# --- truth and sky geometry -------------------------------------------------
TINDX = 13170
sky = h5open(allsky_file) do f
    (; emission = read(f["emission"]), pixels = read(f["pixels"]) .+ 1,
       lon = read(f["ecliptic_longitude_deg"]), lat = read(f["ecliptic_latitude_deg"]),
       comps = Dict("smooth cloud"   => read(f["emission_smooth_cloud"]),
                    "dust band 1"    => read(f["emission_dust_band_1"]),
                    "dust band 2"    => read(f["emission_dust_band_2"]),
                    "dust band 3"    => read(f["emission_dust_band_3"]),
                    "circumsolar ring" => read(f["emission_circum_solar_ring"]),
                    "Earth-trailing" => read(f["emission_earth_trailing_feature"])))
end
npix = length(sky.pixels)
nvec_sky = vcat((cosd.(sky.lat) .* cosd.(sky.lon))', (cosd.(sky.lat) .* sind.(sky.lon))', sind.(sky.lat)')
names_sky, Fd_sky = dot_features(make_vectors(nvec_sky, fill(TINDX, npix)))
Fd_sky   = hcat(Fd_sky, extra_columns(nvec_sky, fill(TINDX, npix)))   # n·δ̂, Jupiter axes — same as training
append!(names_sky, EXTRA_NAMES)
@assert names_sky == dot_names_all "sky feature names must match training feature names"
S_hat = spherex_positions[:, TINDX] ./ norm(spherex_positions[:, TINDX])
elong_sky = acosd.(clamp.(-(nvec_sky' * S_hat), -1, 1))
@printf("epoch TINDX=%d is t_rel = %.2f days (training covers %.1f–%.1f)\n", TINDX, t_rel[TINDX],
        extrema(t_rel[r1.tr_idx])...)

# --- ensemble prediction ------------------------------------------------------
cols  = [findfirst(==(nm), dot_names_all) for nm in r1.feature_names]
preds = map(members) do r
    X = Float32.(((Fd_sky[:, cols] .- r.μ') ./ r.σ')')
    Float64.(predict_y(r, X))          # handles log-target models (exp back to MJy/sr)
end
P      = reduce(hcat, preds)
y_pred = vec(mean(P, dims=2))
y_std  = vec(std(P, dims=2))
y_true = sky.emission
res    = y_pred .- y_true

# --- in-domain mask: every feature inside its TRAINING range --------------------
in_dom = trues(npix)
for c in cols
    lo, hi = extrema(Fd_raw[r1.tr_idx, c])
    in_dom .&= lo .<= Fd_sky[:, c] .<= hi
end
rms(v) = sqrt(mean(abs2, v))
@printf("\nin-domain:     %5.1f%% of sky | rms %.4f MJy/sr | median |frac err| %.2f%% | ensemble std median %.4f\n",
        100mean(in_dom), rms(res[in_dom]), 100median(abs.(res[in_dom]) ./ y_true[in_dom]), median(y_std[in_dom]))
@printf("out-of-domain: %5.1f%% of sky | rms %.4f MJy/sr | median |frac err| %.2f%% | ensemble std median %.4f\n",
        100mean(.!in_dom), rms(res[.!in_dom]), 100median(abs.(res[.!in_dom]) ./ y_true[.!in_dom]), median(y_std[.!in_dom]))
@printf("negative ensemble predictions: %d in-domain, %d out-of-domain (min prediction %.3f MJy/sr)\n",
        count(<(0), y_pred[in_dom]), count(<(0), y_pred[.!in_dom]), minimum(y_pred))
@printf("whole-sky median |frac err| %.2f%%; within 60° of the Sun %.1f%%\n",
        100median(abs.(res) ./ y_true), 100median((abs.(res) ./ y_true)[elong_sky .< 60]))
@printf("in-domain elongation range %.1f°–%.1f° ; truth range in-domain %.3f–%.3f MJy/sr\n",
        extrema(elong_sky[in_dom])..., extrema(y_true[in_dom])...)
@printf("does ensemble spread track error? corr(|res|, std): in-domain %.2f, all-sky %.2f\n",
        cor(abs.(res[in_dom]), y_std[in_dom]), cor(abs.(res), y_std))
println("\nresidual correlation with each Kelsall component (in-domain pixels):")
for (nm, comp) in sort(collect(sky.comps), by=first)
    @printf("  %-17s r = %+.2f\n", nm, cor(res[in_dom], comp[in_dom]))
end
println("(for reference, single members' in-domain rms: ",
        join([@sprintf("%.4f", rms(p[in_dom] .- y_true[in_dom])) for p in preds], ", "), ")")

# --- Mollweide maps (ecliptic, lon 0 at centre increasing left) -----------------
nside = Healpix.npix2nside(npix); hres = Healpix.Resolution(nside)
function moll_img(vals_by_row; nx=1400, ny=700)
    m = fill(NaN, npix); m[sky.pixels] .= vals_by_row
    xs = range(-2√2, 2√2, length=nx); ys = range(-√2, √2, length=ny)
    img = fill(NaN, nx, ny)
    for (j, yv) in enumerate(ys), (i, xv) in enumerate(xs)
        abs(yv) > √2 && continue
        θ = asin(yv / √2); lon = -rad2deg(π * xv / (2√2 * cos(θ)))
        abs(lon) > 180 && continue
        lat = asind(clamp((2θ + sin(2θ)) / π, -1, 1))
        img[i, j] = m[Healpix.ang2pixRing(hres, deg2rad(90 - lat), deg2rad(mod(lon, 360)))]
    end
    xs, ys, img
end
function panel!(fig, pos, vals, title, cmap, cr, label)
    ax = Axis(fig[pos...], title=title, aspect=DataAspect()); hidedecorations!(ax); hidespines!(ax)
    xs, ys, img = moll_img(vals)
    hm = heatmap!(ax, xs, ys, img, colormap=cmap, colorrange=cr, nan_color=(:grey30, 1.0),
                  lowclip=cgrad(cmap)[0.0], highclip=cgrad(cmap)[1.0])
    Colorbar(fig[pos[1], pos[2] + 1], hm, label=label, height=Relative(0.8))
end
cr_true = (log10(minimum(y_true)), log10(quantile(y_true, 0.995)))
res_lim = quantile(abs.(res[in_dom]), 0.99)
fig = Figure(size=(1500, 1250), fontsize=13)
panel!(fig, (1, 1), log10.(y_true),               "Kelsall truth, log₁₀ MJy/sr (epoch $TINDX)", :inferno, cr_true, "log₁₀ MJy/sr")
panel!(fig, (1, 3), log10.(max.(y_pred, 1e-3)),   "Ensemble prediction, log₁₀ MJy/sr", :inferno, cr_true, "log₁₀ MJy/sr")
panel!(fig, (2, 1), ifelse.(in_dom, res, NaN),    "Residual (pred − true), IN-DOMAIN only", ColorSchemes.diverging_bkr_55_10_c35_n256, (-res_lim, res_lim), "MJy/sr")
panel!(fig, (2, 3), res ./ y_true,                "Fractional residual, whole sky (clipped ±50%)", ColorSchemes.diverging_bkr_55_10_c35_n256, (-0.5, 0.5), "(pred − true)/true")
panel!(fig, (3, 1), log10.(max.(y_std, 1e-5)),    "Ensemble spread (std across seeds), log₁₀", :viridis, (-3.5, 0.5), "log₁₀ MJy/sr")
panel!(fig, (3, 3), Float64.(in_dom),             "In-domain mask (all features inside training range)", :grays, (0, 1), "in domain")
Label(fig[0, :], "Rung 3 — all-sky test, $(length(members))-seed ensemble ($(prefix))", fontsize=18, font=:bold)
save(joinpath(RES, "allsky_$(prefix)_maps.png"), fig)

# error and spread vs solar elongation — where does it break?
fig2 = Figure(size=(1000, 420), fontsize=13)
ax = Axis(fig2[1, 1], xlabel="solar elongation at TINDX (°)", ylabel="|pred − true| / true", yscale=log10,
          title="Fractional error (dots) and ensemble spread/true (line) vs elongation")
sub = sort(sample(Xoshiro(3), 1:npix, 60_000, replace=false))
scatter!(ax, elong_sky[sub], max.(abs.(res[sub]) ./ y_true[sub], 1e-6), markersize=1.5,
         color=ifelse.(in_dom[sub], :deepskyblue, :orangered))
bins = 0:2:180; mids = bins[1:end-1] .+ 1
sp = [let m = (elong_sky .>= bins[i]) .& (elong_sky .< bins[i+1]); any(m) ? median(y_std[m] ./ y_true[m]) : NaN end for i in 1:length(mids)]
lines!(ax, mids, max.(sp, 1e-6), color=:white, linewidth=2)
vspan!(ax, [extrema(elong_sky[in_dom])[1]], [extrema(elong_sky[in_dom])[2]], color=(:white, 0.08))
save(joinpath(RES, "allsky_$(prefix)_vs_elong.png"), fig2)
println("\nall-sky done")
