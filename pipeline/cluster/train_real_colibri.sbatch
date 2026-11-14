#!/bin/bash
# Week 14 task 7b on Colibrí: one array task = one training run of sweeps/train_real.jl, read from a list file with one
# "TARGET EPOCHS SEED HOLDOUT FOLD" line per run. Finished runs are skipped, so resubmitting the same array is safe.
#     sbatch --array=1-$(wc -l < LIST) pipeline/cluster/train_real_colibri.sbatch LIST
#SBATCH --job-name=zodi-real
#SBATCH --account=18-interstellar
#SBATCH --partition=general-cpu
#SBATCH --cpus-per-task=8
#SBATCH --mem=12G
#SBATCH --time=06:00:00
#SBATCH --output=logs/%x_%A_%a.out
set -euo pipefail
export PATH="$HOME/.juliaup/bin:$PATH" GKSwstype=100 OPENBLAS_NUM_THREADS=2
# PER_TASK=K (sbatch --export=ALL,PER_TASK=K): each task runs K consecutive list lines one after another (Colibrí limits
# the number of submitted jobs per user, so a long list is packed into fewer tasks)
K=${PER_TASK:-1}
for L in $(seq $(( (SLURM_ARRAY_TASK_ID - 1) * K + 1 )) $(( SLURM_ARRAY_TASK_ID * K ))); do
    TARGET= FOLD=
    read -r TARGET EPOCHS SEED HOLD FOLD < <(sed -n "${L}p" "$1") || true   # last line may lack a newline
    [ -n "${FOLD:-}" ] || { echo "no list line $L in $1"; continue; }
    echo "host $(hostname), $(date), run: $TARGET $EPOCHS $SEED $HOLD $FOLD"
    julia --project=. -t $SLURM_CPUS_PER_TASK sweeps/train_real.jl $TARGET $EPOCHS $SEED $HOLD $FOLD
done
echo "done $(date)"
