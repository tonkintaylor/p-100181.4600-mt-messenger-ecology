# Mt Messenger Ecology Figure Pipeline

<!-- badges: start -->
![Python Version](<https://img.shields.io/badge/python-3.13.2-green>)
[![Confluence](<https://img.shields.io/badge/Not_Configured-Confluence-lightgrey>)](<https://tonkintaylor.atlassian.net/wiki/home>)
![Licence](<https://img.shields.io/badge/licence-proprietary-red>)
[![Ruff](<https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/ruff/main/assets/badge/v2.json>)](<https://github.com/astral-sh/ruff>)
[![Jira](<https://img.shields.io/badge/Not_Configured-Jira-lightgrey>)](<https://tonkintaylor.atlassian.net/jira/projects>)
<!-- badges: end -->

## Introduction

Automated figure generation for regular reporting on Mt Messenger.

Job number: 100181.4600

## Pipeline Architecture

```mermaid
flowchart TD
    Config[/"cycle.toml"/] --> CLI

    subgraph CLI ["cli.py"]
        DataCmd["mgen data"]
        FigCmd["mgen figures"]
        AllCmd["mgen all"]
    end

    DataCmd --> Pipeline
    AllCmd --> Pipeline
    AllCmd --> RFigures

    subgraph Pipeline ["pipeline.py"]
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

    subgraph Domains ["domain/"]
        Macro["process_macro_domain()\nmacro.py"]
        MacroSpecies["process_macro_species_domain()\nmacro_species.py"]
        Sediment["process_sediment_domain()\nsediment.py"]
        SedimentSize["process_sediment_size_domain()\nsediment_size.py"]
    end

    Macro --> Merge
    MacroSpecies --> Merge
    Sediment --> Merge
    SedimentSize --> Merge

    Merge{All OK?}
    Merge -->|yes| Writer
    Merge -->|no| Errors

    subgraph Writer ["writer.py"]
        WriteXlsx["write_data_xlsx()"]
    end

    Writer --> DataOutput[/"MtMessengerEcologyData.xlsx\n6 sheets"/]
    Errors --> ErrReport["Human-readable\nerror summary\nexit code 1"]

    FigCmd --> RFigures
    DataOutput --> RFigures

    subgraph RFigures ["R pipeline (src/r/run_all.R)"]
        Rscript["Rscript via subprocess"]
    end

    RFigures --> Figures[/"figures/\nPNG plots"/]
    RFigures --> Tables[/"tables/\nXLSX tables"/]
```

## Running the Pipeline

After setup, three commands are available:

```Powershell
# Process input spreadsheets → MtMessengerEcologyData.xlsx
mgen data

# Generate figures from the data xlsx (runs R pipeline)
mgen figures

# Generate figures from a manually edited copy
mgen figures --data ./my-edited-copy.xlsx

# Run data processing + figures back-to-back
mgen all

# Validate config without running anything
mgen validate
```

All commands accept an optional path to `cycle.toml` (defaults to `./cycle.toml`).

## Getting Started

### Quick install (pipeline users)

Run this in Windows PowerShell from the repo root to install Python, R, and
the `mgen` command — no developer tools required:

```Powershell
./tasks/install.ps1
```

Then edit `cycle.toml` with your input/output paths and run `mgen all`.

### Full developer setup

Includes linters, test tools, pre-commit hooks, and VS Code configuration:

```Powershell
./tasks/dev_sync.ps1
```

## Other Development Tasks

### Adding a dependency (or regenerating the requirements files.)

Add a lowercase name of the package to the [project].dependencies section of the
`pyproject.toml` file. You will then need to re-generate the requirements files and
install the package via:

```Powershell
./tasks/dev_sync.ps1
```

### Releasing a package version

Run the following command in Windows Powershell to release a new version of the package:

```Powershell
./tasks/release.ps1
```

The branch will be automatically created and pushed to the cloud, ready for a PR to be
created.

## Adding to changelog

Add a new file at `doc/whatsnew/{issue_num}.{entry_type}.md` where `{issue_num}` is
the JIRA issue number being worked on, and `{entry_type}` is one of `feature`, `bugfix`,
`doc`, `removal`, `newhome`, `test`, or `devconfig`.

In the file provide a description of the change that will appear in the changelog.
