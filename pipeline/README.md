# Real-data preparation (`pipeline/`) — 2026-10-13

Goal: when real SPHEREx data arrive, they go through **the same code** as the simulated data, so every result so far
(features, splits, training recipe, verification) carries over. Nothing here touches real data yet.

| file | what it does |
|---|---|
| `ZodiPipeline.jl` | module: exposure table → (optional mask) → ephemerides → emulator features |
| `test_pipeline.jl` | verification on the simulated data → `pipeline_checks.log` (12/12 checks pass) |
| `cluster/run_lane.jl` | one SLURM array task = a share of a sweep's pending runs (skips finished ones; atomic saves) |
| `cluster/train_array.sbatch` | SLURM job-array template (partition/account/module lines marked `EDIT`) |

## Data flow
```
real exposures ──► ExposureTable(jd, nvec | RA/Dec, sky, sky_err, wavelength, keep)
                     │  apply_star_mask(tab; mode=:none)        ← hook only; OFF until we decide to mask
                     ▼
JPL Horizons tables ─► ephemeris_at(jd; earth, jupiter, spherex) → S, E, vS, vE, J  (Hermite interpolation)
                     ▼
               build_features(nvec, geom) → n·S … n·y, sin/cos λ⊕, dust-band profiles   (== training features)
```

### What we need from the real data (per exposure, or per sky-sample)
* **mid-exposure time** (JD; Horizons uses TDB — UTC differs by 69 s, i.e. Earth moves ~2000 km ≈ 1e-5 AU: negligible)
* **pointing**: RA/Dec (ICRS) or a unit vector; `radec_to_ecliptic` rotates to the barycentric mean ecliptic J2000
  (obliquity 84381.406″, as ZodiPy/astropy)
* **sky level** in MJy/sr with an uncertainty, at the wavelength we model. The simulated target is the zodi
  brightness at **5 μm**; real images span 0.75–5 μm with a wavelength gradient across each detector. Open choice
  (for the mentor): a separate emulator per wavelength channel, or wavelength as an extra input.
* the real sky also contains stars/galaxies, the Galaxy and the CIB → the mask hook and a robust per-exposure
  statistic (e.g. sigma-clipped median of unmasked pixels) are where that goes — **not applied yet**.

### Ephemerides (JPL Horizons, saved as text)
Ephemeris type **Vector table**, quantities **state vector (positions + velocities)**, **CSV format = YES**,
coordinate centre **Solar System Barycenter (500@0)**, reference plane **ECLIPTIC (J2000)**, units **AU-D**
(KM-S is also accepted). `read_horizons_vectors` *refuses* files with another centre or plane.
Steps used in the test: Earth 6 h, Jupiter 1 day, SPHEREx 1 min (its 94-min orbit needs fine sampling).
* Earth (Horizons `399`), Jupiter (`599`), SPHEREx (look up the spacecraft's Horizons ID).
* If no SPHEREx ephemeris is available, `ephemeris_at` puts SPHEREx at Earth's centre — **but see the finding below**.

## Verified on the simulated data (`pipeline_checks.log`)
* pipeline features == training features for all 22 inputs (max difference 5.6e-16) — season and dust-band ones included
* ecliptic lon/lat from the pointing vectors match the pointing file (< 1e-11°); RA/Dec ↔ ecliptic round trip 5e-15;
  north ecliptic pole → +z, equinox → +x
* Horizons-format write/read round trip exact; Hermite interpolation: Earth from 6-hourly nodes ≤ 0.01 km
  (λ⊕ error 3e-9°), SPHEREx from 1-minute nodes ≤ 0.002 km, Jupiter from daily nodes 7e-7 AU. (The simulated
  ephemerides are themselves interpolated and smooth, so these are best cases; real Horizons tables will do similarly.)
* requests outside a table's time range are refused; the star mask is a no-op and other modes refuse
* 16 cluster lanes cover the 125 round-9 runs exactly once

### Finding: the emulator depends on SPHEREx's orbital velocity direction
Season model, 30-day blocks (5-seed ensemble, 180k test exposures):

| geometry used at prediction | median \|error\| | p95 |
|---|---|---|
| exact SPHEREx position and velocity | 0.032% | 0.14% |
| position → Earth's centre only (≤ 5e-5 AU) | 0.032% | — |
| velocity direction → Earth's only | 0.050% | — |
| both (no spacecraft ephemeris) | 0.050% | 0.23% |

Moving SPHEREx by its orbit radius does nothing, as physics says; swapping the **velocity direction** (which swings by
up to 15° around the 94-min orbit) costs 50% more error. Kelsall has no velocity dependence, so `n·vS` is being used
as a survey-pointing proxy (like `n·δ̂` on 10/08). Consequences: (1) for real data, get the SPHEREx ephemeris
(or drop `n·vS`); (2) the `season_novS` control in round 9 tests whether the feature can simply be removed.

## Cluster
```bash
# once, on a login node (from the More_zodi root):
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
# then e.g. 16 tasks for the round-9 sweep:
sbatch --array=1-16 pipeline/cluster/train_array.sbatch sweeps/configs_v9.jl
# check what a task would run without training:
SLURM_ARRAY_TASK_ID=3 SLURM_ARRAY_TASK_COUNT=16 julia --project=. pipeline/cluster/run_lane.jl sweeps/configs_v9.jl --dry-run
```
Memory ≈ 1.5 GB per task for the 423k-exposure set; a full SPHEREx year at the same cadence would be ~2.6× that.
The data files (`data/*.h5`, ~150 MB) must be copied to the cluster alongside the project.
