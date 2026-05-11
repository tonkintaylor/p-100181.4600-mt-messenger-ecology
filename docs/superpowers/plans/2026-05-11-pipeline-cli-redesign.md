# Pipeline CLI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename CLI commands to `mgen data / figures / all`, delegate figures to R, add `tables_dir` config, rename Data.xlsx → MtMessengerEcologyData.xlsx, and extend setup to install R.

**Architecture:** The `mgen` CLI gains three commands (`data`, `figures`, `all`) replacing the old `run` and `plot`. The `figures` command delegates to `Rscript src/r/run_all.R` via subprocess. Config gains a `tables_dir` field. Setup scripts install R + packages.

**Tech Stack:** Python 3.13, Click, subprocess, TOML config, R/Rscript, PowerShell/bash setup scripts.

**Spec:** See `docs/superpowers/specs/2026-05-11-pipeline-runner-design.md` (on `feature/missing-ref-tables` branch). GitHub issue: #24.

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `src/mgen/config.py` | Modify | Add `tables_dir: Path` field |
| `src/mgen/cli.py` | Modify | Rename commands, add `all`, replace `plot` with R subprocess |
| `src/mgen/writer.py` | Modify | Update log message string |
| `tests/test_config.py` | Modify | Add `tables_dir` tests |
| `tests/test_cli.py` | Modify | Rename all command references, add `figures`/`all` tests |
| `cycle.example.toml` | Modify | Update filename, add `tables_dir` |
| `README.md` | Modify | Update diagram, add usage section |
| `tasks/shims/install_r` | Create | Bash shim for R + package installation |
| `tasks/shims/install_r.cmd` | Create | CMD shim |
| `tasks/shims/install_r.ps1` | Create | PowerShell shim |
| `tasks/scripts/install_r.sh` | Create | R installation script |
| `tasks/scripts/dev_sync.sh` | Modify | Add `source ./tasks/shims/install_r` |

---

### Task 1: Add `tables_dir` to PipelineConfig

**Files:**
- Modify: `src/mgen/config.py`
- Modify: `tests/test_config.py`

- [ ] **Step 1: Write failing tests for `tables_dir`**

Add a new test class to `tests/test_config.py`:

```python
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `uv run pytest tests/test_config.py::TestTablesDir -v`
Expected: FAIL — `PipelineConfig` has no `tables_dir` attribute.

- [ ] **Step 3: Add `tables_dir` to `PipelineConfig` and `load_config`**

In `src/mgen/config.py`, add the field to the dataclass:

```python
@dataclass(frozen=True)
class PipelineConfig:
    """Validated pipeline configuration from cycle.toml."""

    macroinvertebrate_db: Path
    aquatic_monitoring_db: Path
    data_xlsx: Path
    figures_dir: Path
    tables_dir: Path
```

In `load_config`, add parsing after `figures_dir`:

```python
    # Get tables_dir from config or default to figures_dir / "Tables"
    if "tables_dir" in output_section:
        tables_dir = Path(output_section["tables_dir"])
    else:
        tables_dir = figures_dir / "Tables"
```

And pass it to the constructor:

```python
    return PipelineConfig(
        macroinvertebrate_db=macro_db,
        aquatic_monitoring_db=aquatic_db,
        data_xlsx=data_xlsx,
        figures_dir=figures_dir,
        tables_dir=tables_dir,
    )
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `uv run pytest tests/test_config.py -v`
Expected: All PASS (including existing tests — they still work because
`tables_dir` gets a default).

- [ ] **Step 5: Commit**

```bash
git add src/mgen/config.py tests/test_config.py
git commit -m "feat: add tables_dir to PipelineConfig (#24)"
```

---

### Task 2: Rename `run` → `data` command

**Files:**
- Modify: `src/mgen/cli.py`
- Modify: `tests/test_cli.py`

- [ ] **Step 1: Update tests to use `data` command name**

In `tests/test_cli.py`, change all `"run"` invocations in `TestCli`:

```python
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `uv run pytest tests/test_cli.py::TestCli -v`
Expected: FAIL — `"data"` is not a registered command.

- [ ] **Step 3: Rename the `run` command to `data` in `cli.py`**

In `src/mgen/cli.py`, change the function name and decorator:

```python
@main.command()
@click.argument("config_path", default="cycle.toml", type=click.Path(exists=False))
def data(config_path: str) -> None:
    """Process input spreadsheets and write MtMessengerEcologyData.xlsx."""
    try:
        config = load_config(Path(config_path))
    except ConfigError as e:
        click.echo(f"❌ Config error: {e}", err=True)
        sys.exit(2)

    result = run_pipeline(config)

    if result.errors:
        click.echo("", err=True)
        for error in result.errors:
            click.echo(f"  {error}", err=True)
        click.echo("", err=True)

    if not result.success:
        error_count = sum(1 for e in result.errors if e.severity == "error")
        click.echo(
            f"❌ Pipeline failed: {error_count} error(s) across domains", err=True
        )
        sys.exit(1)

    click.echo(f"✅ Wrote {config.data_xlsx}")
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `uv run pytest tests/test_cli.py::TestCli -v`
Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add src/mgen/cli.py tests/test_cli.py
git commit -m "feat: rename 'mgen run' to 'mgen data' (#24)"
```

---

### Task 3: Replace `plot` with `figures` command (R subprocess)

**Files:**
- Modify: `src/mgen/cli.py`
- Modify: `tests/test_cli.py`

- [ ] **Step 1: Remove old `TestPlotCommand` and write new `TestFiguresCommand`**

Replace the `TestPlotCommand` class in `tests/test_cli.py` with:

```python
from unittest.mock import patch


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
        config_path, data_path = _write_figures_config(tmp_path)

        runner = CliRunner()
        with patch("shutil.which", return_value=None):
            result = runner.invoke(main, ["figures", str(config_path)])
        assert result.exit_code == 1
        assert "Rscript" in result.output

    def test_figures_runs_rscript(self, tmp_path: Path) -> None:
        config_path, data_path = _write_figures_config(tmp_path)

        runner = CliRunner()
        with (
            patch("shutil.which", return_value="/usr/bin/Rscript"),
            patch("subprocess.run") as mock_run,
        ):
            mock_run.return_value.returncode = 0
            result = runner.invoke(main, ["figures", str(config_path)])

        assert result.exit_code == 0
        mock_run.assert_called_once()
        call_args = mock_run.call_args
        assert call_args[0][0][0] == "Rscript"
        assert str(data_path) in call_args[0][0]

    def test_figures_data_override(self, tmp_path: Path) -> None:
        config_path, _ = _write_figures_config(tmp_path)
        custom_data = tmp_path / "custom.xlsx"
        custom_data.touch()

        runner = CliRunner()
        with (
            patch("shutil.which", return_value="/usr/bin/Rscript"),
            patch("subprocess.run") as mock_run,
        ):
            mock_run.return_value.returncode = 0
            result = runner.invoke(
                main, ["figures", str(config_path), "--data", str(custom_data)]
            )

        assert result.exit_code == 0
        call_args = mock_run.call_args
        assert str(custom_data) in call_args[0][0]
```

Also add this helper function after `_write_valid_config`:

```python
def _write_figures_config(tmp_path: Path) -> tuple[Path, Path]:
    """Write a config with existing data xlsx for figures tests."""
    macro_file = tmp_path / "macro.xlsx"
    aquatic_file = tmp_path / "aquatic.xlsx"
    data_file = tmp_path / "Data.xlsx"
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `uv run pytest tests/test_cli.py::TestFiguresCommand -v`
Expected: FAIL — `"figures"` command does not exist.

- [ ] **Step 3: Replace `plot` with `figures` command in `cli.py`**

Remove the entire `plot` function and replace with:

```python
import shutil
import subprocess


def _run_r_figures(
    xlsx_path: Path, figures_dir: Path, tables_dir: Path
) -> None:
    """Run the R figure pipeline via Rscript.

    Exits the process on failure (Rscript not found, R script missing,
    or non-zero exit code).
    """
    if shutil.which("Rscript") is None:
        click.echo(
            "❌ Rscript not found on PATH. Run ./tasks/dev_sync.ps1 to install R.",
            err=True,
        )
        sys.exit(1)

    r_script = Path(__file__).resolve().parent.parent / "r" / "run_all.R"
    if not r_script.exists():
        click.echo(f"❌ R script not found: {r_script}", err=True)
        sys.exit(1)

    cmd = [
        "Rscript",
        str(r_script),
        str(xlsx_path),
        str(figures_dir),
        str(tables_dir),
    ]
    click.echo(f"Running R figures: {xlsx_path}")
    result = subprocess.run(cmd, check=False)

    if result.returncode != 0:
        click.echo("❌ R figure pipeline failed", err=True)
        sys.exit(1)

    click.echo(f"✅ Figures written to {figures_dir}")


@main.command()
@click.argument("config_path", default="cycle.toml", type=click.Path(exists=False))
@click.option(
    "--data",
    "data_override",
    type=click.Path(),
    default=None,
    help="Override data xlsx path (use manually edited data).",
)
def figures(config_path: str, data_override: str | None) -> None:
    """Run the R figure pipeline from the data xlsx."""
    try:
        config = load_config(Path(config_path))
    except ConfigError as e:
        click.echo(f"❌ Config error: {e}", err=True)
        sys.exit(2)

    xlsx_path = Path(data_override) if data_override else config.data_xlsx
    if not xlsx_path.exists():
        click.echo(f"❌ Data xlsx not found: {xlsx_path}", err=True)
        sys.exit(1)

    _run_r_figures(xlsx_path, config.figures_dir, config.tables_dir)
```

Also add the imports at the top of `cli.py`:

```python
import shutil
import subprocess
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `uv run pytest tests/test_cli.py -v`
Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add src/mgen/cli.py tests/test_cli.py
git commit -m "feat: replace 'mgen plot' with 'mgen figures' (R subprocess) (#24)"
```

---

### Task 4: Add `all` command

**Files:**
- Modify: `src/mgen/cli.py`
- Modify: `tests/test_cli.py`

- [ ] **Step 1: Write tests for `all` command**

Add to `tests/test_cli.py`:

```python
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
            patch("shutil.which", return_value="/usr/bin/Rscript"),
            patch("subprocess.run") as mock_subprocess,
        ):
            mock_result = PipelineResult(success=True, errors=[])
            mock_pipeline.return_value = mock_result
            # Create the data xlsx so the figures step finds it
            (tmp_path / "Data.xlsx").touch()
            mock_subprocess.return_value.returncode = 0

            result = runner.invoke(main, ["all", str(config_file)])

        assert result.exit_code == 0
        mock_pipeline.assert_called_once()
        mock_subprocess.assert_called_once()
```

Add this import at the top of `tests/test_cli.py`:

```python
from mgen.pipeline import PipelineResult
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `uv run pytest tests/test_cli.py::TestAllCommand -v`
Expected: FAIL — `"all"` command does not exist.

- [ ] **Step 3: Implement the `all` command in `cli.py`**

Add after the `figures` function:

```python
@main.command(name="all")
@click.argument("config_path", default="cycle.toml", type=click.Path(exists=False))
def all_command(config_path: str) -> None:
    """Run data pipeline then R figures back-to-back."""
    try:
        config = load_config(Path(config_path))
    except ConfigError as e:
        click.echo(f"❌ Config error: {e}", err=True)
        sys.exit(2)

    # --- Data step ---
    pipeline_result = run_pipeline(config)

    if pipeline_result.errors:
        click.echo("", err=True)
        for error in pipeline_result.errors:
            click.echo(f"  {error}", err=True)
        click.echo("", err=True)

    if not pipeline_result.success:
        error_count = sum(
            1 for e in pipeline_result.errors if e.severity == "error"
        )
        click.echo(
            f"❌ Pipeline failed: {error_count} error(s) across domains", err=True
        )
        sys.exit(1)

    click.echo(f"✅ Wrote {config.data_xlsx}")

    # --- Figures step ---
    _run_r_figures(config.data_xlsx, config.figures_dir, config.tables_dir)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `uv run pytest tests/test_cli.py -v`
Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add src/mgen/cli.py tests/test_cli.py
git commit -m "feat: add 'mgen all' command (#24)"
```

---

### Task 5: Rename Data.xlsx → MtMessengerEcologyData.xlsx

**Files:**
- Modify: `cycle.example.toml`
- Modify: `src/mgen/writer.py`
- Modify: `README.md`

- [ ] **Step 1: Update `cycle.example.toml`**

Replace with:

```toml
# Mt Messenger monitoring pipeline configuration.
# Copy this file to cycle.toml and update paths for the current reporting cycle.

[input]
macroinvertebrate_db = "T:/Wellington/TT Projects/1001181/1001181.4500/WorkingMaterial/Aquatic Monitoring/Aquatic monitoring spreadsheets/MTMA Macroinvertebrate Database.xlsx"
aquatic_monitoring_db = "T:/Wellington/TT Projects/1001181/1001181.4500/WorkingMaterial/Aquatic Monitoring/Aquatic monitoring spreadsheets/MTMA Aquatic Monitoring Database.xlsx"

[output]
data_xlsx = "T:/Wellington/TT Projects/1001181/1001181.4500/WorkingMaterial/Aquatic Monitoring/2025-2026 Report/Stats/MtMessengerEcologyData.xlsx"
figures_dir = "T:/Wellington/TT Projects/1001181/1001181.4500/WorkingMaterial/Aquatic Monitoring/2025-2026 Report/Figures"
tables_dir = "T:/Wellington/TT Projects/1001181/1001181.4500/WorkingMaterial/Aquatic Monitoring/2025-2026 Report/Tables"
```

- [ ] **Step 2: Update `writer.py` log message**

In `src/mgen/writer.py`, change line 77:

```python
    logger.info("Wrote %s (%d sheets)", output_path, len(SHEET_ORDER))
```

(Remove the hardcoded "Data.xlsx" string; use the actual path instead.)

Also update the module docstring (line 1):

```python
"""Write assembled DataFrames to the output xlsx.

This is infrastructure — it knows about Excel format details but not
about domain logic. It receives validated DataFrames and writes them.
"""
```

- [ ] **Step 3: Update `README.md` pipeline diagram**

Replace the `Data.xlsx\n5 sheets` node in the Mermaid diagram:

```
    Writer --> Output[/"MtMessengerEcologyData.xlsx\n6 sheets"/]
```

(Also update from "5 sheets" to "6 sheets" since the clarity domain was added.)

- [ ] **Step 4: Run existing tests to confirm nothing breaks**

Run: `uv run pytest tests/ -v --ignore=tests/test_plots --ignore=tests/test_exports --ignore=tests/test_stats --ignore=tests/golden --ignore=tests/test_figures_integration.py`
Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add cycle.example.toml src/mgen/writer.py README.md
git commit -m "refactor: rename Data.xlsx to MtMessengerEcologyData.xlsx (#24)"
```

---

### Task 6: Add R setup to dev_sync

**Files:**
- Create: `tasks/scripts/install_r.sh`
- Create: `tasks/shims/install_r`
- Create: `tasks/shims/install_r.cmd`
- Create: `tasks/shims/install_r.ps1`
- Modify: `tasks/scripts/dev_sync.sh`

- [ ] **Step 1: Create `tasks/scripts/install_r.sh`**

```bash
#!/bin/bash

echo "Ensuring R is installed..."

if command -v Rscript &> /dev/null; then
    r_version=$(Rscript --version 2>&1 | head -1)
    echo "  R already installed: $r_version"
else
    echo "  R not found. Installing via winget..."
    if [ -n "$WINDIR" ]; then
        if command -v winget &> /dev/null; then
            winget install --id RProject.R --accept-source-agreements --accept-package-agreements --silent
            if [ $? -ne 0 ]; then
                echo "Error: Failed to install R via winget."
                echo "Please install R manually from https://cran.r-project.org/"
                exit 1
            fi
            # Refresh PATH to pick up new R installation
            export PATH="$PATH:/c/Program Files/R/R-*/bin"
        else
            echo "Error: winget not available. Please install R manually from https://cran.r-project.org/"
            exit 1
        fi
    else
        echo "Error: Non-Windows R installation not implemented. Please install R manually."
        exit 1
    fi
fi

echo "Ensuring R packages are installed..."
Rscript -e "
required <- c('readxl', 'dplyr', 'tidyr', 'ggplot2', 'vegan', 'indicspecies',
              'ggrepel', 'zoo', 'patchwork', 'openxlsx', 'lubridate')
missing <- required[!required %in% installed.packages()[, 'Package']]
if (length(missing) > 0) {
  cat('  Installing:', paste(missing, collapse=', '), '\n')
  install.packages(missing, repos='https://cloud.r-project.org/', quiet=TRUE)
} else {
  cat('  All R packages already installed.\n')
}
"

if [ $? -ne 0 ]; then
    echo "Error: Failed to install R packages."
    exit 1
fi

echo "  R setup complete."
```

- [ ] **Step 2: Create the shim files**

Create `tasks/shims/install_r` (no extension, bash):

```bash
#!/bin/bash
source ./tasks/scripts/install_r.sh
```

Create `tasks/shims/install_r.cmd`:

```cmd
@echo off
call "%~dp0install_r.ps1" %*
```

Create `tasks/shims/install_r.ps1`:

```powershell
. ./tasks/scripts/sh_runner.ps1
RunShFileWithGitBash -ShFilePath "./tasks/shims/install_r"
```

- [ ] **Step 3: Add R install step to `dev_sync.sh`**

In `tasks/scripts/dev_sync.sh`, add the R install step after
`configure_project`:

```bash
#!/bin/bash

source ./tasks/shims/install_backend
source ./tasks/shims/install_venv
source ./tasks/shims/activate_venv
source ./tasks/shims/sync_requirements
source ./tasks/shims/configure_project
source ./tasks/shims/install_r

echo Done!
```

- [ ] **Step 4: Commit**

```bash
git add tasks/scripts/install_r.sh tasks/shims/install_r tasks/shims/install_r.cmd tasks/shims/install_r.ps1 tasks/scripts/dev_sync.sh
git commit -m "feat: add R installation to dev_sync setup (#24)"
```

---

### Task 7: Update README with usage section

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add usage section to README**

After the "Pipeline Architecture" section and before "Getting Started on
Development", add:

```markdown
## Running the Pipeline

After setup, three commands are available:

```Powershell
# Process input spreadsheets → MtMessengerEcologyData.xlsx
mgen data

# Generate figures from the data xlsx (runs R pipeline)
mgen figures

# Generate figures from a manually edited copy
mgen figures --data ./my-edited-copy.xlsx

# Run data processing + figures back-to-back
mgen all

# Validate config without running anything
mgen validate
```

All commands accept an optional path to `cycle.toml` (defaults to
`./cycle.toml`).
```

- [ ] **Step 2: Update the "Getting Started" section**

Update the description to mention R:

```markdown
## Getting Started

### One-time setup

Run the following command in Windows PowerShell to install Python, R, all
dependencies, and configure VS Code (your current directory should be the root
of the repo):

```Powershell
./tasks/dev_sync.ps1
```
```

- [ ] **Step 3: Run full test suite to confirm nothing is broken**

Run: `uv run pytest tests/ -v --ignore=tests/golden --ignore=tests/test_figures_integration.py`
Expected: All PASS.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: update README with new CLI commands and R setup (#24)"
```
