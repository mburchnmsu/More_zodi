#!/bin/bash
# Colibrí version of threaded.sbatch: train the pending runs of a config file with K trainings at once in one Julia
# process (sweeps/run_threaded.jl; 1 BLAS thread per training). Finished runs are skipped, so resubmitting is safe.
#     sbatch --cpus-per-task=6 pipeline/cluster/threaded_colibri.sbatch sweeps/configs_v47.jl [--only name1,name2]
# Memory: ~1.2 GB per training on the 500-day data plus ~2 GB shared (Discovery round 44: 6 trainings in 14 GB, ~7.2 h).
#SBATCH --job-name=zodi-train
#SBATCH --account=18-interstellar
#SBATCH --partition=general-cpu
#SBATCH --cpus-per-task=6
#SBATCH --mem=14G
#SBATCH --time=12:00:00
#SBATCH --output=logs/%x_%j.out

set -euo pipefail
export PATH="$HOME/.juliaup/bin:$PATH"
export ZODI_DATA="${ZODI_DATA:-z500}" BLAS_THREADS=1 GKSwstype=100
echo "host $(hostname), $(date), $(julia --version), $SLURM_CPUS_PER_TASK trainings, args: $*"
julia --project=. -t "$SLURM_CPUS_PER_TASK" sweeps/run_threaded.jl "$@"
echo "done $(date)"
