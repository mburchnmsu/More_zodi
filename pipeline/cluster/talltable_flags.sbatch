#!/bin/bash
# What the tall table's flags mark: per-bit counts, static-source objects, single-exposure events (realdata/talltable_flags.py).
#     sbatch pipeline/cluster/talltable_flags.sbatch G [first last]
#SBATCH --job-name=zodi-flags
#SBATCH --partition=normal
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=4:00:00
#SBATCH --output=logs/%x_%j.out
set -euo pipefail
echo "host $(hostname), $(date), args: $*"
export TALLTABLE_DB_DIR=/fs1/scratch/mburch6/talltable
~/envs/talltable/bin/python -u realdata/talltable_flags.py "$@"
du -sh data/tt_flags
echo "done $(date)"
