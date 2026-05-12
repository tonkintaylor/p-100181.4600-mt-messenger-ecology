# Mt Messenger Ecology Pipeline

<!-- badges: start -->
![Python Version](<https://img.shields.io/badge/python-3.13-green>)
![R Version](<https://img.shields.io/badge/R-4.5-blue>)
![Licence](<https://img.shields.io/badge/licence-proprietary-red>)
[![Ruff](<https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/ruff/main/assets/badge/v2.json>)](<https://github.com/astral-sh/ruff>)
<!-- badges: end -->

Automated data processing and figure generation for Mt Messenger aquatic
ecology monitoring reports.

**Job number:** 100181.4600

**For usage instructions see [docs/usage.md](docs/usage.md).**

## Pipeline Architecture

```mermaid
flowchart TD
    Config[/"cycle.toml"/] --> CLI

    subgraph CLI ["mgen CLI"]
        DataCmd["mgen data"]
        FigCmd["mgen figures"]
        AllCmd["mgen all"]
    end

    DataCmd --> Pipeline
    AllCmd --> Pipeline
    AllCmd --> RFigures

    subgraph Pipeline ["Python data pipeline"]
        RunPipeline["run_pipeline()"]
    end

    subgraph Sources ["Source Spreadsheets"]
        MacroDB[("Macroinvertebrate\nDatabase.xlsx")]
        AquaticDB[("Aquatic Monitoring\nDatabase.xlsx")]
    end

    MacroDB --> Macro
    MacroDB --> MacroSpecies
    AquaticDB --> Sediment
    AquaticDB --> SedimentSize
    AquaticDB --> Clarity

    subgraph Domains ["Domain processors"]
        Macro["Macroinvertebrate metrics"]
        MacroSpecies["Species data"]
        Sediment["Sediment"]
        SedimentSize["Grain size"]
        Clarity["Water clarity"]
    end

    Macro --> Merge
    MacroSpecies --> Merge
    Sediment --> Merge
    SedimentSize --> Merge
    Clarity --> Merge

    Merge{All OK?}
    Merge -->|yes| Writer
    Merge -->|no| Errors

    Writer["Write xlsx"] --> DataOutput[/"MtMessengerEcologyData.xlsx"/]
    Errors --> ErrReport["Error summary\nexit code 1"]

    FigCmd --> RFigures
    DataOutput --> RFigures

    subgraph RFigures ["R figure pipeline"]
        Rscript["Rscript run_all.R"]
    end

    RFigures --> Figures[/"Figures/\nPNG plots"/]
    RFigures --> Tables[/"Tables/\nXLSX reference tables"/]
```

## Getting Started

### Pipeline users

See [docs/usage.md](docs/usage.md) for installation and usage instructions.

### Developers

Full developer setup with linters, test tools, pre-commit hooks, and
VS Code configuration:

```powershell
./tasks/dev_sync.ps1
```

## Development

### Running Python code

Python code is run through uv to ensure the virtual environment is used:

```powershell
uv run python src/scripts/my_script.py
uv run mgen data
```

### Running R code

R scripts can be run directly with Rscript. The `.Rprofile` activates
renv automatically:

```powershell
Rscript src/r/run_all.R
```

### Running tests

```powershell
uv run pytest
```

### Managing Python packages

Python dependencies are managed by [uv](https://docs.astral.sh/uv/) with
versions locked in `uv.lock`.

**Adding a package:**

1. Add the package to `[project].dependencies` in `pyproject.toml`
2. Run `./tasks/dev_sync.ps1` (updates `uv.lock` and installs)

**Restoring after a pull:**

```powershell
./tasks/dev_sync.ps1
```

### Managing R packages

R dependencies are managed by [renv](https://rstudio.github.io/renv/) with
versions locked in `renv.lock`. The `DESCRIPTION` file declares the direct
R package dependencies.

**Adding a package:**

1. In R from the project root: `renv::install("newpackage")`
2. Add the package to the `Imports` field in `DESCRIPTION`
3. Update the lockfile: `renv::snapshot()`
4. Commit both `DESCRIPTION` and `renv.lock`

**Restoring after a pull:**

```r
renv::restore()
```

Or just re-run `./tasks/dev_sync.ps1` — it restores both Python and R
packages automatically.

## Licence

[Proprietary](LICENSE.txt) — Tonkin & Taylor Limited
