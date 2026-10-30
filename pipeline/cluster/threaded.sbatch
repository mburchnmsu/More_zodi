#!/bin/bash
# NMSU Discovery: train the pending runs of a config file with K trainings at once in one Julia process
# (sweeps/run_threaded.jl, exactly as on the laptop: 1 BLAS thread per training, one shared copy of the data).
# K = --cpus-per-task. Finished runs are skipped, so resubmitting is safe. Submit from the More_zodi project root:
#     sbatch --cpus-per-task=5 pipeline/cluster/threaded.sbatch sweeps/configs_v37.jl [--only name1,name2]
# Memory: ~1.2 GB per training on the 500-day data plus ~2 GB shared (round 37 on the laptop: 5.2–6.5 GB for 5).
#SBATCH --job-name=zodi-train
#SBATCH --partition=normal
#SBATCH --cpus-per-task=5
#SBATCH --mem=12G
#SBATCH --time=12:00:00
#SBATCH --output=logs/%x_%j.out

set -euo pipefail
export PATH="$HOME/.juliaup/bin:$PATH"
export ZODI_DATA="${ZODI_DATA:-z500}" BLAS_THREADS=1 GKSwstype=100
echo "host $(hostname), $(date), $(julia --version), $SLURM_CPUS_PER_TASK trainings, args: $*"
julia --project=. -t "$SLURM_CPUS_PER_TASK" sweeps/run_threaded.jl "$@"
echo "done $(date)"
