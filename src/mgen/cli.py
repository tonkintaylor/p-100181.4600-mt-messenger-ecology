"""Command-line interface for the mgen pipeline."""

from __future__ import annotations

from pathlib import Path

import click

from mgen.config import ConfigError, load_config


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
        msg = f"❌ Config error: {e}"
        raise SystemExit(msg) from None

    click.echo(f"Config loaded: {config.data_xlsx}")
    # Pipeline execution will be added in Task 10
    click.echo("⚠️  Pipeline not yet implemented")


@main.command()
@click.argument("config_path", default="cycle.toml", type=click.Path(exists=False))
def validate(config_path: str) -> None:
    """Validate inputs without writing output."""
    try:
        config = load_config(Path(config_path))
    except ConfigError as e:
        msg = f"❌ Config error: {e}"
        raise SystemExit(msg) from None

    click.echo("✅ Config valid. Inputs found:")
    click.echo(f"   Macro DB: {config.macroinvertebrate_db}")
    click.echo(f"   Aquatic DB: {config.aquatic_monitoring_db}")
    click.echo(f"   Output: {config.data_xlsx}")
