# Using the Mt Messenger Ecology Pipeline

This guide explains how to set up and run the `mgen` pipeline to produce
data spreadsheets, figures, and reference tables for the Mt Messenger
aquatic ecology monitoring reports.

## Quick Start

```powershell
# 1. Clone the repo
cd R:\BEKA\mt_messenger
git clone https://github.com/tonkintaylor/p-100181.4600-mt-messenger-ecology.git .

# 2. Install Python, R, and the mgen command
./tasks/install.ps1

# 3. Edit cycle.toml with your paths (see Configuration below)

# 4. Run the full pipeline
mgen all
```

## Installation

### Prerequisites

- **Windows** with PowerShell
- **Git** (with Git Bash — included in [Git for Windows])

Python and R are installed automatically by the install script.

[Git for Windows]: https://git-scm.com/download/win

### Steps

Open **PowerShell** and run:

```powershell
cd R:\BEKA\mt_messenger
git clone https://github.com/tonkintaylor/p-100181.4600-mt-messenger-ecology.git .
./tasks/install.ps1
```

The install script will:

1. Install [uv] (Python package manager) if needed
2. Create a `.venv` virtual environment and install dependencies
3. Install R and required R packages if needed
4. Create `cycle.toml` from the template

[uv]: https://docs.astral.sh/uv/

### Using `mgen` after install

After running `install.ps1`, the `mgen` command is available globally —
no virtual environment activation needed:

```powershell
cd R:\BEKA\mt_messenger
mgen all
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
mgen validate
```

## Commands

| Command | Description |
|---------|-------------|
| `mgen all` | Run data + figures back-to-back (most common) |
| `mgen data` | Process input databases → consolidated xlsx |
| `mgen figures` | Generate R figures and tables from the data xlsx |
| `mgen validate` | Check config and input paths without writing output |

### `mgen all`

The most common usage — processes both databases and generates all figures
and tables in one step:

```powershell
mgen all
```

### `mgen data`

Reads both monitoring databases, processes each domain (macroinvertebrate
metrics, species data, sediment, grain size, water clarity), and writes
a multi-sheet `MtMessengerEcologyData.xlsx`:

```powershell
mgen data
```

### `mgen figures`

Runs the R plotting pipeline against the data xlsx:

```powershell
mgen figures
```

To generate figures from a manually edited copy of the data:

```powershell
mgen figures --data R:\BEKA\mt_messenger\output\MtMessengerEcologyData_edited.xlsx
```

### Options

All commands accept:

- An optional path to a different config file: `mgen all path\to\cycle.toml`
- `-q` / `--quiet` to suppress status messages (errors still print)

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

- Macroinvertebrate metrics
- Macroinvertebrate species
- Sediment
- Sediment grain size
- Water clarity

## Troubleshooting

### `mgen` command not found

Re-run the install script to register `mgen` on your PATH:

```powershell
./tasks/install.ps1
```

If using a developer checkout, activate the virtual environment:

```powershell
.\.venv\Scripts\activate.ps1
```

### R package installation fails

If `./tasks/install.ps1` fails during R setup, restore packages manually
in R from the project root:

```r
source("renv/activate.R")
renv::restore()
```

### Input file not found

Check that the paths in `cycle.toml` use forward slashes and that the
files exist at those locations. Run `mgen validate` to verify.

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

```r
renv::restore()
```

Or just re-run `./tasks/install.ps1` or `./tasks/dev_sync.ps1`.
