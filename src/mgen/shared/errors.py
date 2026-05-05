"""Error types for pipeline validation."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    import pandas as pd


@dataclass(frozen=True)
class ValidationError:
    """A single validation failure pointing at its source location."""

    domain: str
    severity: str  # "error" or "warning"
    file: str
    sheet: str
    location: str
    message: str

    def __str__(self) -> str:
        return (
            f"[{self.severity.upper()}] {self.file} → {self.sheet}"
            f" → {self.location}: {self.message}"
        )


@dataclass
class DomainResult:
    """Result from a domain module: either data or errors, never both meaningful.

    Mutable because domain modules build results incrementally.
    Consumers MUST check ``.ok`` before accessing ``.data``.
    """

    data: dict[str, pd.DataFrame] | None = None
    errors: list[ValidationError] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        """True if no errors with severity 'error'."""
        return not any(e.severity == "error" for e in self.errors)
