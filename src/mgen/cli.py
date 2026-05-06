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
def run(config_path: str) -> None:
    """Run the pipeline using the specified cycle.toml config."""
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
