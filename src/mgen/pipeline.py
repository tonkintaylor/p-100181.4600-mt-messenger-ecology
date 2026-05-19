"""Pipeline orchestrator: run all domains, enforce no-partial-output contract."""

from __future__ import annotations

import logging
from dataclasses import dataclass, field

from mgen.config import PipelineConfig
from mgen.domain.clarity import process_clarity_domain
from mgen.domain.ldv import process_ldv_domain
from mgen.domain.macro import process_macro_domain
from mgen.domain.macro_species import process_macro_species_domain
from mgen.domain.rpd import process_rpd_domain
from mgen.domain.sediment import process_sediment_domain
from mgen.domain.sediment_size import process_sediment_size_domain
from mgen.shared.errors import DomainResult, ValidationError
from mgen.writer import write_data_xlsx

__all__ = ["PipelineResult", "run_pipeline"]

logger = logging.getLogger(__name__)


@dataclass
class PipelineResult:
    """Outcome of a pipeline run.

    Attributes:
        success: True if all domains succeeded and output was written.
        errors: Collected validation errors from all domains.
    """

    success: bool = False
    errors: list[ValidationError] = field(default_factory=list)


def run_pipeline(config: PipelineConfig) -> PipelineResult:
    """Execute all domain processors and write combined output.

    Enforces the no-partial-output contract: if ANY domain fails,
    no Data.xlsx is written and all errors are collected.

    Returns:
        PipelineResult with success status and any errors.
    """
    results: list[DomainResult] = []

    logger.info("Running macroinvertebrate domain...")
    results.append(process_macro_domain(config.macroinvertebrate_db))

    logger.info("Running macro species domain...")
    results.append(process_macro_species_domain(config.macroinvertebrate_db))

    logger.info("Running sediment domain...")
    results.append(process_sediment_domain(config.aquatic_monitoring_db))

    logger.info("Running sediment size domain...")
    results.append(process_sediment_size_domain(config.aquatic_monitoring_db))

    logger.info("Running clarity domain...")
    results.append(process_clarity_domain(config.aquatic_monitoring_db))

    logger.info("Running RPD domain...")
    results.append(process_rpd_domain(config.aquatic_monitoring_db))

    logger.info("Running LDV domain...")
    results.append(process_ldv_domain(config.aquatic_monitoring_db))

    all_errors: list[ValidationError] = []
    for result in results:
        all_errors.extend(result.errors)

    if not all(r.ok for r in results):
        logger.error("Pipeline failed — %d error(s) across domains", len(all_errors))
        return PipelineResult(success=False, errors=all_errors)

    # Merge all domain data into a single dict for the writer
    combined: dict[str, object] = {}
    for result in results:
        if result.data:
            combined.update(result.data)

    write_data_xlsx(combined, config.data_xlsx)  # type: ignore[arg-type]
    logger.info("Pipeline complete — wrote %s", config.data_xlsx)

    return PipelineResult(success=True, errors=all_errors)
