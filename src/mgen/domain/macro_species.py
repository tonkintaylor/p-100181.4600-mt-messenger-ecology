"""MacroSpecies domain — pivot taxa counts to sparse long format.

Reads the RawData sheet from the Macroinvertebrate Database and produces
a long-format DataFrame with one row per (site x date x taxon) where
the tally is non-zero.
"""

from __future__ import annotations

import logging
from pathlib import Path
from typing import TYPE_CHECKING

import numpy as np
import pandas as pd

from mgen.domain.macro_ingest import IngestError, ingest_raw_data
from mgen.shared.domain_types import BASELINE_END
from mgen.shared.errors import DomainResult, ValidationError
from mgen.shared.schemas import MACRO_SPECIES_COLUMNS

if TYPE_CHECKING:
    from mgen.domain.macro_ingest import RawDataBundle

logger = logging.getLogger(__name__)


def _pivot_sample(
    sample_id: object,
    bundle: RawDataBundle,
    meta_lookup: pd.DataFrame,
    taxa_groups: np.ndarray,
    taxa_names: np.ndarray,
) -> list[dict[str, object]]:
    """Pivot a single sample column into long-format rows.

    Returns only rows where tally > 0.
    """
    meta = meta_lookup.loc[sample_id]
    counts = bundle.taxa_counts[sample_id].to_numpy()

    phase = str(meta["Season"])
    date = meta["Date"]
    site = str(meta["Site"]).strip()

    # Flag incident/additional samples; derive Phase from date
    is_additional = phase.lower() == "incident"
    if pd.notna(date) and pd.Timestamp(date) <= BASELINE_END:
        phase = "Baseline"
    else:
        phase = "Construction"

    rows: list[dict[str, object]] = []
    for i, tally in enumerate(counts):
        if pd.isna(tally) or int(tally) <= 0:
            continue
        rows.append(
            {
                "Phase": phase,
                "Date": date,
                "Site": site,
                "Taxa": str(taxa_groups[i]),
                "Species": str(taxa_names[i]),
                "Tally": int(tally),
                "is_additional": is_additional,
            }
        )
    return rows


def process_macro_species_domain(macro_db_path: Path) -> DomainResult:
    """Pivot taxa counts into sparse long format for MacroSpecies sheet.

    Args:
        macro_db_path: Path to the Macroinvertebrate Database .xlsx file.

    Returns:
        DomainResult with {"MacroSpecies": df} on success.
    """
    file_name = macro_db_path.name
    errors: list[ValidationError] = []

    try:
        bundle = ingest_raw_data(macro_db_path)
    except IngestError as e:
        errors.append(
            ValidationError(
                domain="MacroSpecies",
                severity="error",
                file=file_name,
                sheet="RawData",
                location="file",
                message=f"Failed to read RawData: {e}",
            )
        )
        return DomainResult(data=None, errors=errors)
    except Exception:
        logger.exception("Unexpected error reading %s", file_name)
        errors.append(
            ValidationError(
                domain="MacroSpecies",
                severity="error",
                file=file_name,
                sheet="RawData",
                location="file",
                message="Unexpected error reading RawData",
            )
        )
        return DomainResult(data=None, errors=errors)

    sample_ids = bundle.sample_metadata["sample_id"].tolist()
    meta_lookup = bundle.sample_metadata.set_index("sample_id")
    taxa_groups = bundle.taxa_counts["TaxonGroup"].to_numpy()
    taxa_names = bundle.taxa_counts["Taxon"].to_numpy()

    rows: list[dict[str, object]] = []

    for sample_id in sample_ids:
        if sample_id not in meta_lookup.index:  # pragma: no cover
            continue
        try:
            rows.extend(
                _pivot_sample(sample_id, bundle, meta_lookup, taxa_groups, taxa_names)
            )
        except KeyError:
            logger.warning("MacroSpecies: missing column for sample %s", sample_id)
            errors.append(
                ValidationError(
                    domain="MacroSpecies",
                    severity="warning",
                    file=file_name,
                    sheet="RawData",
                    location=f"sample_col={sample_id}",
                    message="Sample column not found in taxa_counts",
                )
            )
        except Exception:
            logger.exception(
                "MacroSpecies: unexpected error for sample_col=%s", sample_id
            )
            errors.append(
                ValidationError(
                    domain="MacroSpecies",
                    severity="warning",
                    file=file_name,
                    sheet="RawData",
                    location=f"sample_col={sample_id}",
                    message="Unexpected error reading sample counts",
                )
            )

    if not rows:
        errors.append(
            ValidationError(
                domain="MacroSpecies",
                severity="error",
                file=file_name,
                sheet="RawData",
                location="all samples",
                message="No non-zero taxa counts found",
            )
        )
        return DomainResult(data=None, errors=errors)

    df = pd.DataFrame(rows, columns=MACRO_SPECIES_COLUMNS)
    df["Date"] = pd.to_datetime(df["Date"]).astype("datetime64[ns]")
    df["Tally"] = df["Tally"].astype("int64")
    for col in ("Phase", "Site", "Taxa", "Species"):
        df[col] = df[col].astype("object")

    return DomainResult(data={"MacroSpecies": df}, errors=errors)
