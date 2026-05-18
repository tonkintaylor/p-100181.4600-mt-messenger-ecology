"""Domain value objects for the Mt Messenger monitoring pipeline."""

from __future__ import annotations

from dataclasses import dataclass

import pandas as pd

# Samples on or before this date are Baseline regardless of source label.
# Per MKE review: baseline monitoring includes all samples through March 2022.
BASELINE_END = pd.Timestamp("2022-03-31")

# Canonical site codes for the Mt Messenger monitoring programme.
# NOTE: "MMA 6" and "MMA 6b" have a space — matches source database values.
VALID_SITES = frozenset(
    {"EM1", "EM2", "EM3", "EM4", "EM5", "EM7", "EM8", "MMA 6", "MMA 6b"}
)

# Sites that lack replicates and use QMCI-sb instead of QMCI
SITES_WITHOUT_REPLICATES = frozenset({"EM1", "EM2", "EM4", "EM8"})

# Valid monitoring period labels (from Sediment sheet first column)
VALID_PERIODS = frozenset({"Baseline", "Construction"})

# Valid season/phase labels used in output Data.xlsx.
# "Routine" is a planned future monitoring phase post-construction.
VALID_SEASONS = frozenset({"Baseline", "Construction", "Routine", "Additional"})


@dataclass(frozen=True)
class Site:
    """A validated monitoring site."""

    code: str

    def __post_init__(self) -> None:
        if self.code not in VALID_SITES:
            msg = f"Unknown site: {self.code!r}. Expected one of {sorted(VALID_SITES)}"
            raise ValueError(msg)

    @property
    def has_replicates(self) -> bool:
        """Whether this site has replicate samples."""
        return self.code not in SITES_WITHOUT_REPLICATES

    @property
    def uses_qmci_sb(self) -> bool:
        """Whether this site uses QMCI-sb instead of QMCI."""
        return self.code in SITES_WITHOUT_REPLICATES
