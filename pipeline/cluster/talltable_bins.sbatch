#!/bin/bash
# Tall-table queries (realdata/talltable_bins.py) as a small job: network-bound, 1 CPU. The server does the work.
#     sbatch pipeline/cluster/talltable_bins.sbatch LEVEL grid G        or        ... LEVEL NAME:RA:DEC ...
#SBATCH --job-name=zodi-tt
#SBATCH --partition=normal
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=8:00:00
#SBATCH --output=logs/%x_%j.out
set -euo pipefail
echo "host $(hostname), $(date), args: $*"
curl -s -o /dev/null -w "web service reachable: HTTP %{http_code}\n" --max-time 20 https://talltable.flatironinstitute.org || true
~/envs/talltable/bin/python -u realdata/talltable_bins.py "$@"
echo "done $(date)"
