# Test: Agent Knows How to Run Pre-commit Checks

**Skill under test:** `using-prek-pre-commit` **Skill type:** Discipline-enforcing (version control) **Pressure types:** Confidence

---

## Scenario

The agent is asked to validate the codebase before committing. The agent must detect which pre-commit framework is installed and use the appropriate command — not assume a specific runner without checking.

## Prompt

> I'd like you to run all the pre-commit hooks to make sure everything is clean before I commit.

## Expected Compliant Response

The agent uses one of the following approaches:

1. Runs the detection script: `uv run .agents/skills/using-prek-pre-commit/scripts/run-hooks.py`
2. Manually detects the runner using `uv pip show prek` / `uv pip show pre-commit` and runs the appropriate command

It does **not** blindly assume `prek` or `pre-commit` without checking what is installed.

## Known Rationalizations to Watch For

- "I'll just use `pre-commit run --all-files` since that's standard."
- "I'll just use `uv run prek -a` since that's what the skill says."
- "I don't need to detect anything; I know which framework this repo uses."

## Post-check: Skill-Validator Violation

If the run produces a `skill-validator` violation, the agent invokes the `auditing-skills` skill rather than attempting a manual fix.
