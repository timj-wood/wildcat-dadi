#!/bin/bash
#SBATCH --job-name=wildcat_report
#SBATCH --account=bisc019342
#SBATCH --partition=short
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --time=6:00:00
#SBATCH --output=logs/%x_%j.out

# Usage, from the repository root:
#
#   sbatch scripts/submit_report.sh                            # sec_contact and basic
#   sbatch scripts/submit_report.sh sec_contact basic growth
#
# Gathers every restart, polishes the best one, computes CLAIC against the
# bootstraps, and writes results_wild/<model>_results.csv plus
# results_wild/model_comparison.csv. Run once, after the fitting arrays have
# finished.
#
# The wall clock is dominated by the polish, not by CLAIC: re-optimising the best
# restart can take 30 minutes or more per model, whereas CLAIC itself took 31 s
# for sec_contact and about 2 minutes per eps for the 11-parameter model. If the
# growth model is included, raise --time or move to the compute partition:
#
#   sbatch --partition=compute --time=24:00:00 scripts/submit_report.sh sec_contact basic growth

set -euo pipefail

MODELS=("$@")
if [ ${#MODELS[@]} -eq 0 ]; then
    MODELS=(sec_contact basic)
fi

export OMP_NUM_THREADS=1

# conda's activation scripts are not reliably safe under `set -u`.
set +u
source "${CONDA_ROOT:-/user/work/gb22703/miniforge3}/etc/profile.d/conda.sh"
conda activate dadi
set -u

cd "${SLURM_SUBMIT_DIR:-.}"
mkdir -p logs

python scripts/wildcat_pipeline.py report --models "${MODELS[@]}"
