"""MacroSpecies domain — pivot taxa counts to sparse long format.

Reads the RawData sheet from the Macroinvertebrate Database and produces
a long-format DataFrame with one row per (site x date x taxon) where
the tally is non-zero.
"""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from mgen.domain.macro_ingest import IngestError, ingest_raw_data
from mgen.shared.errors import DomainResult, ValidationError
from mgen.shared.schemas import MACRO_SPECIES_COLUMNS

logger = logging.getLogger(__name__)


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
    except (IngestError, Exception) as e:  # noqa: BLE001
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

    sample_ids = bundle.sample_metadata["sample_id"].tolist()
    meta_lookup = bundle.sample_metadata.set_index("sample_id")
    taxa_groups = bundle.taxa_counts["TaxonGroup"].to_numpy()
    taxa_names = bundle.taxa_counts["Taxon"].to_numpy()

    rows: list[dict[str, object]] = []

    for sample_id in sample_ids:
        if sample_id not in meta_lookup.index:
            continue

        meta = meta_lookup.loc[sample_id]
        try:
            counts = bundle.taxa_counts[sample_id].to_numpy()
        except (KeyError, Exception) as e:  # noqa: BLE001
            logger.warning("MacroSpecies: skipping sample_col=%s: %s", sample_id, e)
            errors.append(
                ValidationError(
                    domain="MacroSpecies",
                    severity="warning",
                    file=file_name,
                    sheet="RawData",
                    location=f"sample_col={sample_id}",
                    message=f"Failed to read sample counts: {e}",
                )
            )
            continue

        phase = str(meta["Season"])
        date = meta["Date"]
        site = str(meta["Site"]).strip()

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
                }
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
