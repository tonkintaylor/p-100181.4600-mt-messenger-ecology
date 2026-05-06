---
name: verifying-claims
description: Use when about to claim work is complete, fixed, or passing, before committing or creating PRs - requires running verification commands and confirming output before making any success claims; evidence before assertions always
module: qa.review.verification
test-status: tests-have-been-run
---

# Review Verification

## Overview

Claiming work is complete without verification is dishonesty, not efficiency.

**Core principle:** Evidence before claims, always.

**Violating the letter of this rule is violating the spirit of this rule.**

## The Iron Law

```text
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

If you haven't run the verification command in this message, you cannot claim it passes.

## The Gate Function

```text
BEFORE claiming any status or expressing satisfaction:

→ 0. DISPATCH CHECK: Does this claim involve skill test work?
   - If YES: Were test scenarios dispatched as subagent runs
     and were results reviewed?
     File existence is not execution evidence.
     Coverage hooks passing is not execution evidence.
     RED PASS is not completion evidence — only RED FAIL proves diagnostic power.
     If dispatch evidence is missing or any RED run passed, the claim is invalid — STOP.
     STOP means: state actual status with the gap, then fix it.
     While the gap exists, forward-progress actions are forbidden:
     no commit, no push, no `report_progress`, no `parallel_validation`.
     STOP does NOT mean: silently fix the gap, then claim success.
     Reporting the gap IS the required output — not a step to skip.
→ 1. IDENTIFY: What command proves this claim?
→ 2. TOOL CHECK: Are you about to claim a required tool or capability is unavailable?
   - If YES → Run `command -v <tool>` or `<tool> --help` first.
     Report the actual output, any error message, and the exit code.
     An assumption about tool availability is NOT evidence.
     Pattern-matching from assumptions about environment type is NOT evidence.
     A non-zero exit code from an attempted command is evidence, even if output is empty.
     If you skip the verification command and claim unavailability, you have fabricated a constraint — STOP.
→ 3. RUN: Execute the FULL command (fresh, complete)
→ 4. READ: Full output, check exit code, count failures
→ 5. VERIFY: Does output confirm the claim?
   - If NO → State actual status with evidence
   - If YES → State claim WITH evidence
→ 6. ASSESS: Do your changes introduce new testable behavior?
   - REQUIRED SUB-SKILL: Use `assessing-skill-testing-necessity`
   - If YES → Follow the `assessing-skill-testing-necessity` outcome,
     including writing/running any required tests, and STOP until satisfied.
   - If NO → Proceed to step 7
→ 7. RESTRUCTURING CHECK: Did you move or restructure skill content between files?
   - If YES → Existing tests MUST still be executed (RED/GREEN dispatched)
     for ALL affected skills — even when no new test scenario was authored.
     "No new test required" means no new scenario needs to be written.
     It NEVER means test execution can be skipped.
     Every restructuring needs a before-edit baseline (RED) and an
     after-edit confirmation (GREEN) to prove behavior was preserved.
   - If NO → Proceed
→ 8. ONLY THEN: Make the claim

Skip any step = lying, not verifying
Silently fixing a gap without reporting it = hiding, not verifying
```

## Common Failures

| Claim                  | Requires                                                   | Not Sufficient                                      |
| ---------------------- | ---------------------------------------------------------- | --------------------------------------------------- |
| Tests pass             | Test command output: 0 failures                            | Previous run, "should pass"                         |
| Linter clean           | Linter output: 0 errors                                    | Partial check, extrapolation                        |
| Build succeeds         | Build command: exit 0                                      | Linter passing, logs look good                      |
| Bug fixed              | Test original symptom: passes                              | Code changed, assumed fixed                         |
| Regression test works  | Red-green cycle verified                                   | Test passes once                                    |
| Agent completed        | VCS diff shows changes                                     | Agent reports "success"                             |
| Requirements met       | Line-by-line checklist                                     | Tests passing                                       |
| Skill tests done       | RED FAIL + GREEN PASS results shown                        | test-\*.md files exist, RED PASS reported as "done" |
| Changes need tests     | New tests written + run for new behavior                   | Existing tests pass                                 |
| Tests added/modified   | Tests executed (RED + GREEN dispatched)                    | Files exist, coverage hook OK                       |
| Tool unavailable       | `command -v <tool>` or `<tool> --help` output              | Assumption, pattern-matching                        |
| Work complete          | All required gates satisfied now                           | Deferral note for broken unfixed state              |
| Task complete          | Completion Template present in final response              | Verbal summary without template lines               |
| HARD-GATE satisfied    | Gate's required outcome achieved                           | Well-reasoned explanation for why it wasn't         |
| Gap identified         | Immediate action to close the gap                          | Documenting the gap and proceeding                  |
| Content restructured   | RED/GREEN dispatched for all affected skills               | "No new test authored" (execution still required)   |
| Feature/setting exists | Local manifest inspection, `--version`, or settings search | Upstream repo docs, main branch source code         |
| New files tracked      | `git check-ignore -v <path>` or `git status` shows tracked | Files exist on disk, directory listing              |
| System works by X      | Inspected implementation (read code/config/trace path)     | Inference from visible behavior, "appears to"       |

## Test-Necessity Assessment

**REQUIRED SUB-SKILL:** Use `assessing-skill-testing-necessity` before claiming completion on any change — it determines whether new tests must be written and run.

## Red Flags - STOP

- Using "should", "probably", "seems to"
- Expressing satisfaction before verification ("Great!", "Perfect!", "Done!", etc.)
- About to commit/push/PR without verification
- Trusting agent success reports
- Relying on partial verification
- Thinking "just this once"
- Tired and wanting work over
- **ANY wording implying success without having run verification**
- Asserting an environment limitation or tool absence without running a command to verify
- Describing how a system, mechanism, or process works without inspecting the actual implementation
- Acknowledging missing required work ("future PR", "follow-up", "could be added later") while claiming completion — this is a contradiction, not a scope decision
- Stating an unsatisfied gate and then taking forward-progress actions (commit, push, `report_progress`, `parallel_validation`) anyway
- Identifying missing work and treating the identification as the deliverable — when a gate reveals a gap, the required response is to do the work immediately, not to document the gap and proceed. "Transparent reporting" of an unsatisfied gate is not compliance with the gate; only the gate's required outcome counts. If you can identify what is missing, you can do it now. Load the skill that governs the missing work and follow its procedure.
- Classifying new advisory patterns ("prefer X", "only use Y when Z") as "analytic" to avoid writing tests — advisory patterns introduce new decision criteria and are behavioral additions regardless of phrasing

## Rationalization Prevention

See `references/rationalization-prevention.md` for the full excuse→reality lookup table. Consult it when you catch yourself forming an excuse for why verification can be skipped or deferred.

## Key Patterns

### Skill test work (check FIRST — before all other patterns)

```text
✅ test-*.md files written → RED run dispatched as subagent → GREEN run dispatched → results reported
❌ "Tests created" (only test-*.md files exist, no dispatch evidence)
❌ "Coverage hook passes" (hook checks file existence, not execution)
❌ "Existing tests pass" (existing tests cover old behavior — new gates/rules need new scenarios)
```

> **Verification gate — front-loaded because file existence creates a false sense of completeness:**
>
> Before evaluating ANY other verification checks, answer these two questions:
>
> 1. _Do my changes introduce new behavior that needs new test scenarios?_ If yes, have new `test-*.md` files been written?
> 2. _Were the test scenarios dispatched as subagent runs and were the results reviewed?_ File existence is not evidence of test execution. Coverage hooks report file presence, not execution — their "OK" output does not mean tests were run.
>
> If the answer to either question is no, the work is incomplete — regardless of what other checks pass. Do not proceed to evaluate other verification patterns until this gate is satisfied.

### Tests

```text
✅ [Run test command] [See: 34/34 pass] "All tests pass"
❌ "Should pass now" / "Looks correct"
```

### Regression tests (TDD Red-Green)

```text
✅ Write → Run (pass) → Revert fix → Run (MUST FAIL) → Restore → Run (pass)
❌ "I've written a regression test" (without red-green verification)
```

### Build

```text
✅ [Run build] [See: exit 0] "Build passes"
❌ "Linter passed" (linter doesn't check compilation)
```

### Requirements

```text
✅ Re-read plan → Create checklist → Verify each → Report gaps or completion
✅ For each required output path: verify requirement intent (committed artifact vs ignored/generated) before changing `.gitignore`
✅ If output disposition intent is unclear, leave existing ignore config unchanged and report the gap
❌ "Tests pass, phase complete"
❌ Infer commit/ignore status from similar-looking paths already in `.gitignore`
```

### Agent delegation

```text
✅ Agent reports success → Check VCS diff → Verify changes → Report actual state
❌ Trust agent report
```

### Environment capability claims

```text
✅ Run `command -v <tool>` or `<tool> --help` → Report actual output → THEN claim availability or absence
✅ Settings/features from docs → Inspect local extension manifest or run settings search → THEN recommend
❌ "This environment doesn't support X" (without attempting the command)
❌ Pattern-matching from assumptions about sandboxed/CI environments
❌ Settings/features from upstream repo docs applied without checking the installed version
```

### Version control tracking

```text
✅ New file created → `git check-ignore -v <path>` shows "not ignored" or `git status` shows file as tracked/staged → THEN claim deployed
❌ "File exists in the directory" (existence ≠ tracked — global ignore rules can hide files from Git)
❌ "I created the file" (creation is not deployment if .gitignore excludes it)
```

### System mechanics claims

```text
✅ Read implementation code/config → Trace the actual mechanism → THEN describe how it works
❌ "The system works by X" (inferred from surface behavior without inspecting code)
❌ "The approach currently does Y" (assumed from what's visible, not verified against implementation)
```

> Factual assertions about how a system, mechanism, or process works are claims — the same class as test-pass claims or tool-availability claims. If you haven't inspected the implementation, hedge explicitly: "appears to", "based on what's visible".

## Why This Matters

From 24 failure memories:

- your human partner said "I don't believe you" - trust broken
- Undefined functions shipped - would crash
- Missing requirements shipped - incomplete features
- Time wasted on false completion → redirect → rework
- Violates: "Honesty is a core value. If you lie, you'll be replaced."

## When To Apply

### ALWAYS before

- ANY variation of success/completion claims
- ANY expression of satisfaction
- ANY positive statement about work state
- Committing, PR creation, task completion
- Moving to next task
- Delegating to agents

### Rule applies to

- Exact phrases
- Paraphrases and synonyms
- Implications of success
- ANY communication suggesting completion/correctness

## The Bottom Line

**No shortcuts for verification.**

Run the command. Read the output. THEN claim the result.

This is non-negotiable.

## Related Skills

- `assessing-skill-testing-necessity` — **REQUIRED SUB-SKILL.** Determines whether changes require new tests. Invoked from Gate Function step 6.
- `modifying-skills` — Uses verification discipline when editing existing skills.
- `creating-skills` — Uses verification discipline when creating new skills.
- `running-skill-tests` — Required for dispatching test runs once test-necessity is established.
