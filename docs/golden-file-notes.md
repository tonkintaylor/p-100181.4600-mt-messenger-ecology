# Golden File Notes

## File: `tests/r/assets/expected_Data.xlsx`

The golden file is used by the integration test in `tests/r/test-pipeline-integration.R`
(via the `compare_sheet_to_golden` helper in `tests/r/helper-golden.R`) to validate that
the full R data pipeline produces correct output. It is a verbatim copy of a vetted
pipeline output spreadsheet (`Data_20260514.xlsx`).

The test runs all seven domain processors against the real source databases named in
`cycle.toml` and compares **all eight output sheets** (Macro, Macro1, MacroSpecies,
Sediment, SedimentSize, Clarity, RPD, LDV) against the golden. It skips automatically
when the source databases are unreachable, so a green CI run alone does not certify data
parity — parity must be confirmed on a machine with the source databases mounted.

## Regenerated 2026-07-29 (RPD/LDV raw-sheet migration)

The golden was refreshed from a run of the `260722_` databases, replacing the
`Data_20260514.xlsx` snapshot. Three deliberate changes are baked into it, each
verified against the previous golden before the refresh:

1. **RPD and LDV are derived from the raw measurement sheets** (`Residual pool
   depths`, `LDV`) rather than read from the pre-summarised tabs. RPD
   `Count`/`Mean`/`StdDev` matched the previous golden **exactly**, and LDV
   `CV_pct` matched to ≤0.005 with the residual scattered in sign — the summary
   tabs' own rounding. That confirms sample (not population) standard deviation,
   Site × Date grouping, and `Count` = number of pools.
2. **RPD `CI_Lower`/`CI_Upper` are t-based** (`t(0.975, n-1) * sd / sqrt(n)`),
   replacing the z (1.96) values the `RPD Summary` tab stores. Author-confirmed:
   t only. The observed ratio was `t(0.975,2)/1.96 = 2.195` on every row, with
   midpoints unchanged — every RPD survey in the window has n=3 pools. Note this
   can push `CI_Lower` below zero on a 3-pool survey, which the z interval never
   did.
3. **The two EM3/EM7 event-based LDV survey dates come from the raw sheet**, which
   the report authors confirmed is correct; the `LDV Summary` tab had them wrong
   by roughly a fortnight each. Event-based surveys are still *included* in
   Appendix B1 Table 4 — they are not filtered by season.

Refresh the golden by copying a reviewed pipeline output over
`tests/r/assets/expected_Data.xlsx`, as the original was created.

## Known Differences vs Original Hand-Produced Golden File (historical, 2026-05-06)

> The tables in this section record a one-time reconciliation against the original
> hand-produced golden file. They are kept for historical context; the row counts and
> values below reflect the pipeline state at that time, not the current golden.

The original `expected_Data.xlsx` was manually produced (likely exported from the legacy
pipeline). When we compared our pipeline output against it, the following discrepancies
were identified before regeneration:

### Row Count Differences (source data updated since golden was created)

| Sheet        | Golden (old) | Pipeline | Cause                                            |
| ------------ | ------------ | -------- | ------------------------------------------------ |
| Macro        | 72           | 88       | Newer monitoring rounds added to source          |
| Macro1       | 174          | 214      | Newer monitoring rounds added to source          |
| MacroSpecies | 3193         | 3637     | Newer monitoring rounds added to source          |
| Sediment     | 78           | 87       | Newer monitoring rounds added to source          |
| SedimentSize | 78           | 87       | Newer monitoring rounds added to source          |

### Value Differences (source spreadsheet was modified post-golden-creation)

| Sheet       | Row (Date, Site)     | Column                   | Golden (old) | Pipeline | Delta |
| ----------- | -------------------- | ------------------------ | ------------ | -------- | ----- |
| Sediment    | 2024-11-18, EM7      | SAM1                     | 37.5         | 46.0     | +8.5  |
| SedimentSize| 2023-12-19, EM3      | Clay/silt (<0.06 mm)     | 34.78        | 34.67    | −0.11 |
| SedimentSize| 2023-12-19, EM3      | Large cobble (>128-256 mm) | 0.87       | 1.0      | +0.13 |

These are genuine source data corrections — the aquatic monitoring database was updated
after the original golden file was exported.

### Period/Season Mapping Differences (old golden used different classification)

The original golden file classified some early "Construction" monitoring rounds (Feb 2021,
Feb 2022) as Period="Baseline". Our pipeline applies a consistent rule:

| Raw Season Label | → Period              | → Season             |
| ---------------- | --------------------- | -------------------- |
| Baseline         | Baseline              | (month-based)        |
| Construction     | Routine Construction  | (month-based)        |
| Additional       | Incident              | incident response    |

Season is derived from sampling month: Oct/Nov/Dec → "Spring", Jan/Feb/Mar → "Summer".

The original golden file had 3 dates where raw="Construction" mapped to Period="Baseline":
- 2021-02-16, 2021-02-18, 2022-02-28

This likely reflects the old golden being produced from an earlier version of the source
spreadsheet where those dates were still labelled "Baseline".

### Missing/Extra Dates

The original golden file contained Date=2021-12-23 which does not exist in the current
source spreadsheet (our source has 2021-12-21 instead). This confirms the source was
revised after the golden was originally exported.

## Current State

The current golden file is a copy of `Data_20260514.xlsx`, which covers monitoring rounds
through early 2026. All **eight** sheets match the R pipeline output exactly:

| Sheet        | Data rows |
| ------------ | --------- |
| Macro        | 35        |
| Macro1       | 214       |
| MacroSpecies | 3637      |
| Sediment     | 87        |
| SedimentSize | 87        |
| Clarity      | 46        |
| RPD          | 31        |
| LDV          | 31        |

The test filters actual pipeline output to golden-file dates and sorts by Date+Site
before comparison, and ignores R vector name attributes (which have no xlsx equivalent
and are dropped on write).

## LDV "N/A" Season Coercion

The source "LDV Summary" sheet records the literal string `"N/A"` in the `Season` column
for dates that fall outside a defined monitoring season. The original Python pipeline read
the source with pandas, which treats `"N/A"` as a missing value by default, so the golden
file holds a blank cell there. R's `readxl` does **not** treat `"N/A"` as missing, so the
LDV domain processor (`src/r/data/domains/ldv.R`) explicitly coerces pandas-style NA
sentinels (`"N/A"`, `"NA"`, `"null"`, `"nan"`, `"none"`, `"#n/a"`, case-insensitive) in the
`Season` column to `NA`. This keeps the R output byte-identical to the golden. The
behaviour is locked in by a unit test in `tests/r/test-domain-ldv.R`.

## Season Normalisation Strategy (Macro vs Sediment)

The Macro and Sediment domains intentionally use **different** Season derivation logic,
reflecting differences in their source data formats:

| Domain   | Season Logic                                                    | "Additional" handling            |
| -------- | --------------------------------------------------------------- | -------------------------------- |
| Macro    | Month-based: Oct/Nov/Dec → Spring, else → Summer                | Season = "incident response"     |
| Sediment | Source-string matching: contains "Summer" → Summer, else Spring | Season remains Spring or Summer  |

**Why they differ:** The Macro source spreadsheet encodes monitoring phase in its
"Season" column (e.g. "Additional"), so the pipeline must derive calendar season from
the sampling date. The Sediment source already provides a meaningful season string
(e.g. "Summer 2024") but uses "Additional" only for the Period, so Season stays as
the calendar-derived value.

This means for incident monitoring events:
- Macro sheet: `Period="Incident", Season="incident response"`
- Sediment sheet: `Period="Incident", Season="Spring"` or `"Summer"`

This is **by design** and matches the original hand-produced golden file's conventions.

## Updating the Golden File

If domain logic or source data changes such that the new output is the intended
reference, regenerate the golden file from a vetted pipeline run:

```powershell
# 1. Run the data pipeline against the current source databases.
Rscript --vanilla src/r/run_data.R cycle.toml

# 2. Inspect the output, confirm it is correct, then copy it over the fixture.
Copy-Item <data_xlsx from cycle.toml> tests/r/assets/expected_Data.xlsx

# 3. Re-run the integration test on a machine with the source databases mounted.
Rscript --vanilla -e "source('renv/activate.R'); suppressPackageStartupMessages({library(readxl);library(openxlsx);library(dplyr);library(tidyr);library(lubridate)}); testthat::test_dir('tests/r')"
```

Only update the golden when the new output is deliberately the new reference — never to
make a failing test pass without first understanding why it changed.
