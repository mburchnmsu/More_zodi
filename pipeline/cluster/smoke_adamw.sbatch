#!/bin/bash
# Round 40 smoke test: 2 epochs of an AdamW config (sweeps/smoke_adamw.jl). Submit from the More_zodi project root:
#     sbatch pipeline/cluster/smoke_adamw.sbatch
#SBATCH --job-name=zodi-smoke
#SBATCH --partition=interactive
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=00:45:00
#SBATCH --output=logs/%x_%j.out

set -euo pipefail
export PATH="$HOME/.juliaup/bin:$PATH"
export ZODI_DATA="${ZODI_DATA:-z500}" GKSwstype=100
echo "host $(hostname), $(date)"
julia --project=. sweeps/smoke_adamw.jl
echo "done $(date)"
