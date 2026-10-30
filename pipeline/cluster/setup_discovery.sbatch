#!/bin/bash
# One-time setup on NMSU Discovery: install and precompile the project's packages (exact versions from Manifest.toml)
# on a compute node, then load the z500 data once as a smoke test. Needs juliaup's julia 1.12.6 in $HOME (same as the
# laptop) and the data/*.h5 files copied by hand. Submit from the More_zodi project root:
#     sbatch pipeline/cluster/setup_discovery.sbatch
#SBATCH --job-name=zodi-setup
#SBATCH --partition=interactive
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=01:30:00
#SBATCH --output=logs/%x_%j.out

set -euo pipefail
export PATH="$HOME/.juliaup/bin:$PATH"
export JULIA_NUM_PRECOMPILE_TASKS=$SLURM_CPUS_PER_TASK
export GKSwstype=100                  # Plots/GR: no display on compute nodes
echo "host $(hostname), $(date), julia $(julia --version)"
julia --project=. -t $SLURM_CPUS_PER_TASK -e 'using Pkg; Pkg.instantiate(); Pkg.precompile(); Pkg.status()'
echo "--- data checksums"
sha256sum data/*.h5
echo "--- smoke test: load the z500 data"
ZODI_DATA=z500 julia --project=. -t $SLURM_CPUS_PER_TASK -e 'include("zodi_setup.jl"); println("N = ", N, ", targets ", length(y)); using Flux, CairoMakie; println("ok")'
echo "done $(date)"
