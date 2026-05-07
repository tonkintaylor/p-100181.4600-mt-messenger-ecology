"""Compare Python-generated tables against R golden references in ref/.

Usage:
    python scripts/compare_tables.py

Builds the Bray-Curtis dissimilarity matrix from MacroSpecies data (same
approach as R's MountMessMacroNMDSPlots.R), then compares against
ref/Dissimilarity_Table.xlsx. Also compares Data.xlsx sheets against ref/.
"""

from __future__ import annotations

from pathlib import Path

import pandas as pd

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parent.parent
REF_DIR = REPO_ROOT / "ref"
DATA_XLSX = REF_DIR / "Data.xlsx"

# Tolerance for floating-point comparisons
RTOL = 1e-5
ATOL = 1e-8


# ---------------------------------------------------------------------------
# Comparison helpers
# ---------------------------------------------------------------------------


def _values_close(a: object, b: object, *, rtol: float, atol: float) -> bool:
    """Compare two values with tolerance, handling NaN."""
    if pd.isna(a) and pd.isna(b):
        return True
    if pd.isna(a) or pd.isna(b):
        return False
    return abs(float(a) - float(b)) <= atol + rtol * abs(float(b))


def compare_dataframes(
    actual: pd.DataFrame,
    expected: pd.DataFrame,
    *,
    label: str = "",
    rtol: float = RTOL,
    atol: float = ATOL,
) -> list[str]:
    """Compare two DataFrames and return list of difference descriptions."""
    issues: list[str] = []
    prefix = f"[{label}] " if label else ""

    # Shape
    if actual.shape != expected.shape:
        issues.append(
            f"{prefix}Shape mismatch: got {actual.shape}, expected {expected.shape}"
        )
        return issues

    # Columns
    if list(actual.columns) != list(expected.columns):
        missing = set(expected.columns) - set(actual.columns)
        extra = set(actual.columns) - set(expected.columns)
        issues.append(
            f"{prefix}Column mismatch: "
            f"missing={missing or 'none'}, extra={extra or 'none'}"
        )
        return issues

    # Per-column value comparison
    for col in expected.columns:
        if pd.api.types.is_numeric_dtype(expected[col]):
            close = [
                _values_close(a, e, rtol=rtol, atol=atol)
                for a, e in zip(actual[col], expected[col], strict=True)
            ]
            n_bad = sum(not c for c in close)
            if n_bad > 0:
                diffs = (actual[col].astype(float) - expected[col].astype(float)).abs()
                max_diff = diffs.max()
                worst_idx = int(diffs.idxmax())
                issues.append(
                    f"{prefix}Column '{col}': {n_bad}/{len(close)} values "
                    f"differ (max_abs_diff={max_diff:.2e}, "
                    f"worst row={worst_idx})"
                )
        else:
            actual_s = actual[col].astype(str).fillna("__NULL__")
            expected_s = expected[col].astype(str).fillna("__NULL__")
            neq = actual_s != expected_s
            n_bad = int(neq.sum())
            if n_bad > 0:
                first_idx = int(neq.idxmax())
                issues.append(
                    f"{prefix}Column '{col}': {n_bad}/{len(neq)} values "
                    f"differ (first: row {first_idx}, "
                    f"got={actual[col].iloc[first_idx]!r}, "
                    f"expected={expected[col].iloc[first_idx]!r})"
                )

    return issues


# ---------------------------------------------------------------------------
# Dissimilarity table comparison
# ---------------------------------------------------------------------------


def _build_species_matrix_from_macro_species(
    macro_species: pd.DataFrame,
) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Replicate R's data prep: group by Site/Date, mean Tally, pivot wider.

    Returns (species_df, metadata) where species_df has species columns only
    and metadata has Site + Date in matching row order.
    """
    # Strip trailing spaces from column names (R artifact)
    macro_species.columns = [c.strip() for c in macro_species.columns]

    # R: group_by(Site, Phase, Date, Species) %>% summarise(Tally = mean(...))
    grouped = (
        macro_species.groupby(["Site", "Date", "Species"], observed=True)["Tally"]
        .mean()
        .reset_index()
    )

    # Pivot wider: species as columns, Tally as values, fill missing with 0
    pivoted = grouped.pivot_table(
        index=["Site", "Date"],
        columns="Species",
        values="Tally",
        fill_value=0,
    ).reset_index()

    pivoted.columns.name = None
    metadata = pivoted[["Site", "Date"]].copy()
    species_df = pivoted.drop(columns=["Site", "Date"])

    return species_df, metadata


def compare_dissimilarity_table() -> list[str]:
    """Build dissimilarity matrix from MacroSpecies and compare against ref.

    Comparison is order-independent: rows are matched by (Site, Date) key
    since R preserves insertion order while Python sorts alphabetically.
    """
    from mgen.stats.community import bray_curtis_matrix

    ref_path = REF_DIR / "Dissimilarity_Table.xlsx"
    if not ref_path.exists():
        return ["ref/Dissimilarity_Table.xlsx not found"]

    print("  Building species matrix from MacroSpecies sheet...")
    macro_species = pd.read_excel(DATA_XLSX, sheet_name="MacroSpecies")
    species_df, metadata = _build_species_matrix_from_macro_species(macro_species)

    print(f"  Species matrix shape: {species_df.shape}")
    print("  Computing Bray-Curtis distance matrix...")
    dm = bray_curtis_matrix(species_df)

    # Load reference
    expected = pd.read_excel(ref_path, sheet_name=0)

    # Build keys for row matching
    actual_keys = [
        f"{s}|{d}"
        for s, d in zip(metadata["Site"], metadata["Date"].astype(str), strict=True)
    ]
    ref_keys = [
        f"{s}|{d}"
        for s, d in zip(expected["Site"], expected["Date"].astype(str), strict=True)
    ]

    issues: list[str] = []

    # Check same set of samples
    actual_set = set(actual_keys)
    ref_set = set(ref_keys)
    if actual_set != ref_set:
        missing = ref_set - actual_set
        extra = actual_set - ref_set
        issues.append(
            f"[Dissimilarity_Table] Sample mismatch: "
            f"missing={len(missing)}, extra={len(extra)}"
        )
        if missing:
            issues.append(f"  Missing samples: {sorted(missing)[:5]}...")
        if extra:
            issues.append(f"  Extra samples: {sorted(extra)[:5]}...")
        return issues

    # Build mapping: ref row index -> actual row index (by key)
    actual_key_to_idx = {k: i for i, k in enumerate(actual_keys)}
    ref_to_actual = [actual_key_to_idx[k] for k in ref_keys]

    # Reorder our distance matrix to match ref row order, then compare
    n = len(ref_keys)
    num_cols = [str(i + 1) for i in range(n)]
    ref_dm = expected[num_cols].to_numpy()

    # Reorder dm rows and columns to match ref order
    actual_dm_reordered = dm[ref_to_actual][:, ref_to_actual]

    # Compare with tolerance
    close = abs(actual_dm_reordered - ref_dm) <= ATOL + RTOL * abs(ref_dm)
    n_bad = int((~close).sum())
    total = n * n

    if n_bad > 0:
        import numpy as np

        max_diff = float(abs(actual_dm_reordered - ref_dm).max())
        pct = n_bad / total * 100
        issues.append(
            f"[Dissimilarity_Table] {n_bad}/{total} values differ "
            f"({pct:.1f}%, max_abs_diff={max_diff:.6f})"
        )

        # Identify which rows contribute to mismatches
        row_bad = (~close).sum(axis=1)
        bad_rows = np.where(row_bad > 0)[0]
        if len(bad_rows) <= 10:
            for r in bad_rows:
                issues.append(
                    f"  Row {r} ({ref_keys[r]}): {row_bad[r]} mismatching distances"
                )
        else:
            issues.append(
                f"  {len(bad_rows)} rows affected "
                f"(likely stale ref — regenerate with R script)"
            )
    else:
        print(f"  ✅ All {total} distance values match (rtol={RTOL}, atol={ATOL})")

    return issues


# ---------------------------------------------------------------------------
# Data.xlsx sheet comparison (pipeline output vs R reference)
# ---------------------------------------------------------------------------


def compare_data_xlsx() -> list[str]:
    """Compare expected_Data.xlsx (test asset) against ref/Data.xlsx.

    Note: test asset may be a smaller subset. Shape mismatches are reported
    but not necessarily failures — they indicate different input data sizes.
    """
    test_asset = REPO_ROOT / "tests" / "assets" / "expected_Data.xlsx"
    ref_path = REF_DIR / "Data.xlsx"

    if not test_asset.exists():
        return [f"Test asset not found: {test_asset}"]
    if not ref_path.exists():
        return [f"Reference not found: {ref_path}"]

    issues: list[str] = []

    print("  Comparing Data.xlsx sheets...")
    actual_sheets = pd.read_excel(test_asset, sheet_name=None)
    ref_sheets = pd.read_excel(ref_path, sheet_name=None)

    actual_names = set(actual_sheets.keys())
    ref_names = set(ref_sheets.keys())

    missing = ref_names - actual_names
    extra = actual_names - ref_names
    if missing:
        issues.append(f"[Data.xlsx] Missing sheets: {missing}")
    if extra:
        issues.append(f"[Data.xlsx] Extra sheets (ok): {extra}")

    for sheet in sorted(actual_names & ref_names):
        sheet_issues = compare_dataframes(
            actual_sheets[sheet],
            ref_sheets[sheet],
            label=f"Data.xlsx/{sheet}",
        )
        issues.extend(sheet_issues)

    return issues


# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------


def _print_summary(all_issues: list[str]) -> None:
    """Print final summary."""
    if not all_issues:
        print("\n✅ All tables match golden references (within tolerance)")
        print(f"   rtol={RTOL}, atol={ATOL}")
    else:
        print(f"\n❌ {len(all_issues)} difference(s) found:\n")
        for issue in all_issues:
            print(f"  • {issue}")
        print(f"\n   Tolerance: rtol={RTOL}, atol={ATOL}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main() -> None:
    """Run all table comparisons."""
    print(f"Reference dir: {REF_DIR}")
    print(f"Data.xlsx:     {DATA_XLSX}")
    print()

    if not DATA_XLSX.exists():
        print(f"ERROR: {DATA_XLSX} not found")
        print("  This script requires ref/Data.xlsx")
        return

    all_issues: list[str] = []

    # 1) Dissimilarity table
    print("[1/2] Dissimilarity_Table.xlsx")
    all_issues.extend(compare_dissimilarity_table())

    # 2) Data.xlsx sheets
    print("[2/2] Data.xlsx sheets")
    all_issues.extend(compare_data_xlsx())

    _print_summary(all_issues)


if __name__ == "__main__":
    main()
