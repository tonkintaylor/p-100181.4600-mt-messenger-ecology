"""Tests for cycle.toml config loading."""

from __future__ import annotations

from pathlib import Path

import pytest

from mgen.config import ConfigError, load_config


class TestLoadConfig:
    def test_loads_valid_toml(self, tmp_path: Path) -> None:
        config_file = tmp_path / "cycle.toml"
        macro_file = tmp_path / "macro.xlsx"
        aquatic_file = tmp_path / "aquatic.xlsx"
        macro_file.touch()
        aquatic_file.touch()

        config_file.write_text(
            "[input]\n"
            f'macroinvertebrate_db = "{macro_file.as_posix()}"\n'
            f'aquatic_monitoring_db = "{aquatic_file.as_posix()}"\n'
            "\n"
            "[output]\n"
            f'data_xlsx = "{(tmp_path / "Data.xlsx").as_posix()}"\n'
        )

        config = load_config(config_file)

        assert config.macroinvertebrate_db == macro_file
        assert config.aquatic_monitoring_db == aquatic_file
        assert config.data_xlsx == tmp_path / "Data.xlsx"

    def test_raises_on_missing_config_file(self, tmp_path: Path) -> None:
        with pytest.raises(ConfigError, match="not found"):
            load_config(tmp_path / "nonexistent.toml")

    def test_raises_on_missing_input_file(self, tmp_path: Path) -> None:
        config_file = tmp_path / "cycle.toml"
        config_file.write_text(
            "[input]\n"
            'macroinvertebrate_db = "does_not_exist.xlsx"\n'
            'aquatic_monitoring_db = "also_missing.xlsx"\n'
            "\n"
            "[output]\n"
            f'data_xlsx = "{(tmp_path / "Data.xlsx").as_posix()}"\n'
        )

        with pytest.raises(ConfigError, match=r"does_not_exist\.xlsx"):
            load_config(config_file)

    def test_raises_on_missing_required_key(self, tmp_path: Path) -> None:
        config_file = tmp_path / "cycle.toml"
        config_file.write_text("[input]\n")

        with pytest.raises(ConfigError, match="macroinvertebrate_db"):
            load_config(config_file)


class TestFiguresDir:
    """Tests for figures_dir configuration."""

    def test_figures_dir_from_config(self, tmp_path: Path) -> None:
        config_content = (
            "[input]\n"
            f'macroinvertebrate_db = "{(tmp_path / "macro.xlsx").as_posix()}"\n'
            f'aquatic_monitoring_db = "{(tmp_path / "aquatic.xlsx").as_posix()}"\n'
            "\n"
            "[output]\n"
            f'data_xlsx = "{(tmp_path / "Data.xlsx").as_posix()}"\n'
            f'figures_dir = "{(tmp_path / "Figures").as_posix()}"\n'
        )
        (tmp_path / "macro.xlsx").touch()
        (tmp_path / "aquatic.xlsx").touch()
        config_path = tmp_path / "cycle.toml"
        config_path.write_text(config_content)

        config = load_config(config_path)
        assert config.figures_dir == tmp_path / "Figures"

    def test_figures_dir_defaults_to_figures_subdir(self, tmp_path: Path) -> None:
        config_content = (
            "[input]\n"
            f'macroinvertebrate_db = "{(tmp_path / "macro.xlsx").as_posix()}"\n'
            f'aquatic_monitoring_db = "{(tmp_path / "aquatic.xlsx").as_posix()}"\n'
            "\n"
            "[output]\n"
            f'data_xlsx = "{(tmp_path / "Data.xlsx").as_posix()}"\n'
        )
        (tmp_path / "macro.xlsx").touch()
        (tmp_path / "aquatic.xlsx").touch()
        config_path = tmp_path / "cycle.toml"
        config_path.write_text(config_content)

        config = load_config(config_path)
        assert config.figures_dir == tmp_path / "Figures"


class TestTablesDir:
    """Tests for tables_dir configuration."""

    def test_tables_dir_from_config(self, tmp_path: Path) -> None:
        config_content = (
            "[input]\n"
            f'macroinvertebrate_db = "{(tmp_path / "macro.xlsx").as_posix()}"\n'
            f'aquatic_monitoring_db = "{(tmp_path / "aquatic.xlsx").as_posix()}"\n'
            "\n"
            "[output]\n"
            f'data_xlsx = "{(tmp_path / "Data.xlsx").as_posix()}"\n'
            f'tables_dir = "{(tmp_path / "Tables").as_posix()}"\n'
        )
        (tmp_path / "macro.xlsx").touch()
        (tmp_path / "aquatic.xlsx").touch()
        config_path = tmp_path / "cycle.toml"
        config_path.write_text(config_content)

        config = load_config(config_path)
        assert config.tables_dir == tmp_path / "Tables"

    def test_tables_dir_defaults_to_tables_subdir(self, tmp_path: Path) -> None:
        config_content = (
            "[input]\n"
            f'macroinvertebrate_db = "{(tmp_path / "macro.xlsx").as_posix()}"\n'
            f'aquatic_monitoring_db = "{(tmp_path / "aquatic.xlsx").as_posix()}"\n'
            "\n"
            "[output]\n"
            f'data_xlsx = "{(tmp_path / "Data.xlsx").as_posix()}"\n'
            f'figures_dir = "{(tmp_path / "Figures").as_posix()}"\n'
        )
        (tmp_path / "macro.xlsx").touch()
        (tmp_path / "aquatic.xlsx").touch()
        config_path = tmp_path / "cycle.toml"
        config_path.write_text(config_content)

        config = load_config(config_path)
        assert config.tables_dir == tmp_path / "Figures" / "Tables"
