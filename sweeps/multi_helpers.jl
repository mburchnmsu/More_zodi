# Round 13 helpers (multi-wavelength emulator, 1.25–5.0 μm) for the 10142026_multiwavelength notebook.
# Requires ENV["ZODI_DATA"] = "z115multi" before zodi_setup.jl, then mb_train.jl, extra_features.jl, extra_splits.jl,
# nb_verify_fns.jl, summary_helpers.jl.
@assert ZODI_DATA == "z115multi" "multi_helpers.jl needs ENV[\"ZODI_DATA\"] = \"z115multi\""
const ARMS13L  = [("sunlin", "Sun frame + λ, MSE"), ("sunrel", "Sun frame + λ, fractional loss"),
                  ("sunrelbig", "Sun frame + λ, fractional loss, 128-128-64-32"), ("seasonrel", "old season inputs + λ, fractional loss"),
                  ("sunphase", "Sun frame + λ + ZodiPy phase coefficients C1–C3, fractional loss"),   # round 14
                  ("ep300", "… phase coefficients, 300 epochs"), ("bb", "… phase coefficients + blackbody inputs"),
                  ("bb300", "… phase coefficients + blackbody inputs, 300 epochs")]                  # round 15
const ARMCOL13 = Dict("sunlin" => :orange, "sunrel" => :limegreen, "sunrelbig" => :deepskyblue, "seasonrel" => :magenta, "sunphase" => :red,
                      "ep300" => :gold, "bb" => :cyan, "bb300" => :white)
const ARMS13_R13 = ARMS13L[1:4]; const ARMS13_R1415 = vcat([("sunrel", ARMS13L[2][2])], ARMS13L[5:8])
const TESTS13L = [("chan", "held-out channels (16 of 64 wavelengths never seen)"), ("blk", "30-day blocks (all wavelengths)")]
const CHAN_W   = h5open(f -> read(f["channel_wavelengths_um"]), emission_file)
const _R13 = Dict{Tuple{String, String}, Vector{Any}}()
runs13(arm, test) = get!(_R13, (arm, test)) do
    [deserialize(joinpath(RESULTS_DIR, "m13_$(arm)_$(test)_s$s.jls")) for s in 42:46 if isfile(joinpath(RESULTS_DIR, "m13_$(arm)_$(test)_s$s.jls"))]
end
fe13(rs) = (e = ensemble_pred(rs); te = rs[1].te_idx; (te, 100abs.(e[te] .- y[te]) ./ y[te]))

"""Ensemble accuracy per (test, variant): median / p95 fractional error and MSE."""
function multi_table()
    df = DataFrame(test=String[], variant=String[], seeds=Int[], median_err_pct=Float64[], p95_err_pct=Float64[],
                   worst_channel_median_pct=Float64[], mse=String[])
    for (t, tl) in TESTS13L, (a, al) in ARMS13L
        rs = runs13(a, t); isempty(rs) && continue
        te, fe = fe13(rs)
        worst = maximum(median(fe[CHANNEL[te] .== c]) for c in unique(CHANNEL[te]))
        push!(df, (first(split(tl, " (")), al, length(rs), round(median(fe), digits=4), round(quantile(fe, 0.95), digits=3),
                   round(worst, digits=4), sci(mean(abs2, ensemble_pred(rs)[te] .- y[te]))))
    end
    df
end

"""Median |error| per wavelength channel (left: held-out channels test; right: 30-day blocks)."""
function err_vs_lambda_fig(arms=ARMS13_R13)
    fig = Figure(size=(1200, 540), fontsize=14)
    for (col, (t, tl)) in enumerate(TESTS13L)
        ax = Axis(fig[1, col], xlabel="wavelength (μm)", ylabel=col == 1 ? "median |error| (%)" : "", yscale=log10, title=tl, xscale=log10,
                  xticks=[1.25, 1.5, 2, 2.5, 3, 4, 5])
        vlines!(ax, [1.725, 2.85, 4.2], color=(:red, 0.25), linestyle=:dash)        # ZodiPy's phase-coefficient steps
        for (a, al) in arms
            rs = runs13(a, t); isempty(rs) && continue
            te, fe = fe13(rs); cs = sort(unique(CHANNEL[te]))
            scatterlines!(ax, CHAN_W[cs .+ 1], [median(fe[CHANNEL[te] .== c]) for c in cs], color=ARMCOL13[a], markersize=6, label=al)
        end
    end
    # the blocks panel (right) has every variant → one legend under both panels
    Legend(fig[2, 1:2], content(fig[1, 2]), orientation=:horizontal, nbanks=2, labelsize=11, framevisible=false)
    fig
end

"""Predicted spectra (each ensemble evaluated at 120 wavelengths for 6 fixed exposures) vs ZodiPy's spectra.
The networks saw each exposure at ONE wavelength at most (and the chan models never saw 16 of the channels)."""
function spectra_fig(arm="sunrel", test="chan")
    sp = h5open(joinpath(DATA_DIR, "zodipy115_spectra.h5")) do f
        (; idx=read(f["index_0based"]) .+ 1, w=read(f["wavelength_um"]), y=permutedims(read(f["emission"])), lat=read(f["ecliptic_latitude_deg"]))
        # (h5py writes the (6, 120) array row-major → Julia reads it as 120 × 6; permute back to exposures × wavelengths)
    end
    rs = runs13(arm, test); fn = rs[1].feature_names; cols = [findfirst(==(nm), dot_names_all) for nm in fn]
    jl = findfirst(==("logλ"), fn); jc = [findfirst(==("phC$i"), fn) for i in 1:3]     # every wavelength-dependent input
    fig = Figure(size=(1250, 640), fontsize=13)
    for (i, k) in enumerate(sp.idx)
        F = repeat(Fd_raw[k:k, cols], length(sp.w)); F[:, jl] .= log10.(sp.w)
        for i in 1:3; jc[i] === nothing || (F[:, jc[i]] .= [phase_coeffs(w)[i] for w in sp.w]); end
        for (nm, T) in (("logB250", 250.0), ("logB300", 300.0))
            j = findfirst(==(nm), fn); j === nothing || (F[:, j] .= logB_rel.(sp.w, T))
        end
        p = vec(mean(reduce(hcat, [Float64.(predict_y(r, Float32.(((F .- r.μ') ./ r.σ')'))) for r in rs]), dims=2))
        ax = Axis(fig[fldmod1(i, 3)...], title=@sprintf("β = %.0f°   max |error| %.2f%%", sp.lat[i], 100maximum(abs.(p .- sp.y[i, :]) ./ sp.y[i, :])),
                  xlabel=i > 3 ? "wavelength (μm)" : "", ylabel=i in (1, 4) ? "MJy/sr" : "")
        held = CHAN_W[(0:63)[(0:63) .% 4 .== 2] .+ 1]
        vlines!(ax, held, color=(:white, 0.08))
        lines!(ax, sp.w, sp.y[i, :], color=:white, linewidth=3, label="ZodiPy")
        lines!(ax, sp.w, p, color=ARMCOL13[arm], linewidth=2, linestyle=:dash, label="emulator")
        i == 1 && axislegend(ax, position=:ct, labelsize=11)
    end
    Label(fig[0, :], "Spectra of 6 mission exposures: emulator ($(Dict(ARMS13L)[arm]), $(test == "chan" ? "faint vertical lines = the 16 wavelengths it never saw" : "30-day blocks")) vs ZodiPy",
          font=:bold, fontsize=15)
    fig
end
