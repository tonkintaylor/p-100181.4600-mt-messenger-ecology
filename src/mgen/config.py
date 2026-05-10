"""Load and validate cycle.toml configuration."""

from __future__ import annotations

import tomllib
from dataclasses import dataclass
from pathlib import Path


class ConfigError(Exception):
    """Raised when cycle.toml is missing or invalid."""


@dataclass(frozen=True)
class PipelineConfig:
    """Validated pipeline configuration from cycle.toml."""

    macroinvertebrate_db: Path
    aquatic_monitoring_db: Path
    data_xlsx: Path
    figures_dir: Path
    tables_dir: Path


def load_config(config_path: Path) -> PipelineConfig:
    """Load and validate a cycle.toml file.

    Raises ConfigError if the file is missing, malformed, or references
    input files that don't exist.
    """
    if not config_path.exists():
        msg = f"Config file not found: {config_path}"
        raise ConfigError(msg)

    with config_path.open("rb") as f:
        raw = tomllib.load(f)

    # Extract required keys
    input_section = raw.get("input", {})
    output_section = raw.get("output", {})

    required_inputs = ["macroinvertebrate_db", "aquatic_monitoring_db"]
    for key in required_inputs:
        if key not in input_section:
            msg = f"Missing required key: [input].{key}"
            raise ConfigError(msg)

    if "data_xlsx" not in output_section:
        msg = "Missing required key: [output].data_xlsx"
        raise ConfigError(msg)

    macro_db = Path(input_section["macroinvertebrate_db"])
    aquatic_db = Path(input_section["aquatic_monitoring_db"])
    data_xlsx = Path(output_section["data_xlsx"])

    # Get figures_dir from config or default to data_xlsx parent / "Figures"
    if "figures_dir" in output_section:
        figures_dir = Path(output_section["figures_dir"])
    else:
        figures_dir = data_xlsx.parent / "Figures"

    # Get tables_dir from config or default to figures_dir / "Tables"
    if "tables_dir" in output_section:
        tables_dir = Path(output_section["tables_dir"])
    else:
        tables_dir = figures_dir / "Tables"

    # Validate input files exist
    for path in [macro_db, aquatic_db]:
        if not path.exists():
            msg = f"Input file not found: {path}"
            raise ConfigError(msg)

    return PipelineConfig(
        macroinvertebrate_db=macro_db,
        aquatic_monitoring_db=aquatic_db,
        data_xlsx=data_xlsx,
        figures_dir=figures_dir,
        tables_dir=tables_dir,
    )
