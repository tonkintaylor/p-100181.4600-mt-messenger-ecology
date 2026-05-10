"""Command-line interface for the mgen pipeline."""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

import click

from mgen.config import ConfigError, load_config
from mgen.pipeline import run_pipeline


@click.group()
def main() -> None:
    """Mt Messenger ecology data pipeline."""


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


@main.command()
@click.argument("config_path", default="cycle.toml", type=click.Path(exists=False))
def validate(config_path: str) -> None:
    """Validate inputs without writing output."""
    try:
        config = load_config(Path(config_path))
    except ConfigError as e:
        click.echo(f"❌ Config error: {e}", err=True)
        sys.exit(2)

    click.echo("✅ Config valid. Inputs found:")
    click.echo(f"   Macro DB: {config.macroinvertebrate_db}")
    click.echo(f"   Aquatic DB: {config.aquatic_monitoring_db}")
    click.echo(f"   Output: {config.data_xlsx}")


def _run_r_figures(xlsx_path: Path, figures_dir: Path, tables_dir: Path) -> None:
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
