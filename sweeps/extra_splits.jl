# Round 8 (2026-10-10) extra train/test splits, added to the `splits` Dict from zodi_setup.jl.
#  • block-length sweep: alternating train/test windows of L days (time-based, like "30 day split")
#  • sky-patch holdouts: every exposure within 12° of a centre direction is TEST (for the whole mission)
#  • learning curve: random subsets of the 30-day-split TRAINING rows (same test blocks)
for L in (1, 3, 15, 45)
    splits["$L-day alternating"] = alternating_time_split(Float64(L))
end
const BLOCK_LENGTHS = [(1, "1-day alternating"), (3, "3-day alternating"), (7, "7-day alternating"),
                       (15, "15-day alternating"), (30, "30 day split"), (45, "45-day alternating")]

const PATCH_RADIUS = 12.0
const PATCHES = [("ecliptic", 210.0, 0.0), ("mid-latitude", 180.0, 45.0), ("near north pole", 240.0, 75.0)]
patch_dist(lonc, latc) = acosd.(clamp.(vec([cosd(latc) * cosd(lonc) cosd(latc) * sind(lonc) sind(latc)] * nvec_unit_cartesian), -1, 1))
for (nm, lonc, latc) in PATCHES
    d = patch_dist(lonc, latc)
    splits["patch $nm"] = (findall(d .> PATCH_RADIUS), findall(d .<= PATCH_RADIUS))
end

const LC_FRACTIONS = [0.01, 0.03, 0.1, 0.3, 1.0]
let (tr, te) = splits["30 day split"]
    for f in LC_FRACTIONS[1:end-1]
        sub = sort(sample(Xoshiro(99), tr, round(Int, f * length(tr)), replace=false))
        splits["30 day split frac $f"] = (sub, te)
    end
end
lc_split(f) = f == 1.0 ? "30 day split" : "30 day split frac $f"
