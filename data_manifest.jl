# Data manifest: which HDF5 data files exist, their SHA-256 fingerprints, and where each came from.
# data/*.h5 are not in git (size); data/MANIFEST.tsv is — so every machine (laptop, 2nd PC, cluster) can check it has
# exactly the data a result was made with.
#   julia --project=. data_manifest.jl            # check the local data/ against data/MANIFEST.tsv
#   julia --project=. data_manifest.jl --write    # (re)write the manifest from the local files (after making new data)
using SHA, HDF5, Printf, Dates

const DDIR = joinpath(@__DIR__, "data")
const MAN  = joinpath(DDIR, "MANIFEST.tsv")
# which ZODI_DATA mode reads which file, and how to recreate it (the original files came from the mentor's pipeline)
const ROLE = Dict(
    "boresight_pointing.h5"                                           => ("all", "original (mentor pipeline, 2025-10-30)"),
    "spherex_vectors_bore_interpolated.h5"                            => ("original, z115", "original (mentor pipeline, 2025-11-24)"),
    "spherex_zodipy_5um_boresight_interpolated.h5"                    => ("original", "original (mentor pipeline, 2025-11-24) — has 2 generation errors, see zodipy_gen/reproduce_original.py"),
    "spherex_zodipy_5um_boresight_healpix_components_interpolated.h5" => ("original", "original (mentor pipeline)"),
    "zodipy115_5um_boresight.h5"                                      => ("z115", "zodipy_gen/generate.py"),
    "zodipy115_5um_healpix_components.h5"                             => ("z115, z115year", "zodipy_gen/generate.py"),
    "zodipy115_future.h5"                                             => ("z115 (extrapolation test)", "zodipy_gen/generate_future.py"),
    "z115year_pointing.h5"                                            => ("z115year", "zodipy_gen/generate_year.py"),
    "z115year_vectors.h5"                                             => ("z115year", "zodipy_gen/generate_year.py"),
    "z115year_boresight.h5"                                           => ("z115year", "zodipy_gen/generate_year.py"),
)
sha256file(p) = open(io -> bytes2hex(sha256(io)), p)
created(p) = try
    h5open(p) do f
        haskey(f, "metadata") && haskey(attrs(f["metadata"]), "created") ? string(attrs(f["metadata"])["created"]) : ""
    end
catch; "" end

function write_manifest()
    files = sort(filter(f -> endswith(f, ".h5"), readdir(DDIR)))
    open(MAN, "w") do io
        println(io, "# data/MANIFEST.tsv — written $(Dates.format(now(), "yyyy-mm-dd HH:MM")) by data_manifest.jl. Check: julia --project=. data_manifest.jl")
        println(io, join(("file", "bytes", "sha256", "created", "used_by_ZODI_DATA", "made_by"), '\t'))
        for f in files
            p = joinpath(DDIR, f); role, src = get(ROLE, f, ("?", "?"))
            println(io, join((f, filesize(p), sha256file(p), created(p), role, src), '\t'))
            @printf("  %-66s %10d bytes  %s…\n", f, filesize(p), first(sha256file(p), 12))
        end
    end
    println("wrote $(relpath(MAN)) ($(length(files)) files)")
end

function check_manifest()
    isfile(MAN) || error("no data/MANIFEST.tsv — run with --write first")
    rows = [split(l, '\t') for l in readlines(MAN) if !startswith(l, "#") && !startswith(l, "file\t")]
    bad = 0
    for r in rows
        f, bytes, h = r[1], parse(Int, r[2]), r[3]; p = joinpath(DDIR, f)
        status = !isfile(p) ? "MISSING" : filesize(p) != bytes ? "SIZE DIFFERS" : sha256file(p) != h ? "CONTENT DIFFERS" : "ok"
        status == "ok" || (bad += 1)
        @printf("  %-16s %s\n", status, f)
    end
    extra = setdiff(filter(f -> endswith(f, ".h5"), readdir(DDIR)), first.(rows))
    foreach(f -> @printf("  %-16s %s\n", "NOT IN MANIFEST", f), extra)
    println(bad == 0 ? "all $(length(rows)) manifest files present and identical" : "$bad file(s) missing or different")
    bad == 0
end

"--write" in ARGS ? write_manifest() : (check_manifest() || exit(1))
