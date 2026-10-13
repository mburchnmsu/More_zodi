# Why are the time-matched fake planets NOT equivalent to Jupiter? Test the "clock × direction" mechanism.
using LinearAlgebra; BLAS.set_num_threads(4)
include(joinpath(@__DIR__, "..", "zodi_setup.jl"))
for f in ("mb_train.jl", "extra_features.jl", "nb_verify_fns.jl", "summary_helpers.jl", "checks_helpers.jl"); include(joinpath(@__DIR__, f)); end
col(nm) = Fd_raw[:, findfirst(==(nm), dot_names_all)]
Xf = hcat(ones(N), nvec_unit_cartesian')
moving(nm) = (f = col(nm); f .- Xf * (Xf \ f))

println("1) direction of each planet's MOTION over the mission (ecliptic longitude of J(t_end) − J(t_start))")
o = sortperm(t_rel); a, b = o[1], o[end]
for (nm, P) in (("Jupiter", jupiter_positions), ("rot45", J_rot45), ("rot90", J_rot90))
    d = P[:, b] .- P[:, a]
    @printf("   %-8s position lon %.0f° → motion direction lon %.0f° (|Δ| = %.2f AU) → moving part ≈ time × n·(that direction)\n",
            nm, mod(atand(P[2, a], P[1, a]), 360), mod(atand(d[2], d[1]), 360), norm(d))
end

println("\n2) collinearity: |corr| of each Jupiter-like feature with the single closest fixed input")
for nm in ("n·J", "n·Jrot45", "n·Jrot90", "n·Jscr", "n·Ĵfix", "n·Ĵ⊥fix")
    cs = [(abs(cor(col(nm), col(k))), k) for k in ("n·x", "n·y", "n·z")]
    c, k = maximum(cs); @printf("   %-8s closest: %s |corr| = %.4f\n", nm, k, c)
end

println("\n3) does each feature's moving part match what a NO-Jupiter model is missing?")
for (split_lbl, pre) in (("chronological (fit 0–100)", "v_noJ_s"), ("30-day blocks", "blk_noJ_s"))
    rs = load_prefix(pre); isempty(rs) && continue
    r1 = rs[1]; e = ensemble_pred(rs); res = e .- y
    for (set_lbl, idx) in (("fit rows", r1.tr_idx), ("test rows", r1.te_idx))
        print("   ", rpad(split_lbl, 27), rpad(set_lbl, 10), " corr(moving part, noJ residual): ")
        println(join([@sprintf("%s %+.3f", nm, cor(moving(nm)[idx], res[idx])) for nm in ("n·J", "n·Jrot45", "n·Jrot90", "n·Jscr")], "   "))
    end
end

println("\n4) best possible linear use: fraction of the noJ residual variance explained by each moving part (fit rows → test rows)")
for (split_lbl, pre) in (("chronological", "v_noJ_s"), ("30-day blocks", "blk_noJ_s"))
    rs = load_prefix(pre); isempty(rs) && continue
    r1 = rs[1]; res = ensemble_pred(rs) .- y; tr, te = r1.tr_idx, r1.te_idx
    for nm in ("n·J", "n·Jrot45", "n·Jrot90", "n·Jscr")
        m = moving(nm); k = m[tr] \ res[tr]                                   # 1-parameter fit on fit rows
        r2(idx) = 1 - sum(abs2, res[idx] .- k .* m[idx]) / sum(abs2, res[idx])
        @printf("   %-14s %-9s R² fit rows %+.3f | test rows %+.3f\n", split_lbl, nm, r2(tr), r2(te))
    end
end
