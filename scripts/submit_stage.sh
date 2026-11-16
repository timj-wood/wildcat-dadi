#!/bin/bash
#SBATCH --job-name=wc_stage
#SBATCH --account=bisc019342
#SBATCH --partition=compute
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --time=6:00:00
#SBATCH --output=logs/%x_%A_%a.out
#SBATCH --error=logs/%x_%A_%a.err
#
# One stage of a staged optimisation. Not submitted by hand -- run_stages.sh
# submits it eight times with the right dependencies. Mode is the first
# argument; everything else arrives through the environment, which sbatch
# forwards by default.
#
#   fit   one array task, one restart, writing
#         ${WILDCAT_OUTDIR}/fit_<model>_task<id>.pkl
#   best  after the array finishes: write the round's best point to JSON and
#         move that round's pickles into ${WILDCAT_OUTDIR}/r<N>/, so the next
#         gather sees only the round it belongs to
#
# Header values are overridden per submission (--array, --time), so the ones
# above are only defaults.

# No -e: the best branch inspects the exit status of the python step itself.
set -uo pipefail

# Must match wildcat_pipeline.py, which reads the same variable. run_stages.sh
# exports it; the default here covers a hand submission.
export WILDCAT_OUTDIR="${WILDCAT_OUTDIR:-results_wild}"

# conda's activation scripts are not reliably safe under `set -u`.
set +u
source "${CONDA_ROOT:-/user/work/gb22703/miniforge3}/etc/profile.d/conda.sh"
conda activate dadi
set -u

cd "${SLURM_SUBMIT_DIR:-.}" || exit 1
mkdir -p logs "${WILDCAT_OUTDIR}"

MODE="${1:?usage: submit_stage.sh fit|best}"
MODEL="${MODEL:-basic}"
ROUND="${ROUND:-1}"

echo "mode=${MODE} model=${MODEL} round=${ROUND} outdir=${WILDCAT_OUTDIR} host=$(hostname)"
echo "started: $(date)"

if [ "${MODE}" = "fit" ]; then
    ARGS=(--model "${MODEL}"
          --task-id "${SLURM_ARRAY_TASK_ID}"
          --seed-base "${SEEDBASE}"
          --fold "${FOLD}"
          --maxiter "${MAXITER}"
          --maxeval "${MAXEVAL}"
          --ftol "${FTOL}"
          --maxtime "${MAXTIME}")
    if [ -n "${STARTFROM:-}" ]; then
        ARGS+=(--start-from "${STARTFROM}")
    fi
    echo "python scripts/wildcat_pipeline.py fit ${ARGS[*]}"
    python scripts/wildcat_pipeline.py fit "${ARGS[@]}"

elif [ "${MODE}" = "best" ]; then
    python scripts/wildcat_pipeline.py best --model "${MODEL}" \
        --out "${WILDCAT_OUTDIR}/best_${MODEL}_r${ROUND}.json"
    status=$?
    if [ ${status} -ne 0 ]; then
        echo "best failed; leaving pickles in place for inspection"
        exit ${status}
    fi
    mkdir -p "${WILDCAT_OUTDIR}/r${ROUND}"
    # Not silenced: if this matches nothing the next round's gather will pick up
    # this round's pickles as well as its own, and the staging quietly stops
    # meaning anything. Better to see the error in the log.
    pickles=("${WILDCAT_OUTDIR}"/fit_"${MODEL}"_task*.pkl)
    if [ ! -e "${pickles[0]}" ]; then
        echo "WARNING: no ${WILDCAT_OUTDIR}/fit_${MODEL}_task*.pkl to move." >&2
        echo "         round ${ROUND} pickles will be visible to round $((ROUND + 1))." >&2
    else
        mv "${pickles[@]}" "${WILDCAT_OUTDIR}/r${ROUND}/"
        echo "moved ${#pickles[@]} round ${ROUND} pickles to ${WILDCAT_OUTDIR}/r${ROUND}/"
    fi

else
    echo "unknown mode: ${MODE}" >&2
    exit 2
fi

echo "finished: $(date)"
