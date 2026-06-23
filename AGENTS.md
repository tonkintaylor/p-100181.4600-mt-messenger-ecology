# Agent Instructions

See the .agents/skills directory. You MUST use skills for all tasks.

You must start with `using-superpowers` for EVERY task, no matter how small. Keep `self-reflecting` active throughout — invoke it whenever you encounter failures, retries, or corrections.

Before finishing you MUST use verifying-claims to verify your work, no matter what.

When running pre-commit checks, use: `pre-commit run --all-files`

## Code Style

- Never use multiline strings (docstrings) as inline comments on fields or attributes. Document class attributes in the class docstring's `Attributes:` section instead.
