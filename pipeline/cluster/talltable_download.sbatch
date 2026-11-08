#!/bin/bash
# Offset map without the web service: download the partitions the 48-patch grid needs (level-6 patches → 48 level-6
# partitions, ~85 GB) plus image/waves tables from the public file server into scratch, then run the same per-exposure
# medians locally in DuckDB. Partitions already downloaded (right size) are skipped, so it can be rerun.
#     sbatch pipeline/cluster/talltable_download.sbatch
#SBATCH --job-name=zodi-ttlocal
#SBATCH --partition=normal
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=08:00:00
#SBATCH --output=logs/%x_%j.out
set -uo pipefail
PY=~/envs/talltable/bin/python
BASE=https://sdsc-users.flatironinstitute.org/~chainje/talltable
export TALLTABLE_DB_DIR=/fs1/scratch/$USER/talltable TALLTABLE_LOCAL=1
D=data/spherex_real
echo "host $(hostname), $(date)"
mkdir -p $TALLTABLE_DB_DIR/pixels
$PY realdata/talltable_local_size.py 6 1 > /dev/null || exit 1          # parts.txt + needed_parts_L6_grid1.txt
get() {  # get URL FILE: download unless the local file already has the server's size
    want=$(curl -sIL "$1" | awk 'tolower($1)=="content-length:"{n=$2} END{print n+0}' | tr -d '\r')
    [ -f "$2" ] && [ "$(stat -c %s "$2")" = "$want" ] && return 0
    curl -sfL --retry 5 -o "$2.tmp" "$1" && mv "$2.tmp" "$2" || { echo "  FAILED $1"; return 1; }
}
for f in image.parquet waves.parquet; do get $BASE/$f $TALLTABLE_DB_DIR/$f; done
n=0
for p in $(cat $TALLTABLE_DB_DIR/needed_parts_L6_grid1.txt); do
    mkdir -p $TALLTABLE_DB_DIR/pixels/part=$p
    get $BASE/pixels/part=$p/compacted.parquet $TALLTABLE_DB_DIR/pixels/part=$p/compacted.parquet && n=$((n + 1))
done
echo "downloaded $n partitions, $(du -sh $TALLTABLE_DB_DIR | cut -f1), $(date)"
$PY -u realdata/talltable_bins.py 6 grid 1
echo "GRID DONE level 6: $(ls $D/ttbin_L6_g1_*.csv 2>/dev/null | wc -l) of 48 patches, $(date)"
