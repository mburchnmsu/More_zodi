#!/bin/bash
# Week 15 task 4: per-exposure medians of zodi-cleaned difference images from the full tall table (realdata/tt_diffmed.py).
#     sbatch --array=1-N pipeline/cluster/tt_diffmed_colibri.sbatch N                 (task i does parts[i-1 :: N])
#     sbatch --export=ALL,TTD_PARTS=id1:id2:... pipeline/cluster/tt_diffmed_colibri.sbatch   (timing test)
#SBATCH --job-name=zodi-ttd
#SBATCH --account=18-interstellar
#SBATCH --partition=backfill
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=24:00:00
#SBATCH --output=logs/%x_%A_%a.out
set -euo pipefail
source /fs1/project/18-interstellar/software/env.sh
echo "host $(hostname), $(date), task ${SLURM_ARRAY_TASK_ID:-1} of ${1:-1}"
$TALLTABLE_PYTHON -u realdata/tt_diffmed.py "${SLURM_ARRAY_TASK_ID:-1}" "${1:-1}"
echo "done $(date)"
