"""Tests for the CLI interface."""

from __future__ import annotations

from pathlib import Path

from click.testing import CliRunner

from mgen.cli import main


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
        f'data_xlsx = "{(tmp_path / "Data.xlsx").as_posix()}"\n'
    )
    return config_file


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


class TestPlotCommand:
    def test_plot_command_exists(self) -> None:
        runner = CliRunner()
        result = runner.invoke(main, ["plot", "--help"])
        assert result.exit_code == 0
        assert "Generate" in result.output

    def test_plot_requires_data_xlsx(self, tmp_path: Path) -> None:
        config_content = (
            "[input]\n"
            f'macroinvertebrate_db = "{(tmp_path / "macro.xlsx").as_posix()}"\n'
            f'aquatic_monitoring_db = "{(tmp_path / "aquatic.xlsx").as_posix()}"\n'
            "\n"
            "[output]\n"
            f'data_xlsx = "{(tmp_path / "nonexistent_Data.xlsx").as_posix()}"\n'
        )
        (tmp_path / "macro.xlsx").touch()
        (tmp_path / "aquatic.xlsx").touch()
        config_path = tmp_path / "cycle.toml"
        config_path.write_text(config_content)

        runner = CliRunner()
        result = runner.invoke(main, ["plot", str(config_path)])
        assert result.exit_code != 0
        assert "Data.xlsx not found" in result.output
