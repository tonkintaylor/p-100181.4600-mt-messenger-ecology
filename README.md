# Mt Messenger Ecology Pipeline

<!-- badges: start -->
![R Version](<https://img.shields.io/badge/R-4.5-blue>)
![Licence](<https://img.shields.io/badge/licence-proprietary-red>)
<!-- badges: end -->

Automated data processing and figure generation for Mt Messenger aquatic
ecology monitoring reports.

**Job number:** 100181.4600

**For usage instructions see [docs/usage.md](docs/usage.md).**

## Pipeline Architecture

```mermaid
flowchart TD
    Config[/"cycle.toml"/] --> DataCmd
    Config --> PipelineCmd
    Config --> AllCmd

    subgraph EntryPoints ["R entry points"]
        DataCmd["Rscript src/r/run_data.R"]
        PipelineCmd["Rscript src/r/run_pipeline.R"]
        AllCmd["Rscript src/r/run_all.R"]
    end

    DataCmd --> Pipeline
    PipelineCmd --> Pipeline
    AllCmd --> RFigures

    subgraph Sources ["Source Spreadsheets"]
        MacroDB[("Macroinvertebrate\nDatabase.xlsx")]
        AquaticDB[("Aquatic Monitoring\nDatabase.xlsx")]
    end

    MacroDB --> Macro
    MacroDB --> MacroSpecies
    AquaticDB --> Sediment
    AquaticDB --> SedimentSize
    AquaticDB --> Clarity
    AquaticDB --> RPD
    AquaticDB --> LDV

    subgraph Pipeline ["R data pipeline"]
        subgraph Domains ["Domain processors"]
            Macro["Macroinvertebrate metrics"]
            MacroSpecies["Species data"]
            Sediment["Sediment"]
            SedimentSize["Grain size"]
            Clarity["Water clarity"]
            RPD["Residual pool depth"]
            LDV["Low-flow depth variability"]
        end
    end

    Macro --> Merge
    MacroSpecies --> Merge
    Sediment --> Merge
    SedimentSize --> Merge
    Clarity --> Merge
    RPD --> Merge
    LDV --> Merge

    Merge{All OK?}
    Merge -->|yes| Writer
    Merge -->|no| Errors

    Writer["Write xlsx"] --> DataOutput[/"MtMessengerEcologyData.xlsx"/]
    Errors --> ErrReport["Error summary\nexit code 1"]

    PipelineCmd --> RFigures
    DataOutput --> RFigures

    subgraph RFigures ["R figure pipeline"]
        Rscript["Rscript src/r/run_all.R"]
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

### Running R code

Use the Rscript entry points for normal operation. All scripts activate
renv explicitly before loading packages.

```powershell
# Data pipeline only
Rscript --vanilla src/r/run_data.R cycle.toml

# With validation (checks paths and config before running)
Rscript --vanilla src/r/run_data.R cycle.toml --validate

# Full pipeline: data + figures + tables
Rscript --vanilla src/r/run_pipeline.R cycle.toml

# Figures and tables only (requires the data xlsx to exist; reads paths from cycle.toml)
Rscript --vanilla src/r/run_all.R
```

For one-off diagnostics that do not need project packages, use `--vanilla`:

```powershell
Rscript --vanilla -e "sessionInfo()"
```

For one-off commands that do need project packages, bootstrap renv explicitly:

```powershell
Rscript --vanilla -e "source('renv/activate.R'); packageVersion('ggplot2')"
```

### Running tests

```powershell
Rscript --vanilla -e "source('renv/activate.R'); library(readxl); library(openxlsx); library(dplyr); library(tidyr); library(lubridate); testthat::test_dir('tests/r')"
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

```powershell
Rscript --vanilla -e "source('renv/activate.R'); renv::restore()"
```

Or just re-run `./tasks/dev_sync.ps1` — it restores R packages automatically.

## Licence

[Proprietary](LICENSE.txt) — Tonkin & Taylor Limited
