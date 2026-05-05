"""Shared validation primitives for domain modules."""

from __future__ import annotations

import pandas as pd

from mgen.shared.errors import ValidationError


def check_required_columns(
    df: pd.DataFrame,
    expected: list[str],
    *,
    domain: str,
    file: str,
    sheet: str,
) -> list[ValidationError]:
    """Check that all expected columns are present in a DataFrame."""
    missing = set(expected) - set(df.columns)
    if not missing:
        return []
    return [
        ValidationError(
            domain=domain,
            severity="error",
            file=file,
            sheet=sheet,
            location="header",
            message=f"Missing required columns: {sorted(missing)}",
        )
    ]


def check_no_nulls(
    df: pd.DataFrame,
    columns: list[str],
    *,
    domain: str,
    file: str,
    sheet: str,
) -> list[ValidationError]:
    """Check that specified columns have no null values."""
    errors: list[ValidationError] = []
    for col in columns:
        if col not in df.columns:
            continue
        null_mask = df[col].isna()
        if null_mask.any():
            null_rows = df.index[null_mask].tolist()
            first_few = null_rows[:5]
            errors.append(
                ValidationError(
                    domain=domain,
                    severity="error",
                    file=file,
                    sheet=sheet,
                    location=f"column '{col}', rows {first_few}",
                    message=(
                        f"Found {null_mask.sum()} null values"
                        f" in required column '{col}'"
                    ),
                )
            )
    return errors


def check_value_range(
    df: pd.DataFrame,
    column: str,
    *,
    min_val: float | None = None,
    max_val: float | None = None,
    domain: str,
    file: str,
    sheet: str,
) -> list[ValidationError]:
    """Check that numeric values fall within an expected range."""
    errors: list[ValidationError] = []
    if column not in df.columns:
        return errors

    series = pd.to_numeric(df[column], errors="coerce")

    # Detect non-numeric values that were silently coerced to NaN
    coerced_nans = series.isna() & ~df[column].isna()
    if coerced_nans.any():
        bad_rows = df.index[coerced_nans].tolist()[:5]
        errors.append(
            ValidationError(
                domain=domain,
                severity="error",
                file=file,
                sheet=sheet,
                location=f"column '{column}', rows {bad_rows}",
                message=(
                    f"Found {coerced_nans.sum()} non-numeric values"
                    f" in column '{column}'"
                ),
            )
        )

    if min_val is not None:
        below = series < min_val
        if below.any():
            bad_rows = df.index[below].tolist()[:5]
            errors.append(
                ValidationError(
                    domain=domain,
                    severity="error",
                    file=file,
                    sheet=sheet,
                    location=f"column '{column}', rows {bad_rows}",
                    message=f"Values below minimum {min_val} in column '{column}'",
                )
            )

    if max_val is not None:
        above = series > max_val
        if above.any():
            bad_rows = df.index[above].tolist()[:5]
            errors.append(
                ValidationError(
                    domain=domain,
                    severity="error",
                    file=file,
                    sheet=sheet,
                    location=f"column '{column}', rows {bad_rows}",
                    message=f"Values above maximum {max_val} in column '{column}'",
                )
            )

    return errors
