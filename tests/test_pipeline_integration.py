"""Integration tests for the pipeline orchestrator."""

from __future__ import annotations

from pathlib import Path
from unittest.mock import patch

import pandas as pd
import pytest
from click.testing import CliRunner

from mgen.cli import main
from mgen.config import PipelineConfig
from mgen.pipeline import run_pipeline
from mgen.shared.errors import DomainResult, ValidationError
from mgen.writer import SHEET_ORDER


@pytest.fixture(scope="class")
def pipeline_config(
    example_macro_db: Path,
    example_aquatic_db: Path,
    tmp_path_factory: pytest.TempPathFactory,
) -> PipelineConfig:
    """Config pointing at real fixture data with a temp output path."""
    out_dir = tmp_path_factory.mktemp("pipeline_output")
    return PipelineConfig(
        macroinvertebrate_db=example_macro_db,
        aquatic_monitoring_db=example_aquatic_db,
        data_xlsx=out_dir / "Data.xlsx",
        figures_dir=out_dir / "Figures",
        tables_dir=out_dir / "Tables",
    )


class TestRunPipeline:
    """End-to-end tests for the pipeline orchestrator."""

    def test_success_produces_output(self, pipeline_config: PipelineConfig) -> None:
        result = run_pipeline(pipeline_config)

        assert result.success is True
        assert pipeline_config.data_xlsx.exists()

    def test_output_has_all_sheets(self, pipeline_config: PipelineConfig) -> None:
        if not pipeline_config.data_xlsx.exists():
            run_pipeline(pipeline_config)

        with pd.ExcelFile(pipeline_config.data_xlsx) as xlsx:
            assert xlsx.sheet_names == SHEET_ORDER

    def test_no_hard_errors_on_success(self, pipeline_config: PipelineConfig) -> None:
        result = run_pipeline(pipeline_config)

        hard_errors = [e for e in result.errors if e.severity == "error"]
        assert hard_errors == []

    def test_warnings_still_returned_on_success(
        self, pipeline_config: PipelineConfig
    ) -> None:
        result = run_pipeline(pipeline_config)

        # Warnings are informational — pipeline still succeeds
        assert result.success is True


class TestPipelineErrorHandling:
    """Tests for the no-partial-output contract."""

    def test_domain_failure_returns_errors(
        self, example_macro_db: Path, example_aquatic_db: Path, tmp_path: Path
    ) -> None:
        config = PipelineConfig(
            macroinvertebrate_db=example_macro_db,
            aquatic_monitoring_db=example_aquatic_db,
            data_xlsx=tmp_path / "Data.xlsx",
            figures_dir=tmp_path / "Figures",
            tables_dir=tmp_path / "Tables",
        )
        failed_result = DomainResult(
            data=None,
            errors=[
                ValidationError(
                    domain="sediment",
                    severity="error",
                    file="test.xlsx",
                    sheet="Sediment",
                    location="data",
                    message="Simulated failure",
                )
            ],
        )

        with patch("mgen.pipeline.process_sediment_domain", return_value=failed_result):
            result = run_pipeline(config)

        assert result.success is False
        assert any("Simulated failure" in e.message for e in result.errors)

    def test_no_output_written_on_failure(
        self, example_macro_db: Path, example_aquatic_db: Path, tmp_path: Path
    ) -> None:
        config = PipelineConfig(
            macroinvertebrate_db=example_macro_db,
            aquatic_monitoring_db=example_aquatic_db,
            data_xlsx=tmp_path / "Data.xlsx",
            figures_dir=tmp_path / "Figures",
            tables_dir=tmp_path / "Tables",
        )
        failed_result = DomainResult(
            data=None,
            errors=[
                ValidationError(
                    domain="macro",
                    severity="error",
                    file="test.xlsx",
                    sheet="RawData",
                    location="file",
                    message="Cannot read file",
                )
            ],
        )

        with patch("mgen.pipeline.process_macro_domain", return_value=failed_result):
            run_pipeline(config)

        assert not config.data_xlsx.exists()

    def test_all_domain_errors_collected(
        self, example_macro_db: Path, example_aquatic_db: Path, tmp_path: Path
    ) -> None:
        config = PipelineConfig(
            macroinvertebrate_db=example_macro_db,
            aquatic_monitoring_db=example_aquatic_db,
            data_xlsx=tmp_path / "Data.xlsx",
            figures_dir=tmp_path / "Figures",
            tables_dir=tmp_path / "Tables",
        )
        macro_fail = DomainResult(
            data=None,
            errors=[
                ValidationError(
                    domain="macro",
                    severity="error",
                    file="test.xlsx",
                    sheet="RawData",
                    location="file",
                    message="Macro failed",
                )
            ],
        )
        sediment_fail = DomainResult(
            data=None,
            errors=[
                ValidationError(
                    domain="sediment",
                    severity="error",
                    file="test.xlsx",
                    sheet="Sediment",
                    location="data",
                    message="Sediment failed",
                )
            ],
        )

        with (
            patch("mgen.pipeline.process_macro_domain", return_value=macro_fail),
            patch("mgen.pipeline.process_sediment_domain", return_value=sediment_fail),
        ):
            result = run_pipeline(config)

        assert result.success is False
        messages = [e.message for e in result.errors]
        assert "Macro failed" in messages
        assert "Sediment failed" in messages


class TestCliIntegration:
    """CLI exit code tests using Click's CliRunner."""

    def _write_config(self, tmp_path: Path, macro_db: Path, aquatic_db: Path) -> Path:
        config_file = tmp_path / "cycle.toml"
        config_file.write_text(
            "[input]\n"
            f'macroinvertebrate_db = "{macro_db.as_posix()}"\n'
            f'aquatic_monitoring_db = "{aquatic_db.as_posix()}"\n'
            "\n"
            "[output]\n"
            f'data_xlsx = "{(tmp_path / "Data.xlsx").as_posix()}"\n'
            f'figures_dir = "{(tmp_path / "Figures").as_posix()}"\n'
            f'tables_dir = "{(tmp_path / "Tables").as_posix()}"\n'
        )
        return config_file

    def test_exit_code_0_on_success(
        self, example_macro_db: Path, example_aquatic_db: Path, tmp_path: Path
    ) -> None:
        config_file = self._write_config(tmp_path, example_macro_db, example_aquatic_db)
        runner = CliRunner()

        result = runner.invoke(main, ["data", str(config_file)])

        assert result.exit_code == 0
        assert "Wrote" in result.output

    def test_exit_code_1_on_domain_error(
        self, example_macro_db: Path, example_aquatic_db: Path, tmp_path: Path
    ) -> None:
        config_file = self._write_config(tmp_path, example_macro_db, example_aquatic_db)
        runner = CliRunner()

        failed_result = DomainResult(
            data=None,
            errors=[
                ValidationError(
                    domain="macro",
                    severity="error",
                    file="test.xlsx",
                    sheet="RawData",
                    location="file",
                    message="Domain error",
                )
            ],
        )
        with patch("mgen.pipeline.process_macro_domain", return_value=failed_result):
            result = runner.invoke(main, ["data", str(config_file)])

        assert result.exit_code == 1
        assert "Pipeline failed" in result.output

    def test_exit_code_2_on_config_error(self) -> None:
        runner = CliRunner()

        result = runner.invoke(main, ["data", "nonexistent.toml"])

        assert result.exit_code == 2
        assert "Config error" in result.output

    def test_error_output_shows_domain_and_message(
        self, example_macro_db: Path, example_aquatic_db: Path, tmp_path: Path
    ) -> None:
        config_file = self._write_config(tmp_path, example_macro_db, example_aquatic_db)
        runner = CliRunner()

        failed_result = DomainResult(
            data=None,
            errors=[
                ValidationError(
                    domain="sediment",
                    severity="error",
                    file="aquatic.xlsx",
                    sheet="SedData",
                    location="row 5",
                    message="Missing required column: SAM1",
                )
            ],
        )
        with patch("mgen.pipeline.process_sediment_domain", return_value=failed_result):
            result = runner.invoke(main, ["data", str(config_file)])

        assert "Missing required column: SAM1" in result.output
        assert "sediment" in result.output.lower() or "SedData" in result.output
