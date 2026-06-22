# Using the Mt Messenger Ecology Pipeline

This guide explains how to set up and run the R pipeline to produce
data spreadsheets, figures, and reference tables for the Mt Messenger
aquatic ecology monitoring reports.

## Quick Start

```powershell
# 1. Clone the repo
cd R:\BEKA\mt_messenger
git clone https://github.com/tonkintaylor/p-100181.4600-mt-messenger-ecology.git .

# 2. Install R and restore packages
./tasks/install.ps1

# 3. Edit cycle.toml with your paths (see Configuration below)

# 4. Run the full pipeline (data + figures + tables)
Rscript --vanilla src/r/run_pipeline.R cycle.toml
```

## Installation

### Prerequisites

- **Windows** with PowerShell
- **Git** (with Git Bash — included in [Git for Windows])
- **R 4.5+** — install from [CRAN](https://cran.r-project.org/) or let `install.ps1` do it

[Git for Windows]: https://git-scm.com/download/win

### Steps

Open **PowerShell** and run:

```powershell
cd R:\BEKA\mt_messenger
git clone https://github.com/tonkintaylor/p-100181.4600-mt-messenger-ecology.git .
./tasks/install.ps1
```

The install script will:

1. Install R if not already present (via winget)
2. Restore R packages from `renv.lock`
3. Create `cycle.toml` from the template

### Restoring R packages manually

If `./tasks/install.ps1` fails during R setup, restore packages manually
from the project root:

```powershell
Rscript --vanilla -e "source('renv/activate.R'); renv::restore()"
```

## Configuration

Edit `cycle.toml` in the repo root to set your input and output paths.
Use forward slashes (`/`) in all paths.

```toml
[input]
macroinvertebrate_db = "R:/BEKA/mt_messenger/input/MTMA Macroinvertebrate Database.xlsx"
aquatic_monitoring_db = "R:/BEKA/mt_messenger/input/MTMA Aquatic Monitoring Database.xlsx"

[output]
data_xlsx = "R:/BEKA/mt_messenger/output/MtMessengerEcologyData.xlsx"
figures_dir = "R:/BEKA/mt_messenger/output/Figures"
tables_dir = "R:/BEKA/mt_messenger/output/Tables"
```

| Key | Description |
|-----|-------------|
| `macroinvertebrate_db` | Path to the MTMA Macroinvertebrate Database xlsx |
| `aquatic_monitoring_db` | Path to the MTMA Aquatic Monitoring Database xlsx |
| `data_xlsx` | Where to write the consolidated data spreadsheet |
| `figures_dir` | Directory for generated PNG figures |
| `tables_dir` | Directory for generated reference tables (xlsx) |

Both network paths (`T:/...`) and local paths (`R:/...`) are supported.

Validate your config without running the pipeline:

```powershell
Rscript --vanilla src/r/run_data.R cycle.toml --validate
```

## Commands

| Command | Description |
|---------|-------------|
| `Rscript --vanilla src/r/run_pipeline.R cycle.toml` | Run data + figures back-to-back (most common) |
| `Rscript --vanilla src/r/run_data.R cycle.toml` | Process input databases → consolidated xlsx |
| `Rscript --vanilla src/r/run_data.R cycle.toml --validate` | Validate config and paths without writing output |
| `Rscript --vanilla src/r/run_all.R` | Generate R figures and tables from an existing data xlsx (paths read from `cycle.toml`) |

### run_all.R

Generates the figures and tables **only**, reading an already-produced
`MtMessengerEcologyData.xlsx`. It reads its input/output paths from `cycle.toml`
in the project root, so it takes **no positional arguments**:

```powershell
Rscript --vanilla src/r/run_all.R
```

> Do not pass `cycle.toml` to `run_all.R` — its first positional argument is the
> path to an existing data xlsx, not the config file. To run data + figures
> together from `cycle.toml`, use `run_pipeline.R` (below).

### run_data.R

Reads both monitoring databases, processes each domain (macroinvertebrate
metrics, species data, sediment, grain size, water clarity), and writes
a multi-sheet `MtMessengerEcologyData.xlsx`:

```powershell
Rscript --vanilla src/r/run_data.R cycle.toml
```

Pass `--validate` to check config and input paths without writing any output:

```powershell
Rscript --vanilla src/r/run_data.R cycle.toml --validate
```

### run_pipeline.R

The most common usage — runs the data pipeline and then the figure/table
pipeline back-to-back (the equivalent of `run_data.R` followed by `run_all.R`):

```powershell
Rscript --vanilla src/r/run_pipeline.R cycle.toml
```

## Output

### Figures

PNG plots organised by topic:

```
Figures/
├── Clarity/      Water clarity boxplots, time series, NTU scatter
├── Macro/        MCI, QMCI, taxa richness, EPT plots per site
├── NMDS/         Ordination plots, species overlays
└── Sediment/     Grain size, embeddedness, fine sediment plots
```

### Tables

XLSX reference tables:

```
Tables/
├── Community/    Composition summaries, indicator species
└── NMDS/         Site coordinates, species scores, reference taxa
```

### Data spreadsheet

`MtMessengerEcologyData.xlsx` with sheets for each domain:

- Macroinvertebrate metrics (`Macro`, `Macro1`)
- Macroinvertebrate species (`MacroSpecies`)
- Sediment (`Sediment`)
- Sediment grain size (`SedimentSize`)
- Water clarity (`Clarity`)
- Residual pool depth (`RPD`)
- Low-flow depth variability (`LDV`)

## Troubleshooting

### `Rscript` not found

R is often installed under a versioned directory such as
`C:\Program Files\R\R-4.5.3\bin`. Add that `bin` directory to PATH,
restart the terminal, then verify:

```powershell
Rscript --version
```

### R package installation fails

Restore packages manually from the project root:

```powershell
Rscript --vanilla -e "source('renv/activate.R'); renv::restore()"
```

### Input file not found

Check that the paths in `cycle.toml` use forward slashes and that the
files exist at those locations. Run `run_data.R --validate` to verify.

### Updating to a new version

Pull the latest code and re-run the installer:

```powershell
cd R:\BEKA\mt_messenger
git pull
./tasks/install.ps1
```

## R Package Management

R packages are managed by [renv](https://rstudio.github.io/renv/) for
reproducibility. The lockfile (`renv.lock`) pins exact versions so every
developer gets the same R environment.

### Adding an R package

```r
# In R, from the project root:
renv::install("newpackage")
```

Then add it to the `Imports` field in `DESCRIPTION` and update the lockfile:

```r
renv::snapshot()
```

Commit both `DESCRIPTION` and `renv.lock`.

### Restoring packages after a pull

```powershell
Rscript --vanilla -e "source('renv/activate.R'); renv::restore()"
```

Or just re-run `./tasks/dev_sync.ps1`.

## CI and Data Parity

The golden integration test (`tests/r/test-pipeline-integration.R`) skips automatically when the source databases are unreachable, so a green CI run alone does not certify data parity — parity must be confirmed on a machine with the source databases mounted.
