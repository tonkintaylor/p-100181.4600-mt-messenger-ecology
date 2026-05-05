#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# ///
"""Detect which pre-commit runner is available and run all hooks.

Detection order:
    1. prek        — installed in the current environment
    2. pre-commit  — installed in the current environment
    3. uvx prek    — fallback via ephemeral uv tool execution

Usage:
    uv run .agents/skills/using-prek-pre-commit/scripts/run-hooks.py
"""

from __future__ import annotations

import subprocess
import sys


def _is_installed(package: str) -> bool:
    """Check whether *package* is installed via ``uv pip show``."""
    return (
        subprocess.run(
            ["uv", "pip", "show", package],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        ).returncode
        == 0
    )


def _validate_args(argv: list[str]) -> None:
    """Reject unsupported arguments.

    This script only supports "run all hooks" mode: no arguments or ``-a``.
    """
    if argv and argv != ["-a"]:
        print(
            "Unsupported arguments. This script only supports running all hooks; "
            "use no arguments or '-a'.",
            file=sys.stderr,
        )
        raise SystemExit(2)


def main() -> int:
    _validate_args(sys.argv[1:])

    if _is_installed("prek"):
        cmd = ["uv", "run", "prek", "-a"]
    elif _is_installed("pre-commit"):
        cmd = ["uv", "run", "pre-commit", "run", "--all-files"]
    else:
        print(
            "Neither prek nor pre-commit found in environment; "
            "falling back to uvx prek",
            file=sys.stderr,
        )
        cmd = ["uvx", "prek", "-a"]

    return subprocess.run(cmd, check=False).returncode


if __name__ == "__main__":
    raise SystemExit(main())
