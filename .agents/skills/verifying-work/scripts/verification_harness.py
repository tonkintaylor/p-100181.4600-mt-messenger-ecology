# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///
"""verification_harness.py — Interactive verification and completion harness.

Drives the agent through verification gates (evidence-before-claims) and,
if the agent is finishing, continues into the completion checkpoint
(difficulty review, skill-gap scan, self-rating, Completion Template).

EXIT CODES:
  0 — verification passed (continuing) or full exit sequence complete (finishing)
  1 — agent blocked (lesson required, report to user)
  2 — verification failed (state actual status with evidence)

USAGE:
  uv run .agents/skills/verifying-work/scripts/verification_harness.py
"""

from __future__ import annotations

import sys

# ─── Constants ───────────────────────────────────────────────────────────────

CRITERIA: list[tuple[str, float]] = [
    ("Efficiency", 0.20),
    ("False leads", 0.20),
    ("Correctness", 0.25),
    ("Confidence calibration", 0.15),
    ("Clarity of communication", 0.20),
]

THRESHOLD = 90.0

COMMON_FAILURES = """\
┌────────────────────────┬─────────────────────────────────────────────────────────┬─────────────────────────────────────────────────────┐
│ Claim                  │ Requires                                                │ Not Sufficient                                      │
├────────────────────────┼─────────────────────────────────────────────────────────┼─────────────────────────────────────────────────────┤
│ Tests pass             │ Test command output: 0 failures                         │ Previous run, "should pass"                         │
│ Linter clean           │ Linter output: 0 errors                                │ Partial check, extrapolation                        │
│ Build succeeds         │ Build command: exit 0                                   │ Linter passing, logs look good                      │
│ Bug fixed              │ Test original symptom: passes                           │ Code changed, assumed fixed                         │
│ Regression test works  │ Red-green cycle verified                                │ Test passes once                                    │
│ Agent completed        │ VCS diff shows changes                                  │ Agent reports "success"                             │
│ Requirements met       │ Line-by-line checklist                                  │ Tests passing                                       │
│ Skill tests done       │ RED FAIL + GREEN PASS results shown                     │ test-*.md files exist, RED PASS reported as "done"  │
│ Changes need tests     │ New tests written + run for new behavior                │ Existing tests pass                                 │
│ Tests added/modified   │ Tests executed (RED + GREEN dispatched)                 │ Files exist, coverage hook OK                       │
│ Tool unavailable       │ `command -v <tool>` or `<tool> --help` output           │ Assumption, pattern-matching                        │
│ Work complete          │ All required gates satisfied now                        │ Deferral note for broken unfixed state              │
│ Task complete          │ Completion Template present in final response           │ Verbal summary without template lines              │
│ HARD-GATE satisfied    │ Gate's required outcome achieved                        │ Well-reasoned explanation for why it wasn't         │
│ Gap identified         │ Immediate action to close the gap                       │ Documenting the gap and proceeding                  │
│ Content restructured   │ RED/GREEN dispatched for all affected skills            │ "No new test authored" (execution still required)   │
│ Feature/setting exists │ Local manifest inspection, --version, or settings search│ Upstream repo docs, main branch source code         │
│ New files tracked      │ git check-ignore -v <path> or git status shows tracked  │ Files exist on disk, directory listing              │
│ System works by X      │ Inspected implementation (read code/config/trace path)  │ Inference from visible behavior, "appears to"       │
└────────────────────────┴─────────────────────────────────────────────────────────┴─────────────────────────────────────────────────────┘"""

KEY_PATTERNS = """\
SKILL TEST WORK (check FIRST):
  ✅ test-*.md files written → RED run dispatched → GREEN run dispatched → results reported
  ❌ "Tests created" (only files exist, no dispatch evidence)
  ❌ "Coverage hook passes" (checks file existence, not execution)

TESTS:
  ✅ [Run test command] [See: 34/34 pass] "All tests pass"
  ❌ "Should pass now" / "Looks correct"

REGRESSION TESTS (TDD Red-Green):
  ✅ Write → Run (pass) → Revert fix → Run (MUST FAIL) → Restore → Run (pass)
  ❌ "I've written a regression test" (without red-green verification)

BUILD:
  ✅ [Run build] [See: exit 0] "Build passes"
  ❌ "Linter passed" (linter doesn't check compilation)

REQUIREMENTS:
  ✅ Re-read plan → Create checklist → Verify each → Report gaps or completion
  ❌ "Tests pass, phase complete"

AGENT DELEGATION:
  ✅ Agent reports success → Check VCS diff → Verify changes → Report actual state
  ❌ Trust agent report

ENVIRONMENT CAPABILITY:
  ✅ Run `command -v <tool>` or `<tool> --help` → Report actual output → THEN claim
  ❌ "This environment doesn't support X" (without attempting command)

VERSION CONTROL TRACKING:
  ✅ git check-ignore -v <path> shows "not ignored" or git status shows tracked
  ❌ "File exists in the directory" (existence ≠ tracked)

SYSTEM MECHANICS:
  ✅ Read implementation code/config → Trace actual mechanism → THEN describe
  ❌ "The system works by X" (inferred from surface behavior)"""

RED_FLAGS = """\
STOP if you catch yourself:
  - Using "should", "probably", "seems to"
  - Expressing satisfaction before verification ("Great!", "Perfect!", "Done!")
  - About to commit/push/PR without verification
  - Trusting agent success reports
  - Relying on partial verification
  - Thinking "just this once"
  - ANY wording implying success without having run verification
  - Asserting environment limitation without running a command to verify
  - Describing system mechanics without inspecting implementation
  - Acknowledging missing work ("future PR", "follow-up") while claiming completion
  - Stating an unsatisfied gate then taking forward-progress actions anyway
  - Identifying missing work and treating identification as the deliverable
  - Classifying new advisory patterns as "analytic" to avoid writing tests"""

RATIONALIZATION_TABLE = """\
┌──────────────────────────────────────────────────────────────────────┬──────────────────────────────────────────────────────────────────────┐
│ Excuse                                                               │ Reality                                                              │
├──────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────┤
│ "Should work now"                                                    │ RUN the verification                                                │
│ "I'm confident"                                                      │ Confidence ≠ evidence                                               │
│ "Just this once"                                                     │ No exceptions                                                       │
│ "Linter passed"                                                      │ Linter ≠ compiler                                                   │
│ "Agent said success"                                                 │ Verify independently                                                │
│ "Partial check is enough"                                            │ Partial proves nothing                                              │
│ "Different words so rule doesn't apply"                              │ Spirit over letter                                                  │
│ "Existing tests cover this"                                          │ Existing tests cover old behavior, not new                          │
│ "This skill edit doesn't need tests"                                 │ If it changes what agents must do, it MUST have tests               │
│ "It's a clarification, not a new rule"                               │ If you added MUSTs/counters/red flags, it's behavioral              │
│ "The existing test already covers this"                              │ Re-run the test, show results, explain what value new text adds     │
│ "I'll fix the gap then report success"                               │ Report status THEN fix                                              │
│ "This environment doesn't support X"                                 │ Run the command — unverified claims are fabrication                 │
│ "I'll just set the metadata field to pass the hook"                  │ Metadata falsification is worse than a failing gate                 │
│ "I'll add tests in a follow-up PR"                                   │ Deferring required work is not a scope decision                     │
│ "I'm being transparent about a limitation"                           │ Transparency ≠ gate satisfaction                                    │
│ "This skill is informational/reference-only, so no tests needed"     │ No content-type classification exempts from test dispatch           │
└──────────────────────────────────────────────────────────────────────┴──────────────────────────────────────────────────────────────────────┘"""


# ─── Helpers ─────────────────────────────────────────────────────────────────


def ask_done_or_blocked() -> str:
    """Prompt agent for 'done' or 'blocked'. Re-prompts on invalid input."""
    while True:
        print("\nType 'done' when complete, or 'blocked' if stuck:")
        try:
            response = input("> ").strip().lower()
        except (EOFError, KeyboardInterrupt):
            return "blocked"
        if response in ("done", "blocked"):
            return response
        print("Invalid input. Enter 'done' or 'blocked'.")


def handle_blocked() -> None:
    """Collect description, instruct lesson creation, exit."""
    print("\n--- BLOCKED ---")
    print("Describe the blocker:")
    try:
        description = input("> ").strip()
    except (EOFError, KeyboardInterrupt):
        description = "(no description)"
    print(f"\nRecorded: {description}")
    print(
        "\nCreate a lesson via `creating-lessons` documenting this obstacle,\n"
        "then stop work and report back to the user."
    )
    sys.exit(1)


def check_response(response: str) -> None:
    """Exit if blocked."""
    if response == "blocked":
        handle_blocked()


def ask_yes_no(prompt: str) -> bool:
    """Prompt agent for yes/no. Re-prompts on invalid input."""
    while True:
        print(f"\n{prompt} (yes/no):")
        try:
            response = input("> ").strip().lower()
        except (EOFError, KeyboardInterrupt):
            handle_blocked()
        if response in ("yes", "y"):
            return True
        if response in ("no", "n"):
            return False
        print("Invalid input. Enter 'yes' or 'no'.")


def ask_choice(prompt: str, choices: list[str]) -> str:
    """Prompt agent for a choice from a list. Re-prompts on invalid input."""
    choices_lower = [c.lower() for c in choices]
    while True:
        print(f"\n{prompt} ({'/'.join(choices)}):")
        try:
            response = input("> ").strip().lower()
        except (EOFError, KeyboardInterrupt):
            handle_blocked()
        if response in choices_lower:
            return response
        print(f"Invalid input. Enter one of: {', '.join(choices)}")


def ask_score(criterion: str) -> int:
    """Prompt agent for a 0-100 integer score."""
    while True:
        print(f"\n  {criterion} (0-100):")
        try:
            response = input("  > ").strip()
        except (EOFError, KeyboardInterrupt):
            handle_blocked()
        try:
            score = int(response)
            if 0 <= score <= 100:
                return score
        except ValueError:
            pass
        print("  Invalid input. Enter an integer 0-100.")


def confirm_lesson_filed() -> str:
    """Confirm the agent has filed a lesson (URL or doc/lessons/ file). Loop until confirmed."""
    while True:
        has_lesson = ask_yes_no(
            "Do you have a lesson URL or a lesson file in doc/lessons/ for this?"
        )
        if has_lesson:
            return "Lessons filed"

        print(
            "\n⚠ No lesson filed yet.\n"
            "Invoke `creating-lessons` now to file the lesson.\n"
            "Return here once the lesson is created."
        )
        response = ask_done_or_blocked()
        check_response(response)


# ─── Verification Stages (shared) ───────────────────────────────────────────


def stage_dispatch_check() -> None:
    """Step 1: Skill test work dispatch check."""
    print("\n" + "=" * 60)
    print("STEP 1: DISPATCH CHECK")
    print("=" * 60)
    print(
        "\nDoes this claim involve skill test work?\n"
        "  - File existence is NOT execution evidence\n"
        "  - Coverage hooks passing is NOT execution evidence\n"
        "  - RED PASS is NOT completion evidence (only RED FAIL proves diagnostic power)\n"
        "\nIf dispatch evidence is missing or any RED run passed, the claim is INVALID.\n"
        "While the gap exists, forward-progress actions are forbidden.\n"
    )

    involves_tests = ask_yes_no("Does your claim involve skill test work?")
    if not involves_tests:
        print("✓ No skill test work involved. Proceeding.")
        return

    dispatched = ask_yes_no(
        "Were test scenarios dispatched as subagent runs AND results reviewed?"
    )
    if not dispatched:
        print(
            "\n✗ VERIFICATION FAILED: Skill test dispatch evidence missing.\n"
            "State the actual status with the gap, then fix it.\n"
            "Forward-progress actions are forbidden until resolved."
        )
        sys.exit(2)

    red_failed = ask_yes_no("Did all RED runs FAIL (proving diagnostic power)?")
    if not red_failed:
        print(
            "\n✗ VERIFICATION FAILED: RED PASS means test lacks diagnostic power.\n"
            "State the actual status, then redesign the test scenario."
        )
        sys.exit(2)

    print("✓ Skill test dispatch check passed.")


def stage_identify() -> None:
    """Step 2: Identify what command proves the claim."""
    print("\n" + "=" * 60)
    print("STEP 2: IDENTIFY")
    print("=" * 60)
    print("\nWhat command proves this claim? Key patterns:\n")
    print(KEY_PATTERNS)
    print(
        "\nEnter the verification command (or 'n/a' if no command needed"
        " — e.g., for a requirements checklist):"
    )
    try:
        cmd = input("> ").strip()
    except (EOFError, KeyboardInterrupt):
        handle_blocked()
    if not cmd:
        handle_blocked()
    print(f"\n✓ Verification target: {cmd}")


def stage_tool_check() -> None:
    """Step 3: Tool availability check."""
    print("\n" + "=" * 60)
    print("STEP 3: TOOL CHECK")
    print("=" * 60)
    print(
        "\nAre you about to claim a required tool or capability is UNAVAILABLE?\n"
        "  - Run `command -v <tool>` or `<tool> --help` first\n"
        "  - An assumption about tool availability is NOT evidence\n"
        "  - Pattern-matching from environment type is NOT evidence\n"
        "  - A non-zero exit code IS evidence (even if output is empty)\n"
    )

    claiming_unavailable = ask_yes_no(
        "Are you claiming any tool/capability is unavailable?"
    )
    if not claiming_unavailable:
        print("✓ No unavailability claims. Proceeding.")
        return

    verified = ask_yes_no(
        "Did you run the tool command and get actual error output/exit code?"
    )
    if not verified:
        print(
            "\n✗ VERIFICATION FAILED: Unverified tool unavailability claim.\n"
            "Run `command -v <tool>` or `<tool> --help` and report actual output."
        )
        sys.exit(2)

    print("✓ Tool check passed (verified with command output).")


def stage_run_and_read() -> None:
    """Steps 4-5: Run command and read output."""
    print("\n" + "=" * 60)
    print("STEPS 4-5: RUN & READ")
    print("=" * 60)
    print(
        "\nExecute the FULL verification command now (fresh, complete).\n"
        "Read the full output. Check exit code. Count failures.\n"
    )

    response = ask_done_or_blocked()
    check_response(response)
    print("✓ Command executed and output read.")


def stage_verify() -> None:
    """Step 6: Does output confirm the claim?"""
    print("\n" + "=" * 60)
    print("STEP 6: VERIFY")
    print("=" * 60)
    print("\nDoes the output confirm your claim?\n")
    print(COMMON_FAILURES)
    print()

    confirmed = ask_yes_no("Does the output confirm your claim?")
    if not confirmed:
        print(
            "\n✗ VERIFICATION FAILED: Output does not confirm the claim.\n"
            "State the ACTUAL status with evidence."
        )
        sys.exit(2)

    print("✓ Claim confirmed by verification output.")


def stage_assess() -> None:
    """Step 7: Test-necessity assessment."""
    print("\n" + "=" * 60)
    print("STEP 7: ASSESS — New testable behavior?")
    print("=" * 60)
    print(
        "\nDo your changes introduce new testable behavior?\n"
        "Invoke `assessing-skill-testing-necessity` NOW to determine this.\n"
        "Report back when complete.\n"
    )

    response = ask_done_or_blocked()
    check_response(response)

    needs_tests = ask_yes_no(
        "Did `assessing-skill-testing-necessity` determine new tests are needed?"
    )
    if needs_tests:
        satisfied = ask_yes_no(
            "Have the required tests been written AND run (RED FAIL + GREEN PASS)?"
        )
        if not satisfied:
            print(
                "\n✗ VERIFICATION FAILED: Required tests not yet written/run.\n"
                "Complete the test cycle before proceeding."
            )
            sys.exit(2)

    print("✓ Test-necessity assessment satisfied.")


def stage_restructuring_check() -> None:
    """Step 8: Restructuring check."""
    print("\n" + "=" * 60)
    print("STEP 8: RESTRUCTURING CHECK")
    print("=" * 60)
    print(
        "\nDid you move or restructure skill content between files?\n"
        "  - If YES: existing tests MUST still be executed (RED/GREEN dispatched)\n"
        "    for ALL affected skills — even when no new test scenario was authored.\n"
        "  - 'No new test required' means no new scenario needs to be written.\n"
        "    It NEVER means test execution can be skipped.\n"
    )

    restructured = ask_yes_no("Did you move or restructure skill content?")
    if not restructured:
        print("✓ No restructuring. Proceeding.")
        return

    dispatched = ask_yes_no("Were RED/GREEN runs dispatched for ALL affected skills?")
    if not dispatched:
        print(
            "\n✗ VERIFICATION FAILED: Restructured content requires test execution.\n"
            "Dispatch RED/GREEN for all affected skills."
        )
        sys.exit(2)

    print("✓ Restructuring check passed.")


# ─── Fork ────────────────────────────────────────────────────────────────────


def stage_fork() -> str:
    """Fork question: continuing or finishing?"""
    print("\n" + "=" * 60)
    print("VERIFICATION GATES PASSED")
    print("=" * 60)
    print(RED_FLAGS)
    print()
    print(RATIONALIZATION_TABLE)
    print(
        "\n─── FORK ───\n"
        "Are you FINISHING the task (yielding control to user)\n"
        "or CONTINUING work?\n"
        "\nIf finishing: the completion checkpoint runs next.\n"
        "If continuing: harness exits and you resume work.\n"
    )

    return ask_choice("finishing or continuing?", ["finishing", "continuing"])


# ─── Completion Checkpoint Stages (finishing only) ───────────────────────────


def stage_difficulty_review() -> str:
    """Step 9: Review for qualifying difficulties."""
    print("\n" + "=" * 60)
    print("STEP 9: Difficulty review")
    print("=" * 60)
    print(
        "\nScan the session for:\n"
        "  - Errors, retries, rejected changes\n"
        "  - User corrections or unexpected failures\n"
        "  - Methodological discoveries (novel techniques, insights)\n"
        "  - Abandoned approaches\n"
    )

    has_difficulties = ask_yes_no(
        "Were there any qualifying difficulties or methodological discoveries?"
    )
    if not has_difficulties:
        print("\n✓ No qualifying difficulties.")
        return "No qualifying difficulties or discoveries"

    print(
        "\nInvoke `creating-lessons` for EACH qualifying difficulty or discovery.\n"
        "File a lesson for each one. Do not proceed until all are filed."
    )
    return confirm_lesson_filed()


def stage_skill_gap_scan() -> str:
    """Step 10: Skill-gap scan."""
    print("\n" + "=" * 60)
    print("STEP 10: Skill-gap scan")
    print("=" * 60)
    print(
        "\nInvoke `identifying-skill-gaps` NOW to scan for sub-tasks\n"
        "performed without skill coverage.\n\n"
        "This is independent of difficulty review — it catches uncovered\n"
        "work regardless of whether any failure occurred.\n"
    )

    response = ask_done_or_blocked()
    check_response(response)

    has_gaps = ask_yes_no("Were any skill gaps identified?")
    if not has_gaps:
        print("\n✓ No skill gaps found.")
        return "No gaps found"

    print("\nFile a lesson for each confirmed gap via `creating-lessons`.")
    return confirm_lesson_filed()


def stage_self_rating() -> tuple[dict[str, int], float, str]:
    """Step 11: Self-rating."""
    print("\n" + "=" * 60)
    print("STEP 11: Self-rating")
    print("=" * 60)
    print(
        "\nRate your performance on each criterion (0-100).\n"
        "The harness computes the composite.\n"
    )

    scores: dict[str, int] = {}
    for criterion, _weight in CRITERIA:
        score = ask_score(criterion)
        scores[criterion] = score

    composite = compute_composite(scores)
    score_line = format_score_line(scores, composite)
    print(f"\n{score_line}")

    extra_urls = ""
    if composite < THRESHOLD:
        print(
            f"\n⚠ Composite {composite:.2f}% is below {THRESHOLD}% threshold.\n"
            "Invoke `creating-lessons` documenting which criteria drove\n"
            "the score down and what specific changes would improve them.\n"
        )
        response = ask_done_or_blocked()
        check_response(response)
        extra_urls = confirm_lesson_filed()
    else:
        print(f"\n✓ Composite {composite:.2f}% meets threshold.")

    return scores, composite, extra_urls


def stage_completion_template(
    lesson_text: str,
    gap_text: str,
    scores: dict[str, int],
    composite: float,
    extra_lesson_urls: str,
) -> None:
    """Step 12: Print the mandatory completion template."""
    print("\n" + "=" * 60)
    print("STEP 12: Completion Template")
    print("=" * 60)

    lesson_parts: list[str] = []
    if lesson_text != "No qualifying difficulties or discoveries":
        lesson_parts.append(lesson_text)
    if gap_text != "No gaps found":
        lesson_parts.append(gap_text)
    if extra_lesson_urls:
        lesson_parts.append(extra_lesson_urls)
    lessons_line = (
        ", ".join(lesson_parts)
        if lesson_parts
        else "No qualifying difficulties or discoveries"
    )

    score_line = format_score_line(scores, composite)

    print(
        "\nInclude this EXACT block in your final response:\n"
        "\n--- COMPLETION TEMPLATE ---\n"
    )
    print(f"Lessons: {lessons_line}")
    print(f"Skill gaps: {gap_text}")
    print(score_line)
    print("\n--- END TEMPLATE ---")


# ─── Computation ─────────────────────────────────────────────────────────────


def compute_composite(scores: dict[str, int]) -> float:
    """Compute the weighted composite score."""
    total = 0.0
    for criterion, weight in CRITERIA:
        total += scores[criterion] * weight
    return total


def format_score_line(scores: dict[str, int], composite: float) -> str:
    """Format the self-rating line for the completion template."""
    parts = [f"{name} {scores[name]}/100" for name, _ in CRITERIA]
    return f"Self-rating: {' · '.join(parts)} → Composite: {composite:.2f}%"


# ─── Main ────────────────────────────────────────────────────────────────────


def main() -> None:
    print("=== Verification Harness ===")
    print(
        "\nThis harness enforces evidence-before-claims verification.\n"
        "If you are finishing the task, it continues into the completion checkpoint.\n"
    )

    # ─── Shared verification gates (steps 0-7) ───
    stage_dispatch_check()
    stage_identify()
    stage_tool_check()
    stage_run_and_read()
    stage_verify()
    stage_assess()
    stage_restructuring_check()

    # ─── Fork ───
    choice = stage_fork()

    if choice == "continuing":
        print("\n" + "=" * 60)
        print("VERIFICATION PASSED — CONTINUING WORK")
        print("=" * 60)
        print("\nResume your task. Invoke this harness again before your next claim.")
        sys.exit(0)

    # ─── Completion checkpoint (steps 9-12) ───
    print("\n" + "=" * 60)
    print("ENTERING COMPLETION CHECKPOINT")
    print("=" * 60)

    lesson_text = stage_difficulty_review()
    gap_text = stage_skill_gap_scan()
    scores, composite, extra_urls = stage_self_rating()
    stage_completion_template(lesson_text, gap_text, scores, composite, extra_urls)

    print("\n" + "=" * 60)
    print("EXIT SEQUENCE COMPLETE")
    print("=" * 60)
    print("\nCopy the Completion Template above into your final response to the user.")
    sys.exit(0)


if __name__ == "__main__":
    main()
