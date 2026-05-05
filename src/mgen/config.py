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

    # Validate input files exist
    for path in [macro_db, aquatic_db]:
        if not path.exists():
            msg = f"Input file not found: {path}"
            raise ConfigError(msg)

    return PipelineConfig(
        macroinvertebrate_db=macro_db,
        aquatic_monitoring_db=aquatic_db,
        data_xlsx=data_xlsx,
    )
