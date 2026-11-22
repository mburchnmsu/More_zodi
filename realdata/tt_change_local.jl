# Week 15 task 6, local test of sweeps/train_change.jl (no cluster): builds data/tt_change_train.* in the same format as
# realdata/tt_change_prep.py from the 192 local patches (data/tt_train, star-masked medians per exposure × level-9 cell).
# Differences from the sky-wide version: the static sky is not removed pixel by pixel (c = the cell's masked median flux,
# scaled to 5 μm with (5/λ)^6.1; the per-cell offset in the loss removes the static sky at the cell level), and cz is the
# cell's median ZODI scaled the same way. Rows with < 50% clean pixels are dropped.
#   1. ephemeris: python -I realdata/exposure_ephem.py data/tt_change_local_times.csv data/tt_change_local_ephem.csv
#      (this script writes the times file first and stops if the ephemeris file is missing)
#   2. julia --project=. realdata/tt_change_local.jl
using DelimitedFiles, Statistics, Printf, LinearAlgebra
const R = normpath(joinpath(@__DIR__, "..")); D = joinpath(R, "data")
T, h = readdlm(joinpath(D, "tt_train", "ttx_L6_g2_sub9_zodipy_ours.csv"), ',', header=true); h = vec(h); c(n) = T[:, findfirst(==(n), h)]
M, hm = readdlm(joinpath(D, "tt_train", "ttx_L6_g2_sub9_mask.csv"), ',', header=true); hm = vec(hm); cm(n) = M[:, findfirst(==(n), hm)]
img = Int.(c("imageid")); tmid = Float64.(c("t_mid_mjd"))
tf = joinpath(D, "tt_change_local_times.csv"); ef = joinpath(D, "tt_change_local_ephem.csv")
if !isfile(ef)
    u = unique(i -> img[i], eachindex(img))
    open(tf, "w") do io; println(io, "imageid,t_beg,t_end"); for i in u; @printf(io, "%d,%.7f,%.7f\n", img[i], tmid[i], tmid[i]); end; end
    println("wrote $tf; now run exposure_ephem.py on it"); exit(0)
end
E, he = readdlm(ef, ',', header=true); he = vec(he)
eph = Dict(Int(E[k, 1]) => k for k in axes(E, 1))
idx = Dict((string(M[k, 1]), string(M[k, 2]), Int(M[k, 3])) => k for k in axes(M, 1))
km = [get(idx, (string(T[k, 1]), string(T[k, 2]), Int(T[k, 3])), 0) for k in axes(T, 1)]
nclean, npix, fclean, zclean, lclean = cm("n_clean"), cm("n_pix"), cm("flux_med_clean"), cm("zodi_med_clean"), cm("wavelength_clean")
ok = [k > 0 && nclean[k] >= 0.5npix[k] && haskey(eph, img[i]) for (i, k) in enumerate(km)]
rows = findall(ok); kk = km[rows]
lam = Float64.(lclean[kk]); fac = (5.0 ./ lam) .^ 6.1
f5 = Float64.(fclean[kk]) .* fac; z5 = Float64.(zclean[kk]) .* fac
ra, dec = Float64.(c("ra"))[rows], Float64.(c("dec"))[rows]
cellid = [parse(Int, last(split(string(T[i, 1]), "_"))) * 1000 + Int(T[i, 3]) for i in rows]   # patch × 1000 + sub-pixel
ε = deg2rad(23.4392911)
n = [(x = cosd(d)cosd(a); y = cosd(d)sind(a); z = sind(d); [x, y * cos(ε) + z * sin(ε), -y * sin(ε) + z * cos(ε)]) for (a, d) in zip(ra, dec)]
er = [eph[img[i]] for i in rows]
S = [Float64.(E[k, 3:5]) for k in er]; v = [(w = Float64.(E[k, 6:8]); w ./ norm(w)) for k in er]
elat = [asind(q[3]) for q in n]; elon = [mod(atand(q[2], q[1]), 360) for q in n]
cols = ["t_mid", "c", "cz", "f5", "z5", "lam", "n_kept", "elon", "elat", "n·S", "n·z", "S·z", "S·S", "n·v", "S·v", "z·v"]
Mx = hcat(tmid[rows] .- 60000, f5, z5, f5, z5, lam, Float64.(nclean[kk]), elon, elat,
          dot.(n, S), getindex.(n, 3), getindex.(S, 3), dot.(S, S), dot.(n, v), dot.(S, v), getindex.(v, 3))
o = sortperm(collect(zip(cellid, tmid[rows])))
write(joinpath(D, "tt_change_train.f32"), Float32.(Mx[o, :]'))
write(joinpath(D, "tt_change_train.cell"), Int64.(cellid[o]))
open(joinpath(D, "tt_change_train.cols"), "w") do io; foreach(x -> println(io, x), cols); end
@printf("%d rows, %d cells -> data/tt_change_train.* (local test set)\n", length(o), length(unique(cellid)))
