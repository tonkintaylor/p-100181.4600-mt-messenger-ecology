"""Command-line interface for the mgen pipeline."""

from __future__ import annotations

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


@main.command()
@click.argument("config_path", default="cycle.toml", type=click.Path(exists=False))
@click.option(
    "--only",
    type=click.Choice(["sediment", "macro", "community", "all"]),
    default="all",
)
@click.option(
    "--data-xlsx",
    type=click.Path(),
    default=None,
    help="Override Data.xlsx path",
)
def plot(config_path: str, only: str, data_xlsx: str | None) -> None:
    """Generate monitoring figures from Data.xlsx."""
    try:
        config = load_config(Path(config_path))
    except ConfigError as e:
        click.echo(f"❌ Config error: {e}", err=True)
        sys.exit(2)

    xlsx_path = Path(data_xlsx) if data_xlsx else config.data_xlsx
    if not xlsx_path.exists():
        click.echo(f"❌ Data.xlsx not found: {xlsx_path}", err=True)
        sys.exit(1)

    import pandas as pd  # noqa: PLC0415

    data: dict[str, pd.DataFrame] = {}
    with pd.ExcelFile(xlsx_path) as xls:
        for sheet in xls.sheet_names:
            data[sheet] = pd.read_excel(xls, sheet_name=sheet)

    from mgen.figures import generate_figures  # noqa: PLC0415

    fig_result = generate_figures(data, config.figures_dir, only=only)

    if fig_result.warnings:
        for warning in fig_result.warnings:
            click.echo(f"⚠️  {warning}", err=True)

    if fig_result.success:
        file_count = len(fig_result.files_written)
        click.echo(f"✅ Wrote {file_count} files to {config.figures_dir}")
    else:
        click.echo("❌ No figures generated", err=True)
        sys.exit(1)
