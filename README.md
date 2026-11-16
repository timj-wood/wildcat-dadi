# wildcat-dadi

Demographic inference for the Scottish wildcat (*Felis silvestris*) and the domestic cat (*F. catus*) from a folded joint site frequency spectrum, using [dadi](https://dadi.readthedocs.io) 2.4.4.

Three two-population models are fitted, compared with CLAIC, and given confidence intervals from the Godambe information matrix (100 block-bootstrap replicates).

## Requirements

A SLURM cluster and conda. Create the environment with:

    conda env create -f environment.yml

The submission scripts activate it from `$CONDA_ROOT/etc/profile.d/conda.sh`; set `CONDA_ROOT` if your conda lives somewhere other than the default in the scripts. The PCA check (`scripts/pca.R`) needs R.

## Data

`data/` holds MSMC multihetsep files for 46 cats on chromosomes A1 and A2, the individual order (`cat_orders.txt`) and the folded 33 x 13 spectrum the fits used (`data.fs`). Only two groups are analysed:

| Population | Individuals | Haplotype columns |
|---|---|---|
| Scottish wildcat (wild-caught) | 16 | 0–31 |
| Domestic | 6 | 52–63 |

Captive Scottish cats (32–51) and mainland European wildcats (64–91) are in the files but excluded, due to the large variation in Hudson's $F_{ST}$ value between populations. `scripts/pooling_check.py` quantifies this.

Fixed constants: callable length L = 22,488,648 bp, µ = 0.86e-8 per bp per generation, generation time 3 years.

## Models

| Name | Function | Free parameters |
|---|---|---|
| `sec_contact` | `dadi.Demographics2D.sec_contact_asym_mig` | 6 |
| `basic` | `wildcat_domestic` | 11 |
| `growth` | `wildcat_domestic_growth` | 13 |

`basic` and `growth` are constrained (TA > max(TB, TD)) and fitted with COBYLA; `sec_contact` uses Nelder-Mead in log space. Full parameterisations can be found in the [model schematic](plots/model.pdf).

Note that migration subscripts name the receiving population first in `sec_contact` (dadi convention) but the source population first in `basic` and `growth`.

## Usage

All commands are run from the repository root.

1. Build the spectrum and bootstrap replicates:

       mkdir -p logs && sbatch scripts/submit_sfs.sh

2. Fit each model (four chained rounds of 50 restarts):

       sbatch scripts/run_stages.sh sec_contact
       sbatch scripts/run_stages.sh basic
       sbatch scripts/run_stages.sh growth

   The best fit for each model is written to `results_wild/best_<model>_r4.json`.

3. Compare models and compute intervals. Polishing the `growth` fit can take hours, so give it the compute partition:

       sbatch --partition=compute --time=24:00:00 scripts/submit_report.sh sec_contact basic growth

4. Compute correlation matrices from the stored Godambe matrices (no refitting, takes seconds):

       sbatch scripts/submit_corr.sh

Every stage writes to `WILDCAT_OUTDIR` (default `results_wild/`, ignored by git).

## Outputs

- `model_comparison.csv`: log-likelihoods, effective parameter counts and CLAIC
- Per-model parameter CSVs with 95% confidence intervals and physical values
- `fit_<model>.png`: observed and expected spectra with Anscombe residuals
- `claic_<model>.pkl`: Godambe H and J matrices
- `corr_<model>.csv` and `.pdf`: parameter correlation matrices (parameter order follows `wildcat_models.py`)

Each run writes a metadata file recording its parameters, including the bootstrap seed, so CLAIC values and intervals can be reproduced exactly.

The committed `results/` tree is a copy of the final outputs: `models/` holds the fits, intervals, comparison and fit figures, `correlation/` the correlation matrices.

## Files

    scripts/
      wildcat_pipeline.py    spectrum, fitting, rescaling, report
      wildcat_models.py      model functions and bounds
      claic.py               CLAIC calculation
      plot_corr.py           correlation matrices from stored H and J
      pooling_check.py       pooled vs wild-only spectra
      pca.R                  PCA of one chromosome, to check the column-to-population mapping
      submit_sfs.sh          build spectrum and bootstraps
      run_stages.sh          submit four-round staged optimisation
      submit_stage.sh        single round, as a job array
      submit_report.sh       CLAIC comparison, intervals, figures
      submit_corr.sh         correlation matrices
    data/                    input multihetsep files, individual order, folded spectrum
    plots/                   spectrum (jsfs.png), model schematic (model.pdf), PCA (chr1_pca.pdf, chr2_pca.pdf)
    results/
      models/                fits, intervals, comparison, fit figures
      correlation/           correlation matrices
    environment.yml          conda environment

## Credits

This project was supervised by Mark Beaumont, Dennis Prangle and Grace Yan. Model specification by Mark Beaumont. `wildcat_models.py` and `claic.py` were specified by Dennis Prangle through the use of Claude LLM.

All code was submitted via the computational facilities of the [Advanced Computing Research Centre](http://www.bristol.ac.uk/acrc/), University of Bristol.
