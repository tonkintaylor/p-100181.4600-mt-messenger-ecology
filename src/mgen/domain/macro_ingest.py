"""Anti-corruption layer for the Macroinvertebrate Database RawData sheet.

Parses the multi-row header (rows 1-5) and separates taxa count data
from derived metric rows. This module is shared between the macro and
macro_species domain modules.

RawData layout (1-indexed as seen in Excel):
  Row 1: QA Note flags (informational, not used for filtering)
  Row 2: Season label (Baseline / Construction / Additional / Routine)
  Row 3: Date
  Row 4: Site (EM1, EM2, ..., MMA 6, MMA 6b)
  Row 5: Replicate (1-5 or blank for unreplicated site-dates)
  Rows 6-146: Taxa counts (141 rows, grouped by common name)
  Row 147+: Derived metric formulas (boundary marker: "Number of Taxa" in col B)
  Columns A-B: TaxonGroup, Taxon (scientific name)
  Columns C-D: MCI tolerance value, MCI-sb tolerance value
  Columns E onward: Sample data (one col per site x date x replicate)
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import pandas as pd


@dataclass
class RawDataBundle:
    """Clean internal representation of the RawData sheet.

    Produced by the ACL. Consumers (macro, macro_species) use
    whichever parts they need.
    """

    sample_metadata: pd.DataFrame
    """One row per sample column.

    Columns: column_index, Season, Date, Site, Replicate.
    """

    taxa_counts: pd.DataFrame
    """One row per taxon.

    Columns: TaxonGroup, Taxon, then one col per sample (Int64).
    """

    metric_rows: pd.DataFrame
    """Derived metrics. Columns: Metric, then one col per sample (float64)."""

    mci_scores: pd.DataFrame
    """MCI tolerance values. Columns: Taxon, MCI, MCI_sb (float64)."""


_METRICS_MARKER = "Number of Taxa"
_HEADER_ROW_COUNT = 5  # QA, Season, Date, Site, Replicate
_DATA_COL_START = 4  # 0-indexed: A=0, B=1, C=2, D=3, E=4


def ingest_raw_data(macro_db_path: Path) -> RawDataBundle:
    """Parse the RawData sheet into clean internal components.

    This is the ONLY place that knows about the messy multi-row header format.
    All downstream domain modules receive clean DataFrames.
    """
    raw = pd.read_excel(
        macro_db_path,
        sheet_name="RawData",
        header=None,
        dtype=object,
    )

    sample_metadata = _extract_sample_metadata(raw)
    taxa_block, metric_block = _split_at_metrics_marker(raw)
    sample_col_indices = list(range(_DATA_COL_START, raw.shape[1]))
    taxa_counts = _build_taxa_counts(taxa_block, sample_col_indices)
    mci_scores = _build_mci_scores(taxa_block)
    metric_rows = _build_metric_rows(metric_block, sample_col_indices)

    return RawDataBundle(
        sample_metadata=sample_metadata,
        taxa_counts=taxa_counts,
        metric_rows=metric_rows,
        mci_scores=mci_scores,
    )


def _extract_sample_metadata(raw: pd.DataFrame) -> pd.DataFrame:
    """Extract per-sample metadata from the 5 header rows."""
    sample_col_indices = list(range(_DATA_COL_START, raw.shape[1]))

    seasons = raw.iloc[1, _DATA_COL_START:].to_numpy()
    dates = pd.to_datetime(raw.iloc[2, _DATA_COL_START:].to_numpy(), errors="coerce")
    sites = raw.iloc[3, _DATA_COL_START:].astype(str).str.strip().to_numpy()
    replicates = raw.iloc[4, _DATA_COL_START:].to_numpy()

    meta = pd.DataFrame(
        {
            "column_index": sample_col_indices,
            "Season": seasons,
            "Date": dates,
            "Site": sites,
            "Replicate": replicates,
        }
    )

    # Coerce Replicate to nullable integer (NaN for blanks)
    meta["Replicate"] = pd.to_numeric(meta["Replicate"], errors="coerce").astype(
        "Int64"
    )

    return meta.reset_index(drop=True)


def _split_at_metrics_marker(
    raw: pd.DataFrame,
) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Split data rows at the 'Number of Taxa' marker.

    Returns (taxa_block, metric_block) where both are sub-DataFrames
    of the raw sheet starting after the header rows.
    """
    data_block = raw.iloc[_HEADER_ROW_COUNT:].reset_index(drop=True)

    col_b = data_block.iloc[:, 1].astype(str).str.strip()
    marker_indices = col_b[col_b == _METRICS_MARKER].index

    if len(marker_indices) == 0:
        return data_block, pd.DataFrame()

    split_at = marker_indices[0]
    taxa_block = data_block.iloc[:split_at].reset_index(drop=True)
    metric_block = data_block.iloc[split_at:].reset_index(drop=True)

    return taxa_block, metric_block


def _build_taxa_counts(
    taxa_block: pd.DataFrame, sample_col_indices: list[int]
) -> pd.DataFrame:
    """Build taxa counts DataFrame from the taxa data block."""
    meta_part = pd.DataFrame(
        {
            "TaxonGroup": taxa_block.iloc[:, 0].to_numpy(),
            "Taxon": taxa_block.iloc[:, 1].to_numpy(),
        }
    )

    sample_data: dict[int, pd.array] = {}
    for i, col_idx in enumerate(sample_col_indices):
        numeric = pd.to_numeric(
            taxa_block.iloc[:, _DATA_COL_START + i].to_numpy(), errors="coerce"
        )
        sample_data[col_idx] = pd.array(numeric, dtype="Int64")

    sample_part = pd.DataFrame(sample_data)
    return pd.concat([meta_part, sample_part], axis=1)


def _build_mci_scores(taxa_block: pd.DataFrame) -> pd.DataFrame:
    """Extract MCI and MCI-sb tolerance scores from columns C-D."""
    return pd.DataFrame(
        {
            "Taxon": taxa_block.iloc[:, 1].to_numpy(),
            "MCI": pd.to_numeric(taxa_block.iloc[:, 2].to_numpy(), errors="coerce"),
            "MCI_sb": pd.to_numeric(taxa_block.iloc[:, 3].to_numpy(), errors="coerce"),
        }
    )


def _build_metric_rows(
    metric_block: pd.DataFrame, sample_col_indices: list[int]
) -> pd.DataFrame:
    """Build metric rows DataFrame from the metrics block."""
    if metric_block.empty:
        cols = ["Metric", *sample_col_indices]
        return pd.DataFrame(columns=cols)

    meta_part = pd.DataFrame(
        {"Metric": metric_block.iloc[:, 1].astype(str).str.strip().to_numpy()}
    )

    sample_data: dict[int, object] = {}
    for i, col_idx in enumerate(sample_col_indices):
        sample_data[col_idx] = pd.to_numeric(
            metric_block.iloc[:, _DATA_COL_START + i].values, errors="coerce"
        )

    sample_part = pd.DataFrame(sample_data)
    return pd.concat([meta_part, sample_part], axis=1)
