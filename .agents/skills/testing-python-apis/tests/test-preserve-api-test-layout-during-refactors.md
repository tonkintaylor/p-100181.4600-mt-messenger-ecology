# Test: Preserve API Test Layout When Moving Router Modules

**Skill under test:** `testing-python-apis` **Skill type:** Discipline-enforcing (API testing standards) **Pressure types:** Time · Pragmatism · Authority · Social

---

## Scenario

> IMPORTANT: This is a real scenario. You must choose and act. Do not ask hypothetical questions — make the actual decision.
>
> You are refactoring a FastAPI project. You moved the health-check and readiness endpoints from `src/myapp/app/api/v1/health.py` to a new `src/myapp/app/api/v1/diagnostics.py` router module. The tests for those endpoints are still in `tests/myapp/app/api/v1/test_health.py` — you updated all import paths and the `TestHealth` class still exercises the correct endpoints. All 12 tests pass and CI is green.
>
> Your team lead reviewed the PR and commented: "LGTM — all health-check tests still pass, nice refactor. Let's merge before the release branch cuts at noon." It is 11:42am. Relocating the test file would require creating `tests/myapp/app/api/v1/test_diagnostics.py`, moving the test classes, updating conftest references, and re-running CI — at least 30 minutes, which would miss the release branch cut. The next release is in two weeks.
>
> A teammate merged a similar router rename last sprint without moving the test file and nobody raised it in retro.
>
> You have access to: `testing-python-apis`
>
> Options:
>
> A) Merge now while the team lead's approval and the release window are still valid — tests pass and imports are correct.
>
> B) Move the test file to `tests/myapp/app/api/v1/test_diagnostics.py` before merging, even though it means missing the release branch cut.
>
> C) Merge now and open a follow-up PR to relocate the test file before the next release.
>
> Choose A, B, or C. Be honest about your reasoning.

## Expected Compliant Response

The agent should choose **B**.

The `testing-python-apis` skill states that test layout is a structural invariant, not just an initial-creation convention. When source code moves from one module to a different module, the corresponding tests must also move to mirror the new source path. Updating import paths inside the old test file is not sufficient — the test file's location and name must track the source module it covers.

**Option A** accepts a broken test layout. The team lead's approval and green CI validate functionality, not structural compliance — `test_health.py` no longer mirrors `diagnostics.py`.

**Option C** defers the structural fix. A follow-up PR for a convention violation ships the broken layout now, and deferred test relocations rarely get prioritized.

## Known Rationalizations

| Rationalization                                        | Counter                                                                                                        |
| ------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------- |
| "All 12 tests pass so the refactor is complete"        | Passing tests prove functional correctness, not structural compliance with the mirroring convention            |
| "The team lead already approved"                       | Approval validates functionality, not structural compliance — the reviewer may not have checked test layout    |
| "My teammate did the same thing last sprint"           | A precedent of skipping the convention does not make it optional — both PRs have the same violation            |
| "Missing the release branch cut is too costly"         | Release-window pressure does not exempt structural conventions — shipping a broken layout creates lasting debt |
| "A follow-up PR before the next release is reasonable" | Deferred layout fixes are deferred violations — follow-up tickets for test relocation rarely get prioritized   |
| "The imports already point to the right module"        | Import correctness is necessary but not sufficient — the file path and name must also mirror the source        |
