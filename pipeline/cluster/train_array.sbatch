#!/bin/bash
# SLURM job array for the zodi-emulator training sweeps. TEMPLATE: partition/account/module names depend on the
# cluster — fill in the lines marked EDIT. Submit from the More_zodi project root:
#     sbatch --array=1-16 pipeline/cluster/train_array.sbatch sweeps/configs_v9.jl
# Each task runs its round-robin share of the not-yet-saved runs (see run_lane.jl). Re-submitting is safe:
# finished runs are skipped. Results: sweeps/results/<run>.jls (same as on the laptop).
#SBATCH --job-name=zodi-train
#SBATCH --cpus-per-task=2              # one run uses ~2 BLAS threads + Julia; matches the laptop lanes
#SBATCH --mem=6G                       # ~1.5 GB per process observed on the laptop (423k exposures), with headroom
#SBATCH --time=04:00:00                # ~5 min per run on a laptop core pair; a lane of ~10 runs fits comfortably
#SBATCH --output=logs/%x_%A_%a.out
#SBATCH --partition=EDIT              # EDIT
##SBATCH --account=EDIT               # EDIT if the cluster requires an account

set -euo pipefail
mkdir -p logs
# module load julia/1.12               # EDIT: or use juliaup in $HOME
export JULIA_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=2
export JULIA_DEPOT_PATH="${JULIA_DEPOT_PATH:-$HOME/.julia}"

# one-time per cluster (run on a login node first, not inside every task):
#   julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
julia --project=. pipeline/cluster/run_lane.jl "$1"
