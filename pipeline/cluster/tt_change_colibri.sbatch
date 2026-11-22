#!/bin/bash
# Week 15 task 6: per exposure × level-9 cell change of the sky (flux scaled to 5 μm minus its per-pixel median), realdata/tt_change.py.
#     sbatch --array=1-N pipeline/cluster/tt_change_colibri.sbatch N                 (task i does parts[i-1 :: N])
#     sbatch --export=ALL,TTC_PARTS=id1:id2:... pipeline/cluster/tt_change_colibri.sbatch   (timing test)
#SBATCH --job-name=zodi-ttc
#SBATCH --account=18-interstellar
#SBATCH --partition=backfill
#SBATCH --cpus-per-task=4
#SBATCH --mem=24G
#SBATCH --time=24:00:00
#SBATCH --output=logs/%x_%A_%a.out
set -euo pipefail
source /fs1/project/18-interstellar/software/env.sh
export TTD_MEM=${TTD_MEM:-14GB}
echo "host $(hostname), $(date), task ${SLURM_ARRAY_TASK_ID:-1} of ${1:-1}"
$TALLTABLE_PYTHON -u realdata/tt_change.py "${SLURM_ARRAY_TASK_ID:-1}" "${1:-1}"
echo "done $(date)"
