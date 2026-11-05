#!/bin/bash
# Wait for the tall-table web service to come back (one SELECT 1 per hour, up to 3 days), then run the offset-map queries:
# the 0.92° (level-6) test on two patches, then the 48-patch grid at level 6 if both test patches worked, else at level 8.
#     sbatch pipeline/cluster/talltable_wait.sbatch
#SBATCH --job-name=zodi-ttwait
#SBATCH --partition=normal
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=3-12:00:00
#SBATCH --output=logs/%x_%j.out
set -uo pipefail
PY=~/envs/talltable/bin/python
D=data/spherex_real
echo "host $(hostname), $(date)"
up=0
for i in $(seq 1 72); do
    if $PY realdata/talltable_ping.py; then up=1; break; fi
    echo "  $(date '+%m-%d %H:%M') try $i: down, next in 1 h"; sleep 3600
done
[ $up = 1 ] || { echo "still down after 72 tries, giving up $(date)"; exit 1; }
echo "service up $(date); level-6 test"
$PY -u realdata/talltable_bins.py 6 b30l210:218.487:16.649 nep:270:66.560708
if [ -f $D/ttbin_L6_b30l210.csv ] && [ -f $D/ttbin_L6_nep.csv ]; then LEVEL=6; else LEVEL=8; fi
echo "grid at level $LEVEL $(date)"
$PY -u realdata/talltable_bins.py $LEVEL grid 1
echo "GRID DONE level $LEVEL: $(ls $D/ttbin_L${LEVEL}_g1_*.csv 2>/dev/null | wc -l) of 48 patches, $(date)"
