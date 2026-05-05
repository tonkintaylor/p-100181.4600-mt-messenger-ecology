"""Domain value objects for the Mt Messenger monitoring pipeline."""

from __future__ import annotations

from dataclasses import dataclass

# Canonical site codes for the Mt Messenger monitoring programme
VALID_SITES = frozenset(
    {"EM1", "EM2", "EM3", "EM4", "EM5", "EM7", "EM8", "MMA6", "MMA6b"}
)

# Sites that lack replicates and use QMCI-sb instead of QMCI
SITES_WITHOUT_REPLICATES = frozenset({"EM1", "EM2", "EM4", "EM8"})

# Valid season/phase labels
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
