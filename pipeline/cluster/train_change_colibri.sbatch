#!/bin/bash
# Week 15 task 6 on Colibrí: one array task = one run of sweeps/train_change.jl, read from a list file with one
# "ARM FOLD SEED EPOCHS" line per run (sweeps/real_lists/w15_change.txt). Finished runs are skipped.
#     sbatch --array=1-$(wc -l < LIST) pipeline/cluster/train_change_colibri.sbatch LIST
#SBATCH --job-name=zodi-chg
#SBATCH --account=18-interstellar
#SBATCH --partition=backfill
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=08:00:00
#SBATCH --output=logs/%x_%A_%a.out
set -euo pipefail
export PATH="$HOME/.juliaup/bin:$PATH" GKSwstype=100 OPENBLAS_NUM_THREADS=4
read -r ARM FOLD SEED EPOCHS < <(sed -n "${SLURM_ARRAY_TASK_ID}p" "$1") || true
echo "host $(hostname), $(date), run: $ARM $FOLD $SEED $EPOCHS"
julia --project=. -t $SLURM_CPUS_PER_TASK sweeps/train_change.jl $ARM $FOLD $SEED $EPOCHS
echo "done $(date)"
