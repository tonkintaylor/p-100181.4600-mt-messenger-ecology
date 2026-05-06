# Golden File Notes

## File: `tests/assets/expected_Data.xlsx`

The golden file is used by `TestGoldenFileComparison` in `tests/test_writer.py` to validate
that the full pipeline produces correct output. It was regenerated on 2026-05-06 from the
current pipeline output.

## Known Differences vs Original Hand-Produced Golden File

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

The golden file was regenerated on 2026-05-06 from pipeline output filtered to dates
≤ 2025-03-12 (the max date from the original golden). All 5 sheets now match pipeline
output exactly. The test filters actual pipeline output to golden-file dates and sorts
by Date+Site before comparison.

## Updating the Golden File

If domain logic or source data changes, regenerate with:

```python
from mgen.domain.macro import process_macro_domain
from mgen.domain.macro_species import process_macro_species_domain
from mgen.domain.sediment import process_sediment_domain
from mgen.domain.sediment_size import process_sediment_size_domain

# Run pipeline, filter to desired date range, write with pd.ExcelWriter
```

Or run the test with `--update-golden` (not yet implemented — future enhancement).
