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

### Running tests

```powershell
uv run pytest
```

### Adding a dependency

Add the package to `[project].dependencies` in `pyproject.toml`, then:

```powershell
./tasks/dev_sync.ps1
```

### Releasing a version

```powershell
./tasks/release.ps1
```

The branch will be automatically created and pushed, ready for a PR.

### Changelog

Add a new file at `doc/whatsnew/{issue_num}.{entry_type}.md` where
`{entry_type}` is one of `feature`, `bugfix`, `doc`, `removal`,
`newhome`, `test`, or `devconfig`.

## Licence

[Proprietary](LICENSE.txt) — Tonkin & Taylor Limited
