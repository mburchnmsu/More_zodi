#!/bin/bash
# One-time setup on NMSU Colibrí: install and precompile the project's packages (exact versions from Manifest.toml) on a
# compute node with juliaup's julia 1.12.6 in $HOME. No data needed (the z500 .h5 files are not copied yet).
#     sbatch pipeline/cluster/setup_colibri.sbatch
#SBATCH --job-name=zodi-setup
#SBATCH --account=18-interstellar
#SBATCH --partition=general-cpu
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=01:30:00
#SBATCH --output=logs/%x_%j.out

set -euo pipefail
export PATH="$HOME/.juliaup/bin:$PATH"
export JULIA_NUM_PRECOMPILE_TASKS=$SLURM_CPUS_PER_TASK
export GKSwstype=100
echo "host $(hostname), $(date), julia $(julia --version)"
julia --project=. -t $SLURM_CPUS_PER_TASK -e 'using Pkg; Pkg.instantiate(); Pkg.precompile(); Pkg.status()'
julia --project=. -e 'using Flux, CairoMakie, HDF5, JLD2; println("packages load ok")'
echo "done $(date)"
