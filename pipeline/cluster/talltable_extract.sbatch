#!/bin/bash
# Week 14 task 7a: per-exposure, per-sub-pixel medians from the local tall-table copy on scratch (realdata/talltable_extract.py).
#     sbatch pipeline/cluster/talltable_extract.sbatch G SUB [first last]
#SBATCH --job-name=zodi-ttx
#SBATCH --partition=normal
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=4:00:00
#SBATCH --output=logs/%x_%j.out
set -euo pipefail
echo "host $(hostname), $(date), args: $*"
export TALLTABLE_DB_DIR=/fs1/scratch/mburch6/talltable
~/envs/talltable/bin/python -u realdata/talltable_extract.py "$@"
# star-masked pass (sbatch --export=ALL,TTX_MASK=1 ...): merge the masked medians into one CSV for the ThinkPad
[ "${TTX_MASK:-0}" = 1 ] && ~/envs/talltable/bin/python -u realdata/ttx_mask_merge.py "$1" "$2"
du -sh data/tt_train
echo "done $(date)"
