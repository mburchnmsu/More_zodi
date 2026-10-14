# Round 10 helpers (corrected ZodiPy-1.1.5 target + extrapolation in time) for the 10142026 notebook.
# Requires ENV["ZODI_DATA"] = "z115" before zodi_setup.jl, then mb_train.jl, extra_features.jl, extra_splits.jl,
# nb_verify_fns.jl, summary_helpers.jl, and pipeline/ZodiPipeline.jl (using .ZodiPipeline).
@assert ZODI_DATA == "z115" "z115_helpers.jl needs the corrected data (ENV[\"ZODI_DATA\"] = \"z115\")"

const ARMS10L  = [("base", "n·* (no season)"), ("season", "season model"), ("novS", "season − n·vS"), ("noJ", "season − n·J")]
const ARMCOL10 = Dict("base" => :orange, "season" => :limegreen, "novS" => :gray70, "noJ" => :deepskyblue,
                      "sun" => :magenta, "sunseason" => :gold, "suncloud" => :red, "suncloudZ" => :cyan)
# round 11 (Sun-frame inputs) — same tests (r90 → future set, blk)
const ARMS11L  = [("sun", "Sun frame"), ("sunseason", "Sun frame + sin/cos λ⊕"), ("suncloud", "Sun frame + cloud (n·ĉ, Zc, Rc)"),
                  ("suncloudZ", "Sun frame + cloud (n·ĉ, Zc)")]
const ARMS_ALL = vcat(ARMS10L, ARMS11L)
const ARMLAB   = Dict(ARMS_ALL)
const TESTS10L = Dict("blk" => "30-day blocks", "ch" => "80/20 chronological", "p1" => "patch: ecliptic", "r90" => "random 10% (in-mission)")
# the same (arm, test) trained on the ORIGINAL data — identical recipe (64-64-32-16, batch 512, 100 epochs, one-cycle 1e-3)
const ORIG_NAME = Dict(("base", "blk") => "blk_base", ("base", "ch") => "final_base", ("season", "blk") => "se_blk",
                       ("season", "ch") => "b9_season_ch", ("novS", "blk") => "b9_novS_blk", ("novS", "ch") => "b9_novS_ch",
                       ("season", "p1") => "patch1_season")
const RES_ORIG = joinpath(PROJECT_DIR, "sweeps", "results")
const y_orig   = h5open(f -> read(f["emission"]), joinpath(DATA_DIR, "spherex_zodipy_5um_boresight_interpolated.h5"))
const MISSION_JD0 = minimum(times)                           # first exposure
mission_day(jd) = jd .- MISSION_JD0

const _R10 = Dict{Tuple{String, String}, Vector{Any}}()
runs10(arm, test) = get!(_R10, (arm, test)) do
    [deserialize(joinpath(RESULTS_DIR, "z115_$(arm)_$(test)_s$s.jls")) for s in 42:46
     if isfile(joinpath(RESULTS_DIR, "z115_$(arm)_$(test)_s$s.jls"))]
end
runs_orig(arm, test) = haskey(ORIG_NAME, (arm, test)) ?        # every seed 42–46 that exists (some older ones have 3)
    [deserialize(joinpath(RES_ORIG, "$(ORIG_NAME[(arm, test)])_s$s.jls")) for s in 42:46
     if isfile(joinpath(RES_ORIG, "$(ORIG_NAME[(arm, test)])_s$s.jls"))] : Any[]

function ens_metrics(rs, yy)
    e = ensemble_pred(rs); te = rs[1].te_idx; fe = abs.(e[te] .- yy[te]) ./ yy[te]
    (; mse=mean(abs2, e[te] .- yy[te]), med=100median(fe), p95=100quantile(fe, 0.95))
end

"""Corrected ÷ original target for every exposure vs mission day. Shaded: the window over which ZodiPy's Earth-position
spline was fitted when the original was made (file's first..last exposure); outside it Earth was extrapolated."""
function data_compare_fig()
    d = mission_day(times); r = y ./ y_orig; k = 1:5:length(r)
    spl = mission_day.((times[1], times[end]))
    fig = Figure(size=(1150, 430), fontsize=14)
    ax = Axis(fig[1, 1], xlabel="mission day", ylabel="corrected ÷ original",
              title="Corrected target (ZodiPy 1.1.5, heliocentric observer, true Earth) ÷ original simulated data — every 5th exposure")
    vspan!(ax, [minimum(spl)], [maximum(spl)], color=(:limegreen, 0.12))
    text!(ax, mean(spl), 0.94, text="original: Earth from its spline\n(only the 2–3% observer offset)", align=(:center, :bottom), fontsize=12, color=:limegreen)
    text!(ax, 100, 1.05, text="original: Earth EXTRAPOLATED", align=(:center, :top), fontsize=12, color=:orange)
    scatter!(ax, d[k], r[k], markersize=1.5, color=(:deepskyblue, 0.35)); hlines!(ax, [1.0], color=:white, linestyle=:dash)
    ylims!(ax, 0.93, 1.06); fig
end

"""Same tests, same recipe: original (buggy) target vs the corrected one. Each ensemble is scored against the target it
was trained on."""
function sanity_table()
    df = DataFrame(test=String[], variant=String[], seeds=String[], original_median_pct=Float64[], corrected_median_pct=Float64[],
                   original_p95_pct=Float64[], corrected_p95_pct=Float64[], original_mse=String[], corrected_mse=String[])
    for test in ("blk", "p1", "ch"), (arm, al) in ARMS10L
        rs = runs10(arm, test); ro = runs_orig(arm, test); (isempty(rs) || isempty(ro)) && continue
        @assert rs[1].te_idx == ro[1].te_idx "$arm/$test: original and corrected runs use different test sets"
        a, b = ens_metrics(ro, y_orig), ens_metrics(rs, y)
        push!(df, (TESTS10L[test], al, "$(length(ro)) / $(length(rs))", round(a.med, digits=4), round(b.med, digits=4),
                   round(a.p95, digits=3), round(b.p95, digits=3), sci(a.mse), sci(b.mse)))
    end
    df
end

"""80/20 chronological: median error vs mission day, original vs corrected target (season model)."""
function chrono_fig(; arms=("base", "season"))
    fig = Figure(size=(1150, 450), fontsize=14)
    ax = Axis(fig[1, 1], xlabel="mission day", ylabel="median |error| (%)", yscale=log10,
              title="80/20 chronological test (last 20% of the mission held out): original vs corrected target")
    for arm in arms, (lab, rs, yy, ls) in (("original", runs_orig(arm, "ch"), y_orig, :dash), ("corrected", runs10(arm, "ch"), y, :solid))
        isempty(rs) && continue
        e = ensemble_pred(rs); te = rs[1].te_idx; d = mission_day(times[te]); fe = 100abs.(e[te] .- yy[te]) ./ yy[te]
        edges = floor(minimum(d)):2.0:ceil(maximum(d)); c = Float64[]; v = Float64[]
        for k in 1:length(edges)-1
            s = edges[k] .<= d .< edges[k+1]; count(s) < 50 && continue
            push!(c, edges[k] + 1); push!(v, median(fe[s]))
        end
        lines!(ax, c, v, color=ARMCOL10[arm], linestyle=ls, linewidth=2.5, label="$(Dict(ARMS10L)[arm]), $lab target")
    end
    axislegend(ax, position=:lt, labelsize=12); fig
end

# ------------------------------------------------------------------ extrapolation in time (synthetic future set)
const FUT = h5open(joinpath(DATA_DIR, "zodipy115_future.h5")) do f
    (; y=read(f["emission"]), jd=read(f["times/julian_date"]), Δ=read(f["delta_days"]), src=read(f["source_index_0based"]) .+ 1,
       nvec=read(f["pointing/nvec_unit_cartesian"]), S=read(f["spherex/positions"]), vS=read(f["spherex/velocities"]),
       E=read(f["earth/positions"]), vE=read(f["earth/velocities"]), J=read(f["jupiter/positions"]))
end
@assert size(FUT.nvec, 1) == 3 && size(FUT.S, 1) == 3

"""Ensemble prediction for arbitrary geometry through the real-data pipeline (= the training features)."""
function predict_geom(rs, nvec, geom)
    F, nms = ZodiPipeline.build_features(nvec, geom)
    cols = [findfirst(==(f), nms) for f in rs[1].feature_names]
    @assert !any(isnothing, cols) "feature missing from the pipeline: $(rs[1].feature_names)"
    vec(mean(reduce(hcat, [Float64.(predict_y(r, Float32.(((F[:, cols] .- r.μ') ./ r.σ')'))) for r in rs]), dims=2))
end

"""Pipeline check: the r90 ensembles predict their own in-mission test rows identically via the pipeline."""
function pipeline_selfcheck(arm="season")
    rs = runs10(arm, "r90"); te = rs[1].te_idx[1:50:end]
    g = (; S=spherex_positions[:, te], E=earth_positions[:, te], vS=v_spherex[:, te], vE=v_earth[:, te], J=jupiter_positions[:, te])
    maximum(abs.(predict_geom(rs, nvec_unit_cartesian[:, te], g) .- ensemble_pred(rs)[te]) ./ y[te])
end

const _FP = Dict{String, Vector{Float64}}()
future_pred(arm) = get!(_FP, arm) do
    predict_geom(runs10(arm, "r90"), FUT.nvec, (; S=FUT.S, E=FUT.E, vS=FUT.vS, vE=FUT.vE, J=FUT.J))
end

"""Median / p95 |error| per shift Δ (each Δ = the whole survey pattern moved Δ days later), plus the in-mission reference."""
function future_table(arms=ARMS_ALL)
    Δs = sort(unique(FUT.Δ))
    df = DataFrame(shift=vcat("in-mission (held-out 10%)", ["+$(Int(d)) d" for d in Δs]))
    for (arm, al) in arms
        rs = runs10(arm, "r90"); isempty(rs) && continue
        m0 = ens_metrics(rs, y); fe = 100abs.(future_pred(arm) .- FUT.y) ./ FUT.y
        df[!, "$al ($(length(rs))) median %"] = vcat(round(m0.med, digits=4), [round(median(fe[FUT.Δ .== d]), digits=4) for d in Δs])
    end
    df
end

"""Median |error| vs date across ~2 years: the mission (shaded) and the synthetic future exposures."""
function future_fig(arms=ARMS10L; title="Extrapolation in time: trained on the whole mission (shaded), tested on the same survey pattern later in the year")
    fig = Figure(size=(1200, 520), fontsize=14)
    ax = Axis(fig[1, 1], xlabel="days since the first mission exposure", ylabel="median |error| (%)", yscale=log10, title=title)
    dm = mission_day(times); vspan!(ax, [minimum(dm)], [maximum(dm)], color=(:white, 0.12))
    for x in (365.25, 730.5); vlines!(ax, [x], color=(:white, 0.4), linestyle=:dot); end
    for (arm, al) in arms
        rs = runs10(arm, "r90"); isempty(rs) && continue
        d = mission_day(FUT.jd); fe = 100abs.(future_pred(arm) .- FUT.y) ./ FUT.y
        edges = 0:7.0:ceil(maximum(d)); c = Float64[]; v = Float64[]
        for k in 1:length(edges)-1
            s = edges[k] .<= d .< edges[k+1]; count(s) < 100 && continue
            push!(c, edges[k] + 3.5); push!(v, median(fe[s]))
        end
        lines!(ax, c, v, color=ARMCOL10[arm], linewidth=2.5, label=al)
        m0 = ens_metrics(rs, y); scatter!(ax, [mean(dm)], [m0.med], color=ARMCOL10[arm], marker=:star5, markersize=16)
    end
    ylims!(ax, low=0.005)
    axislegend(ax, position=:rb, labelsize=12, framevisible=true)
    Label(fig[2, 1], "stars: held-out 10% inside the mission.  Lines: synthetic exposures, 7-day bins (inside the shaded window they are " *
          "rotated survey patterns at mission dates — new sky positions for that date).  Dotted: +1 and +2 years.", fontsize=12, color=:gray70)
    fig
end

"""In-mission interpolation (30-day blocks) for every round-10/11 input set: must not get worse than the season model."""
function interp_table(arms=ARMS_ALL)
    ref = runs10("season", "blk"); mref = mse_on(ensemble_pred(ref), ref[1].te_idx)
    df = DataFrame(variant=String[], features=Int[], seeds=Int[], median_err_pct=Float64[], p95_err_pct=Float64[], mse=String[], vs_season=Float64[])
    for (arm, al) in arms
        rs = runs10(arm, "blk"); isempty(rs) && continue
        m = ens_metrics(rs, y)
        push!(df, (al, length(rs[1].feature_names), length(rs), round(m.med, digits=4), round(m.p95, digits=3), sci(m.mse), round(m.mse / mref, digits=3)))
    end
    df
end

# ------------------------------------------------------------------ round 12: train on a simulated year, test on the next
# The multi-year data are read directly (this notebook's globals hold the 140-day mission); each run stores its test predictions.
const Y12 = let P = joinpath(DATA_DIR, "z115year_pointing.h5"), B = joinpath(DATA_DIR, "z115year_boresight.h5")
    isfile(P) ? (; jd=h5open(f -> read(f["times/julian_date"]), P), shift=h5open(f -> read(f["shift_days"]), P),
                   y=h5open(f -> read(f["emission"]), B)) : nothing
end
const RES12 = joinpath(PROJECT_DIR, "sweeps", "results_z115year")
const _R12 = Dict{String, Vector{Any}}()
runs12(arm) = get!(_R12, arm) do
    [deserialize(joinpath(RES12, "y12_$(arm)_s$s.jls")) for s in 42:46 if isfile(joinpath(RES12, "y12_$(arm)_s$s.jls"))]
end
const ARMS12L = [("base", "n·* (no season)"), ("season", "season model"), ("noJ", "season − n·J"), ("sun", "Sun frame"),
                 ("sunseason", "Sun frame + sin/cos λ⊕"), ("suncloud", "Sun frame + cloud (n·ĉ, Zc, Rc)"), ("suncloudZ", "Sun frame + cloud (n·ĉ, Zc)")]

"""Year-2 accuracy by quarter after the training year (median |error| %)."""
function year2_table()
    d = Y12.jd .- minimum(Y12.jd); edges = [365.25, 456, 548, 639, 730.5, 840]
    df = DataFrame(variant=String[], features=Int[], seeds=Int[], year1_fit=Float64[], year2_all=Float64[])
    for (lo, hi) in zip(edges[1:end-1], edges[2:end]); df[!, "days $(round(Int, lo))–$(round(Int, hi))"] = Float64[]; end
    for (arm, al) in ARMS12L
        rs = runs12(arm); isempty(rs) && continue
        e = ensemble_pred(rs); te = rs[1].te_idx; fe = 100abs.(e[te] .- Y12.y[te]) ./ Y12.y[te]
        tr = rs[1].tr_idx; f1 = 100median(abs.(e[tr] .- Y12.y[tr]) ./ Y12.y[tr])   # error on the training year itself
        push!(df, vcat(Any[al, length(rs[1].feature_names), length(rs), round(f1, digits=4), round(median(fe), digits=4)],
                       [round(median(fe[lo .<= d[te] .< hi]), digits=4) for (lo, hi) in zip(edges[1:end-1], edges[2:end])]))
    end
    df
end

"""Median |error| vs date for the year-1 → later test."""
function year2_fig()
    fig = Figure(size=(1200, 500), fontsize=14)
    ax = Axis(fig[1, 1], xlabel="days since the first mission exposure", ylabel="median |error| (%)", yscale=log10,
              title="Trained on one full simulated year (shaded), tested on the following ~16 months")
    vspan!(ax, [0.0], [365.25], color=(:white, 0.12)); vlines!(ax, [730.5], color=(:white, 0.4), linestyle=:dot)
    d = Y12.jd .- minimum(Y12.jd)
    for (arm, al) in ARMS12L
        rs = runs12(arm); isempty(rs) && continue
        e = ensemble_pred(rs); te = rs[1].te_idx; fe = 100abs.(e[te] .- Y12.y[te]) ./ Y12.y[te]; dt = d[te]
        edges = 365.25:7.0:ceil(maximum(dt)); c = Float64[]; v = Float64[]
        for k in 1:length(edges)-1
            s = edges[k] .<= dt .< edges[k+1]; count(s) < 100 && continue
            push!(c, edges[k] + 3.5); push!(v, median(fe[s]))
        end
        lines!(ax, c, v, color=ARMCOL10[arm], linewidth=2.5, label=al)
    end
    axislegend(ax, position=:lt, labelsize=11, nbanks=2); fig
end

"""Which inputs leave their training range in the future set? (fraction of future rows outside the 0.1–99.9% training range)"""
function feature_range_table(arm="season")
    tr = splits["random 90/10"][1]                       # the training rows of every r90 run
    Ftr, nms = ZodiPipeline.build_features(nvec_unit_cartesian[:, tr], (; S=spherex_positions[:, tr], E=earth_positions[:, tr],
                                            vS=v_spherex[:, tr], vE=v_earth[:, tr], J=jupiter_positions[:, tr]); bands=false)
    Ff, _ = ZodiPipeline.build_features(FUT.nvec, (; S=FUT.S, E=FUT.E, vS=FUT.vS, vE=FUT.vE, J=FUT.J); bands=false)
    df = DataFrame(feature=String[], train_range=String[], future_range=String[], future_outside_pct=Float64[])
    for (j, nm) in enumerate(nms)
        lo, hi = quantile(Ftr[:, j], (0.001, 0.999))
        push!(df, (nm, @sprintf("%.3f … %.3f", lo, hi), @sprintf("%.3f … %.3f", extrema(Ff[:, j])...),
                   round(100mean((Ff[:, j] .< lo) .| (Ff[:, j] .> hi)), digits=1)))
    end
    df
end
