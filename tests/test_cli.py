"""Tests for the CLI interface."""

from __future__ import annotations

from pathlib import Path
from unittest.mock import patch

from click.testing import CliRunner

from mgen.cli import main
from mgen.pipeline import PipelineResult


def _write_valid_config(tmp_path: Path) -> Path:
    """Write a valid cycle.toml and its referenced input files."""
    macro_file = tmp_path / "macro.xlsx"
    aquatic_file = tmp_path / "aquatic.xlsx"
    macro_file.touch()
    aquatic_file.touch()

    config_file = tmp_path / "cycle.toml"
    config_file.write_text(
        "[input]\n"
        f'macroinvertebrate_db = "{macro_file.as_posix()}"\n'
        f'aquatic_monitoring_db = "{aquatic_file.as_posix()}"\n'
        "\n"
        "[output]\n"
        f'data_xlsx = "{(tmp_path / "MtMessengerEcologyData.xlsx").as_posix()}"\n'
    )
    return config_file


def _write_figures_config(tmp_path: Path) -> tuple[Path, Path]:
    """Write a config with existing data xlsx for figures tests."""
    macro_file = tmp_path / "macro.xlsx"
    aquatic_file = tmp_path / "aquatic.xlsx"
    data_file = tmp_path / "MtMessengerEcologyData.xlsx"
    macro_file.touch()
    aquatic_file.touch()
    data_file.touch()

    config_file = tmp_path / "cycle.toml"
    config_file.write_text(
        "[input]\n"
        f'macroinvertebrate_db = "{macro_file.as_posix()}"\n'
        f'aquatic_monitoring_db = "{aquatic_file.as_posix()}"\n'
        "\n"
        "[output]\n"
        f'data_xlsx = "{data_file.as_posix()}"\n'
    )
    return config_file, data_file


_DATA_XLSX_NAME = "MtMessengerEcologyData.xlsx"


class TestCli:
    def test_main_group_help(self) -> None:
        runner = CliRunner()

        result = runner.invoke(main, ["--help"])

        assert result.exit_code == 0
        assert "Mt Messenger" in result.output

    def test_data_missing_config(self) -> None:
        runner = CliRunner()

        result = runner.invoke(main, ["data", "nonexistent.toml"])

        assert result.exit_code == 2
        assert "Config error" in result.output

    def test_validate_missing_config(self) -> None:
        runner = CliRunner()

        result = runner.invoke(main, ["validate", "nonexistent.toml"])

        assert result.exit_code == 2
        assert "Config error" in result.output

    def test_data_valid_config(self, tmp_path: Path) -> None:
        config_file = _write_valid_config(tmp_path)
        runner = CliRunner()

        result = runner.invoke(main, ["data", str(config_file)])

        # With empty input files, the pipeline will fail at domain level (exit 1)
        assert result.exit_code == 1
        assert "Pipeline failed" in result.output

    def test_validate_valid_config(self, tmp_path: Path) -> None:
        config_file = _write_valid_config(tmp_path)
        runner = CliRunner()

        result = runner.invoke(main, ["validate", str(config_file)])

        assert result.exit_code == 0
        assert "Config valid" in result.output

    def test_validate_shows_figures_and_tables_dirs(self, tmp_path: Path) -> None:
        config_file = _write_valid_config(tmp_path)
        runner = CliRunner()

        result = runner.invoke(main, ["validate", str(config_file)])

        assert result.exit_code == 0
        assert "Figures" in result.output
        assert "Tables" in result.output

    def test_quiet_flag_suppresses_status(self, tmp_path: Path) -> None:
        config_file = _write_valid_config(tmp_path)
        runner = CliRunner()

        result = runner.invoke(main, ["--quiet", "validate", str(config_file)])

        assert result.exit_code == 0
        assert result.output == ""


class TestFiguresCommand:
    def test_figures_command_exists(self) -> None:
        runner = CliRunner()
        result = runner.invoke(main, ["figures", "--help"])
        assert result.exit_code == 0
        assert "R figure pipeline" in result.output

    def test_figures_missing_data_xlsx(self, tmp_path: Path) -> None:
        config_content = (
            "[input]\n"
            f'macroinvertebrate_db = "{(tmp_path / "macro.xlsx").as_posix()}"\n'
            f'aquatic_monitoring_db = "{(tmp_path / "aquatic.xlsx").as_posix()}"\n'
            "\n"
            "[output]\n"
            f'data_xlsx = "{(tmp_path / "nonexistent.xlsx").as_posix()}"\n'
        )
        (tmp_path / "macro.xlsx").touch()
        (tmp_path / "aquatic.xlsx").touch()
        config_path = tmp_path / "cycle.toml"
        config_path.write_text(config_content)

        runner = CliRunner()
        result = runner.invoke(main, ["figures", str(config_path)])
        assert result.exit_code == 1
        assert "not found" in result.output

    def test_figures_missing_rscript(self, tmp_path: Path) -> None:
        config_path, _data_path = _write_figures_config(tmp_path)

        runner = CliRunner()
        with patch("mgen.cli.shutil.which", return_value=None):
            result = runner.invoke(main, ["figures", str(config_path)])
        assert result.exit_code == 1
        assert "Rscript" in result.output

    def test_figures_runs_rscript(self, tmp_path: Path) -> None:
        config_path, data_path = _write_figures_config(tmp_path)

        runner = CliRunner()
        with (
            patch("mgen.cli.shutil.which", return_value="/usr/bin/Rscript"),
            patch("mgen.cli.subprocess.run") as mock_run,
        ):
            mock_run.return_value.returncode = 0
            result = runner.invoke(main, ["figures", str(config_path)])

        assert result.exit_code == 0
        mock_run.assert_called_once()
        call_args = mock_run.call_args
        assert call_args[0][0][0] == "Rscript"
        assert str(data_path) in call_args[0][0]

    def test_figures_missing_r_script(self, tmp_path: Path) -> None:
        config_path, _data_path = _write_figures_config(tmp_path)
        original_exists = Path.exists

        def _exists_except_r_script(self: Path) -> bool:
            if "run_all.R" in str(self):
                return False
            return original_exists(self)

        runner = CliRunner()
        with (
            patch("mgen.cli.shutil.which", return_value="/usr/bin/Rscript"),
            patch.object(Path, "exists", _exists_except_r_script),
        ):
            result = runner.invoke(main, ["figures", str(config_path)])
        assert result.exit_code == 1
        assert "R script not found" in result.output

    def test_figures_data_override(self, tmp_path: Path) -> None:
        config_path, _ = _write_figures_config(tmp_path)
        custom_data = tmp_path / "custom.xlsx"
        custom_data.touch()

        runner = CliRunner()
        with (
            patch("mgen.cli.shutil.which", return_value="/usr/bin/Rscript"),
            patch("mgen.cli.subprocess.run") as mock_run,
        ):
            mock_run.return_value.returncode = 0
            result = runner.invoke(
                main, ["figures", str(config_path), "--data", str(custom_data)]
            )

        assert result.exit_code == 0
        call_args = mock_run.call_args
        assert str(custom_data) in call_args[0][0]


class TestAllCommand:
    def test_all_command_exists(self) -> None:
        runner = CliRunner()
        result = runner.invoke(main, ["all", "--help"])
        assert result.exit_code == 0
        assert "data" in result.output.lower()
        assert "figures" in result.output.lower()

    def test_all_missing_config(self) -> None:
        runner = CliRunner()
        result = runner.invoke(main, ["all", "nonexistent.toml"])
        assert result.exit_code == 2
        assert "Config error" in result.output

    def test_all_stops_on_data_failure(self, tmp_path: Path) -> None:
        config_file = _write_valid_config(tmp_path)
        runner = CliRunner()

        result = runner.invoke(main, ["all", str(config_file)])

        # Data pipeline fails (empty input files) → should not attempt figures
        assert result.exit_code == 1
        assert "Pipeline failed" in result.output

    def test_all_runs_figures_after_data(self, tmp_path: Path) -> None:
        config_file = _write_valid_config(tmp_path)
        runner = CliRunner()

        with (
            patch("mgen.cli.run_pipeline") as mock_pipeline,
            patch("mgen.cli.shutil.which", return_value="/usr/bin/Rscript"),
            patch("mgen.cli.subprocess.run") as mock_subprocess,
        ):
            mock_result = PipelineResult(success=True, errors=[])
            mock_pipeline.return_value = mock_result
            # Create the data xlsx so the figures step finds it
            (tmp_path / _DATA_XLSX_NAME).touch()
            mock_subprocess.return_value.returncode = 0

            result = runner.invoke(main, ["all", str(config_file)])

        assert result.exit_code == 0
        mock_pipeline.assert_called_once()
        mock_subprocess.assert_called_once()
