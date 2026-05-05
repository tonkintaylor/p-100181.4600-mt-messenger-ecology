# Phase 1a Design — Data.xlsx Pipeline

**Date:** 2026-05-05
**Status:** Approved
**Scope:** Mt Messenger aquatic monitoring — automate production of `Data.xlsx` from source databases

## Problem Statement

The Mt Messenger Bypass aquatic monitoring workflow requires biannual production of `Data.xlsx` — a 5-sheet Excel file consumed by R scripts that generate ~90 plots and stats tables for the Freshwater Chapter. Today this is a manual process: someone copies derived metric values from two Excel databases into `Data.xlsx` by hand, introducing delay and risk of transcription error.

Phase 1a automates this bridge: one command reads the source databases and emits an identical `Data.xlsx`, with validation that catches data quality issues before they propagate to plots.

## Scope

**In scope (Phase 1a):**

- Macroinvertebrate metrics → Macro1 sheet (175×7) and Macro sheet (73×7)
- MacroSpecies → taxa tally long-format (3194×6)
- Sediment → SAM1/SAM3 (79×6)
- SedimentSize → 12 grain-size bins (79×16)
- Validation layer with collect-all error reporting
- Config file for per-cycle paths
- CLI entry point (`mgen run`)
- Unit tests on metric derivation + golden-file integration tests

**Out of scope:**

- Geotechnics lab report ingest (confirmed out of scope by Mike)
- Other database domains (Fish, Habitat, FieldWQ, LDV, RPD, Macrophytes)
- Phase 2 R script refactoring
- Report assembly

## Architecture

Domain-oriented modules with a thin orchestrator. Each domain is a bounded context owning its own ingest, validation, and transformation logic.

```
src/mgen/
  config.py              # Read cycle.toml, resolve/validate paths
  pipeline.py            # Orchestrator: load config, call domains, emit or report
  shared/
    __init__.py
    types.py             # Value objects: Site, Season, Period
    schemas.py           # Output DataFrame schemas (column names, dtypes)
    errors.py            # ValidationError with file/sheet/cell context
    validation.py        # Shared validation primitives (schema check, range, null)
  domains/
    __init__.py
    macro.py             # ACL + metric derivation + transform → Macro1 + Macro
    macro_species.py     # Shared ACL + taxa pivot → MacroSpecies
    macro_ingest.py      # Shared ACL: parse RawData multi-row header
    sediment.py          # ACL + reshape → Sediment
    sediment_size.py     # ACL + reshape → SedimentSize
  writer.py              # Infrastructure: DataFrame dict → Data.xlsx (5 sheets)
```

### DDD Patterns Applied

| Pattern | Where | Purpose |
|---------|-------|---------|
| Bounded Context | Each domain module | Isolates source-format knowledge and domain rules |
| Shared Kernel | `shared/types.py`, `shared/schemas.py`, `shared/validation.py` | Site, Season, Period, output schemas, validation primitives |
| Anti-Corruption Layer | `macro_ingest.py`, each domain's read step | Translates messy spreadsheet formats to clean internal model |
| Domain Service | Metric derivation in `macro.py` | Ecologist-signed logic, testable independently |
| Value Object | Site, Season, Period | Validated, immutable domain concepts |
| Aggregate | `DomainResult` per module | Complete output or errors, never partial |

### Data Flow

```
cycle.toml (paths)
       │
       ▼
┌─────────────────────────────────────────────┐
│ pipeline.py (orchestrator)                  │
│  1. Load & validate config                  │
│  2. Call each domain module                 │
│  3. Collect results (data or errors)        │
│  4. All clean → writer → Data.xlsx          │
│  5. Any errors → report & exit non-zero     │
└─────────────────────────────────────────────┘
       │ calls
       ├── macro.py (uses macro_ingest.py)
       │     → Macro1, Macro DataFrames
       ├── macro_species.py (uses macro_ingest.py)
       │     → MacroSpecies DataFrame
       ├── sediment.py
       │     → Sediment DataFrame
       └── sediment_size.py
             → SedimentSize DataFrame
```

## Config Interface

A TOML file per monitoring cycle:

```toml
[input]
macroinvertebrate_db = "T:/Wellington/TT Projects/1001181/1001181.4500/WorkingMaterial/Aquatic Monitoring/Aquatic monitoring spreadsheets/MTMA Macroinvertebrate Database.xlsx"
aquatic_monitoring_db = "T:/Wellington/TT Projects/1001181/1001181.4500/WorkingMaterial/Aquatic Monitoring/Aquatic monitoring spreadsheets/MTMA Aquatic Monitoring Database.xlsx"

[output]
data_xlsx = "T:/Wellington/TT Projects/1001181/1001181.4500/WorkingMaterial/Aquatic Monitoring/2025-2026 Report/Stats/Data.xlsx"
```

**CLI:**

```
mgen run cycle.toml          # run pipeline with explicit config
mgen run                     # looks for cycle.toml in current directory
mgen validate cycle.toml     # check inputs without writing output
```

Phase 2 R scripts will read the same `cycle.toml` for path consistency.

## Error Handling

**Strategy:** Collect all validation errors across all domains, then report together.

**Result type per domain:**

```python
@dataclass
class DomainResult:
    data: dict[str, pd.DataFrame] | None  # sheet_name → DataFrame
    errors: list[ValidationError]

@dataclass(frozen=True)
class ValidationError:
    domain: str       # e.g. "macroinvertebrate"
    severity: str     # "error" or "warning"
    file: str         # source filename
    sheet: str        # sheet name
    location: str     # e.g. "row 47, col F"
    message: str      # human-readable description
```

**Orchestrator behaviour:**

- Any errors with severity "error" → full error report printed, exit non-zero, no output file
- Only warnings → print warnings, emit Data.xlsx, exit zero
- Clean → emit Data.xlsx, print summary, exit zero

## Testing Strategy

Three layers, aligned with `.agents/skills/testing-python-*`:

| Layer | What | How | Skill |
|-------|------|-----|-------|
| Unit | Metric derivation functions | Precise numerical assertions, parametrized with boundary values | `testing-python-units` |
| Contract | Domain module outputs | Schema assertions on DataFrames (columns, dtypes, ranges) | `testing-python-core` |
| Integration | Full pipeline | Golden-file comparison against current Data.xlsx (within float tolerance) | Real I/O on fixture data |

**Key conventions from testing skills:**

- AAA pattern (arrange/act/assert)
- Mock only external boundaries (file I/O); never mock internal domain logic
- Don't test value objects directly — exercise through domain functions
- Don't unit-test orchestrator — covered by integration test
- Parametrize with tuple syntax and ids
- Equivalence classes + boundary values, not exhaustive permutations

**Fixtures:** Trimmed copies of Mike's example databases committed to `tests/fixtures/`.

## Issue Breakdown

10 issues, each a reviewable PR delivering a testable slice.

### Issue 1: Project scaffolding & config

- `config.py` with TOML loading and path validation
- `shared/errors.py` with `ValidationError`
- CLI entry point skeleton (`mgen run`)
- `cycle.toml` example in repo root
- Tests: config loads valid TOML, rejects missing paths

### Issue 2: Shared kernel — types & schemas

- `shared/types.py`: Site, Season, Period value objects
- `shared/schemas.py`: output column specs and dtypes for all 5 sheets
- `validation.py`: shared primitives (schema check, range assertion, null detection)
- Tests: exercised via later domain tests (no direct VO tests per skill rules)

### Issue 3: Macroinvertebrate ACL — ingest RawData

- `domains/macro_ingest.py`: parse multi-row header (rows 1-5), extract sample metadata, produce clean internal DataFrame
- Handles: QA-flagged columns, missing replicates, season/date/site extraction
- Shared between macro and macro_species domains
- Tests: header parsing with boundary cases

### Issue 4: Macroinvertebrate domain — metric derivation

- Domain service in `domains/macro.py`: MCI, MCI-sb, QMCI, QMCI-sb, EPT richness/abundance, %EPT, ASPM-MCI
- QMCI-sb routing for non-replicate sites (E1, E2, E4, E8)
- EPT membership derived from taxa group labels (not hard-coded row numbers)
- Tests: precise numerical assertions against spreadsheet formula results

### Issue 5: Macroinvertebrate domain — emit Macro1 + Macro

- Transform derived metrics → Macro1 (175×7, full precision)
- Aggregate replicated sites → Macro (73×7, means)
- Schema validation on output
- Tests: schema contract + golden-file comparison for both sheets

### Issue 6: MacroSpecies domain — taxa pivot

- Wide-to-long pivot of taxa rows (6-146)
- Zero-fill absent taxa, join with sample metadata
- Emit MacroSpecies (3194×6)
- Tests: schema contract + golden-file comparison

### Issue 7: Sediment domain — ingest & reshape

- Read Aquatic Monitoring DB Sediment tab
- Reshape → Sediment (79×6): Site, Date, Period, SAM1, SAM3, Season
- Tests: schema contract + golden-file comparison

### Issue 8: SedimentSize domain — ingest & reshape

- Read Aquatic Monitoring DB SedimentSize data
- Reshape → SedimentSize (79×16): Site, Date, Period, Season + 12 grain-size bins
- Tests: schema contract + golden-file comparison

### Issue 9: Writer — emit Data.xlsx

- Assemble all domain outputs into 5-sheet xlsx
- Preserve exact column types, date formats, and sheet order R scripts expect
- Tests: golden-file comparison of full output against example Data.xlsx

### Issue 10: Pipeline orchestrator & integration

- `pipeline.py` wires config → domains → writer
- Error collection and human-readable reporting
- CLI integration (exit codes, summary output)
- Tests: end-to-end integration test on fixture data; error-reporting test with intentionally bad data

### Dependency Graph

```
#1 (scaffolding)
├── #2 (shared kernel)
│   ├── #3 (macro ACL)
│   │   ├── #4 (metric derivation)
│   │   │   └── #5 (emit Macro1/Macro)
│   │   └── #6 (MacroSpecies pivot)
│   ├── #7 (sediment)
│   └── #8 (sediment size)
└────────────────────────────────┐
                                 ▼
                    #9 (writer) ← #5, #6, #7, #8
                         │
                         ▼
                    #10 (orchestrator + integration)
```

Issues #7 and #8 can be worked in parallel with #3-6 once #1 and #2 are complete.

## Key Domain Decisions

| Decision | Rationale |
|----------|-----------|
| Python + pandas + openpyxl | Mainstream, hireable, testable. Aligns with T+T skills. |
| Macro1 is canonical | Mike confirmed. Macro sheet derived by aggregating means for replicated sites. |
| QMCI-sb for E1, E2, E4, E8 | Sites without replicates use soft-bottom variant. Encoded explicitly. |
| EPT from taxa group labels | Not hard-coded row numbers. Survives taxa additions/reordering. |
| Data.xlsx format preserved exactly | R scripts read unchanged. Automation slots in behind, not in place of. |
| No partial output | Pipeline either succeeds completely or reports all errors. |

## Phase 2 Compatibility

- `cycle.toml` will be shared with Phase 2 R scripts for path consistency
- `Data.xlsx` format is the stable interface contract between phases
- Architecture supports adding new domains (Fish, Habitat, etc.) as new modules without modifying existing ones
