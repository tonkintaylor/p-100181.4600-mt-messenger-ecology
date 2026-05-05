---
name: verifying-work
description: Use when about to claim work is complete, fixed, or passing — or before yielding control at session end. Runs the verification gate (evidence before claims) and, if finishing, the completion checkpoint (lessons, skill gaps, self-rating, template). Single exit gate referenced from AGENTS.md.
module: qa.review.verification
test-status: tests-have-been-run
---

# Verifying Work

Claiming work is complete without verification is dishonesty, not efficiency.

**Core principle:** Evidence before claims, always.

## When to Use

- Before ANY success/completion claim (mid-stream or session end)
- Before committing, creating PRs, or yielding control
- Whenever AGENTS.md says "verify your work"

## The Process

Run the verification harness:

    uv run .agents/skills/verifying-work/scripts/verification_harness.py

The harness walks through verification gates first (shared for all invocations), then asks whether you are finishing or continuing. If finishing, it continues into the completion checkpoint.

## If the Harness Aborts

Read the script source, diagnose what went wrong, file a lesson, then immediately stop work and report back to the user.

## Related Skills

- `assessing-skill-testing-necessity` — invoked at step 7 (test-necessity assessment)
- `identifying-skill-gaps` — invoked at step 10 (skill-gap scan in completion checkpoint)
- `creating-lessons` — invoked at steps 9, 10, 11 (documents difficulties, gaps, sub-threshold ratings)
