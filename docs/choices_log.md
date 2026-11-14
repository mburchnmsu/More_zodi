# Choices log

Every analysis choice that could change a result goes here: what was chosen, why, and what the alternative was. Started
2026-11-13 because Dr. Saydjari asked us to keep track of the choices being made (Week 14 card). The early entries are
reconstructed from STATUS.md and the scripts. Newest entries go at the bottom.

| Date | Area | Choice | Why / alternative | Where |
|---|---|---|---|---|
| 2026-10-28 | Real data, wavelength | Use 4.9–5.1 μm in the query. In practice the window is 4.9–5.01 μm, because detector D6 stops at 5.01 μm. | This is the emulator's band. Other windows only appear as a side check (`docs/slides_other_wavelengths.md`). | realdata/talltable_offsetmap.jl |
| 2026-10-29 | Real data, releases | qr2 and qr3 data are combined, with no correction between them. | SPHEREx's zodi layer jumps from 1.04× to 1.17× ZodiPy at the release boundary, and the image level drops ~7%. We haven't asked which release to trust. **Open: could produce the Week 13 behind − ahead signal.** | STATUS.md (Oct 29) |
| 2026-10-29 | Real data | No star masking. | The user's call: wait until they say so. Medians over a patch limit how much stars matter. | — |
| 2026-11-04 | Tall table access | Read the downloaded Parquet partitions (~470 GB, Discovery scratch) with DuckDB instead of the web SQL service. | The web service was down. We use the same SQL, so results should match the service. | STATUS.md |
| 2026-11-04 | Our model | Our model's prediction is evaluated at each exposure's own wavelength and time (`ours_lam`). | Matches what the tall table's zodi column is computed for. `ours_5um` is kept as a check. | ttbin_*_ours.csv |
| 2026-11-08 | Sky sampling | Grid 2: 192 HEALPix level-6 patches (~0.92° across). Each exposure gives one value: the median over the patch's pixels (`flux_median`). | A coarse grid keeps SQL time and data size small. Grid 1 (48 patches) gave the same fit values. Denser grids are still to do. | realdata/talltable_offsetmap.jl |
| 2026-11-08 | Galactic cut | Fits use only patches with \|b\| > 15° (144 of 192). | Starlight from the Galaxy and the plane would otherwise dominate the offset. A csc\|b\| term is tested as a check. | realdata/offset_scatter.jl, offset_comps.jl |
| 2026-11-08 | Offset definition | Per patch, offset = median over exposures of (measured − model). Fit across patches: offset = c0 + c1·model. | A median is robust to outlier exposures. The alternative, a time-domain fit per patch (measured ≈ a·model + b), is also reported. | realdata/talltable_offsetmap.jl |
| 2026-11-08 | Component fits | (A) across the sky: one constant plus a scale per Kelsall component. (B) over time: one constant per patch plus shared component scales. | (B) removes any fixed sky (stars, galaxies, a constant), so only zodi's time variation sets the scales. In the figure, white = (A), blue = (B), orange = (B) with SPHEREx's model as the sky. | realdata/offset_comps.jl |
| 2026-11-09 | Time residuals | Subtract each patch's own median over time before mapping residuals. Express residuals in % of our model. | Removes the fixed non-zodi sky. The cost: anything constant in time, such as the offset, can't be seen in these maps. | realdata/realsky2d.jl |
| 2026-11-09 | Earth-motion frame | φE = λ_patch − (λ_sun − 90°), with a low-precision solar formula (~0.01°). Behind = φE 90–270° (per patch), or 150–210° vs 330–30° (binned). | The trailing cloud sits behind Earth. The ahead and behind views of a patch are ~6 months apart, so seasonal (and release) effects are mixed in. | realdata/realsky2d.jl |
| 2026-11-10 | Slides | Every slide is at 5 μm only, with one plot per slide. | The user's and mentor's request. | docs/slides_week13.md |
| 2026-11-13 | Slides | Each figure slide gets a sentence saying what the plot is, plus a sentence with the conclusion. | Dr. Saydjari's request (Week 14 card). | docs/ |
