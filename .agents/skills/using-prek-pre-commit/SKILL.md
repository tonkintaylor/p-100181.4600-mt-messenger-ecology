---
name: using-prek-pre-commit
description: Use when invoking the pre-commit runner to execute hooks, or when you need the exact command to run all checks
module: make.git.hooks.prek
test-status: tests-have-been-run
---

# using-prek-pre-commit

## Usage

Run all pre-commit hooks using the detection script:

```bash
uv run .agents/skills/using-prek-pre-commit/scripts/run-hooks.py
```

The script automatically detects which pre-commit framework is installed and runs the appropriate command.

## Detection Order

The script checks which runner is available in this order:

1. **prek** — `uv pip show prek` succeeds → runs `uv run prek -a`
2. **pre-commit** — `uv pip show pre-commit` succeeds → runs `uv run pre-commit run --all-files`
3. **Fallback** — neither installed → runs `uvx prek -a` (ephemeral uv tool execution)

## Manual Detection

If the script is not available (e.g. skills are not installed locally), detect and run manually:

```bash
if uv pip show prek >/dev/null 2>&1; then
    uv run prek -a
elif uv pip show pre-commit >/dev/null 2>&1; then
    uv run pre-commit run --all-files
else
    uvx prek -a
fi
```

## Quick Reference

- Run all pre-commit hooks: `uv run .agents/skills/using-prek-pre-commit/scripts/run-hooks.py`
- Manual with prek: `uv run prek -a`
- Manual with pre-commit: `uv run pre-commit run --all-files`
- Fallback (neither installed): `uvx prek -a`

## Related Skills

- `validating-hooks` — Why hooks exist, the philosophy of hook-based validation, and how to think about fixing failures.
