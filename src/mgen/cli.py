"""Command-line interface for the mgen pipeline."""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

import click

from mgen.config import ConfigError, PipelineConfig, load_config
from mgen.pipeline import PipelineResult, run_pipeline


@click.group()
@click.option(
    "-q",
    "--quiet",
    is_flag=True,
    default=False,
    help="Suppress status messages (only show errors).",
)
@click.pass_context
def main(ctx: click.Context, *, quiet: bool) -> None:
    """Mt Messenger ecology data pipeline."""
    ctx.ensure_object(dict)
    ctx.obj["quiet"] = quiet


def _echo(message: str, ctx: click.Context, *, err: bool = False) -> None:
    """Print *message* unless ``--quiet`` is active (errors always print)."""
    if err or not ctx.obj.get("quiet"):
        click.echo(message, err=err)


def _handle_pipeline_result(
    result: PipelineResult, config: PipelineConfig, ctx: click.Context
) -> None:
    """Display pipeline errors and exit on failure."""
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

    _echo(f"✅ Wrote {config.data_xlsx}", ctx)


@main.command()
@click.argument("config_path", default="cycle.toml", type=click.Path(exists=False))
@click.pass_context
def data(ctx: click.Context, config_path: str) -> None:
    """Process input spreadsheets and write MtMessengerEcologyData.xlsx."""
    try:
        config = load_config(Path(config_path))
    except ConfigError as e:
        click.echo(f"❌ Config error: {e}", err=True)
        sys.exit(2)

    result = run_pipeline(config)
    _handle_pipeline_result(result, config, ctx)


@main.command()
@click.argument("config_path", default="cycle.toml", type=click.Path(exists=False))
@click.pass_context
def validate(ctx: click.Context, config_path: str) -> None:
    """Validate inputs without writing output."""
    try:
        config = load_config(Path(config_path))
    except ConfigError as e:
        click.echo(f"❌ Config error: {e}", err=True)
        sys.exit(2)

    _echo("✅ Config valid. Inputs found:", ctx)
    _echo(f"   Macro DB: {config.macroinvertebrate_db}", ctx)
    _echo(f"   Aquatic DB: {config.aquatic_monitoring_db}", ctx)
    _echo(f"   Output: {config.data_xlsx}", ctx)
    _echo(f"   Figures: {config.figures_dir}", ctx)
    _echo(f"   Tables: {config.tables_dir}", ctx)


def _run_r_figures(
    xlsx_path: Path, figures_dir: Path, tables_dir: Path, ctx: click.Context
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

    # Resolved relative to source tree — requires a dev checkout (not pip install).
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
    _echo(f"Running R figures: {xlsx_path}", ctx)
    # stdout/stderr pass through to the terminal so R progress is visible.
    result = subprocess.run(cmd, check=False)

    if result.returncode != 0:
        click.echo("❌ R figure pipeline failed", err=True)
        sys.exit(1)

    _echo(f"✅ Figures written to {figures_dir}", ctx)


@main.command()
@click.argument("config_path", default="cycle.toml", type=click.Path(exists=False))
@click.option(
    "--data",
    "data_override",
    type=click.Path(),
    default=None,
    help="Override data xlsx path (use manually edited data).",
)
@click.pass_context
def figures(ctx: click.Context, config_path: str, data_override: str | None) -> None:
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

    _run_r_figures(xlsx_path, config.figures_dir, config.tables_dir, ctx)


@main.command(name="all")
@click.argument("config_path", default="cycle.toml", type=click.Path(exists=False))
@click.pass_context
def all_command(ctx: click.Context, config_path: str) -> None:
    """Run data pipeline then R figures back-to-back."""
    try:
        config = load_config(Path(config_path))
    except ConfigError as e:
        click.echo(f"❌ Config error: {e}", err=True)
        sys.exit(2)

    pipeline_result = run_pipeline(config)
    _handle_pipeline_result(pipeline_result, config, ctx)

    _run_r_figures(config.data_xlsx, config.figures_dir, config.tables_dir, ctx)
