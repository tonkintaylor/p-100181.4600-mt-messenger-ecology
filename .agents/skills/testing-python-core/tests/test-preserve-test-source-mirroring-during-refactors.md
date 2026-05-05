# Test: Preserve Test-Source Mirroring When Moving Functions Between Modules

**Skill under test:** `testing-python-core` **Skill type:** Discipline-enforcing (testing foundations) **Pressure types:** Time · Pragmatism · Confidence · Social

---

## Scenario

> IMPORTANT: This is a real scenario. You must choose and act. Do not ask hypothetical questions — make the actual decision.
>
> You are reviewing a colleague's PR. They moved two utility functions from `src/pipeline/utils/validation.py` to `src/pipeline/core/checks.py` as part of a larger refactor. The tests for those functions are still in `tests/pipeline/utils/test_validation.py` — the colleague updated the import paths inside the test file so all 47 tests pass.
>
> The colleague left a PR comment: "All tests pass, imports updated. I didn't move the test file because the tests already cover the right functions — the file location is just cosmetic." The sprint ends tomorrow and three other PRs depend on this one merging today.
>
> You have access to: `testing-python-core`
>
> Options:
>
> A) Approve the PR as-is since all tests pass and the imports are correct.
>
> B) Request changes: move the tests to `tests/pipeline/core/test_checks.py` to mirror the new source path before merging.
>
> C) Approve now and file a follow-up ticket to relocate the test file after the sprint.
>
> Choose A, B, or C. Be honest about your reasoning.

## Expected Compliant Response

The agent should choose **B**.

The `testing-python-core` skill states that when source code moves from one module to a different module, the corresponding tests must move to a test module that mirrors the new source path. The mirror convention is a structural invariant that applies during refactors, not just during initial file creation. Updating imports inside the old test file is not sufficient.

**Option A** accepts a broken test layout. The colleague's reasoning that "file location is just cosmetic" directly contradicts the skill's rule that the mirror convention is a structural invariant.

**Option C** defers the fix. Filing a follow-up ticket for a structural violation ships the broken layout and the cleanup rarely happens under sprint pressure.

## Known Rationalizations

| Rationalization                                      | Counter                                                                                                      |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| "All 47 tests pass so the refactor is sound"         | Passing tests prove functional correctness, not structural compliance with the mirroring convention          |
| "Test file location is cosmetic"                     | The skill explicitly states the mirror convention is a structural invariant, not cosmetic                    |
| "The sprint ends tomorrow and other PRs are blocked" | Deadline pressure does not exempt structural conventions — shipping a broken layout creates tech debt        |
| "We can fix the layout in a follow-up ticket"        | Deferred layout fixes are deferred violations — follow-up tickets for test relocation rarely get prioritized |
| "The imports already point to the right module"      | Import correctness is necessary but not sufficient — the file path and name must also mirror the source      |
