# Exposure-by-exposure values in ONE small patch (a level-9 sub-pixel, ~6.9′ across), in MJy/sr at each exposure's own
# wavelength: the tall table's measured sky (star-masked), SPHEREx's zodi, ZodiPy/Kelsall, our emulator, SPHEREx zodi + b
# and the held-out network (see realdata/tt_match_mjy.jl for the data and the fits).
#     julia --project=. realdata/tt_patch_values.jl [patch subpix]   (default: the |b| > 15° sub-pixel with the most clean exposures)
include(joinpath(@__DIR__, "tt_match_mjy.jl"))
sub = Int.(c("subpix")); tmid = Float64.(c("t_mid_mjd")); wl = Float64.(c("wavelength"))
ok = hiB .& (clean .>= 0.5) .& isfinite.(fm) .& isfinite.(net)
P, Sp = if length(ARGS) >= 2
    parse(Int, ARGS[1]), parse(Int, ARGS[2])
else
    cnt = Dict{Tuple{Int,Int},Int}(); for k in findall(ok); key = (patch[k], sub[k]); cnt[key] = get(cnt, key, 0) + 1; end
    first(sort(collect(cnt), by=last, rev=true))[1]
end
k = findall(ok .& (patch .== P) .& (sub .== Sp)); k = k[sortperm(tmid[k])]
b5 = cvfit(hcat(ones(length(fm)), zcol), fm, ok)   # SPHEREx zodi + b, b fit on the other folds' patches
λecl = atand(sind(mean(ra[k])) * cosd(23.4393) + tand(mean(dec[k])) * sind(23.4393), cosd(mean(ra[k])))
βecl = asind(sind(mean(dec[k])) * cosd(23.4393) - cosd(mean(dec[k])) * sind(23.4393) * sind(mean(ra[k])))
@printf("patch %d, sub-pixel %d: RA %.2f°, Dec %.2f° (Galactic b %.1f°, ecliptic β %.1f°), %d clean exposures, median %.0f%% of pixels unmasked\n",
        P, Sp, mean(ra[k]), mean(dec[k]), mean(gb[k]), βecl, length(k), 100median(clean[k]))
@printf("%-10s %7s %9s %9s %9s %9s %9s %9s\n", "MJD", "λ (μm)", "measured", "SPHEREx", "Kelsall", "ours", "SPHX + b", "network")
for i in k
    @printf("%-10.2f %7.3f %9.4f %9.4f %9.4f %9.4f %9.4f %9.4f\n", tmid[i], wl[i], fm[i], zcol[i], zl[i], ol[i], b5[i], net[i])
end
@printf("%-18s %9s %+9.4f %+9.4f %+9.4f %+9.4f %+9.4f   (median model − measured)\n", "", "",
        (median(p[k] .- fm[k]) for p in (zcol, zl, ol, b5, net))...)
@printf("%-18s %9s %9.4f %9.4f %9.4f %9.4f %9.4f   (median |model − measured|)\n", "", "",
        (median(abs.(p[k] .- fm[k])) for p in (zcol, zl, ol, b5, net))...)
