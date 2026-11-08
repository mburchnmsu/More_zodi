#!/bin/bash
# Offset map without the web service: download the partitions a patch grid needs (level-6 patches at the level-G centres;
# G = 1 → 48 partitions, ~85 GB; G = 2 → 192) plus the image/waves tables from the public file server into scratch, then run
# the per-exposure medians locally in DuckDB at 4.9–5.1 μm and at each extra wavelength window (same files, no extra
# download). Files already downloaded (right size) and patches already on disk are skipped, so it can be rerun.
#     sbatch pipeline/cluster/talltable_download.sbatch [G [lo:hi ...]]
#SBATCH --job-name=zodi-ttlocal
#SBATCH --partition=normal
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=08:00:00
#SBATCH --output=logs/%x_%j.out
set -uo pipefail
G=${1:-1}; shift || true
PY=~/envs/talltable/bin/python
BASE=https://sdsc-users.flatironinstitute.org/~chainje/talltable
export TALLTABLE_DB_DIR=/fs1/scratch/$USER/talltable TALLTABLE_LOCAL=1
D=data/spherex_real
echo "host $(hostname), grid $G, extra windows: $*, $(date)"
mkdir -p $TALLTABLE_DB_DIR/pixels
$PY realdata/talltable_local_size.py 6 $G > /dev/null || exit 1          # parts.txt + needed_parts_L6_grid$G.txt
get() {  # get URL FILE: download unless the local file already has the server's size
    want=$(curl -sIL "$1" | awk 'tolower($1)=="content-length:"{n=$2} END{print n+0}' | tr -d '\r')
    [ -f "$2" ] && [ "$(stat -c %s "$2")" = "$want" ] && return 0
    curl -sfL --retry 5 -o "$2.tmp" "$1" && mv "$2.tmp" "$2" || { echo "  FAILED $1"; return 1; }
}
for f in image.parquet waves.parquet; do get $BASE/$f $TALLTABLE_DB_DIR/$f; done
n=0
for p in $(cat $TALLTABLE_DB_DIR/needed_parts_L6_grid$G.txt); do
    mkdir -p $TALLTABLE_DB_DIR/pixels/part=$p
    get $BASE/pixels/part=$p/compacted.parquet $TALLTABLE_DB_DIR/pixels/part=$p/compacted.parquet && n=$((n + 1))
done
echo "have $n of $(wc -l < $TALLTABLE_DB_DIR/needed_parts_L6_grid$G.txt) partitions, $(du -sh $TALLTABLE_DB_DIR | cut -f1), $(date)"
$PY -u realdata/talltable_bins.py 6 grid $G
echo "GRID DONE level 6 grid $G: $(ls $D/ttbin_L6_g${G}_[0-9][0-9][0-9].csv 2>/dev/null | wc -l) patches, $(date)"
for w in "$@"; do
    TT_LAM=$w $PY -u realdata/talltable_bins.py 6 grid $G | grep -v "already done"
    echo "WINDOW $w DONE: $(ls $D/ttbin_L6_g${G}_[0-9][0-9][0-9]_w${w%%:*}.csv 2>/dev/null | wc -l) patches, $(date)"
done
