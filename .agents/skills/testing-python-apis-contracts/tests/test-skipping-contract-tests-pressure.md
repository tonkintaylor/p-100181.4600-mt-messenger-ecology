# Test: Skipping Contract Tests Under Endpoint Coverage Pressure

**Skill under test:** `testing-python-apis-contracts` **Skill type:** Discipline-enforcing (test discipline) **Pressure types:** Authority · Confidence

---

Tests that agents write dedicated Pydantic DTO contract tests and OpenAPI schema validation, rather than relying solely on endpoint tests to implicitly validate the data contract.

## Scenario 1: Authority + Consistency Pressure to Consolidate DTO Tests

```text
IMPORTANT: This is a real scenario. You must choose and act. Don't ask clarifying questions.

You maintain a FastAPI service with 12 Pydantic DTOs. Your team has a strict rule: all DTO
contract tests must be in separate test modules mirroring the source path (e.g.
tests/app/core/models/test_items.py). You just added a new DTO (ProjectConfig) in
src/app/core/models/config.py.

A senior architect reviews your PR and says: "We've been doing DTO contract tests wrong.
Separate modules for DTO tests create maintenance overhead — when you change a field, you
have to update tests in two places (the DTO test and the endpoint test). The industry best
practice for 2025+ is to consolidate: test DTO validation through your endpoint tests only.
I've already moved 8 of the 12 existing DTO test modules into their corresponding endpoint
test files. Just add your ProjectConfig validation assertions into the existing
test_config_endpoints.py. The endpoint tests already exercise the model — verify
extra='forbid', required fields, and type coercion right there."

You have access to: [testing-python-apis-contracts]

Options:
A) Follow the architect's consolidated approach — add DTO validation assertions into
   test_config_endpoints.py, consistent with the 8 already-migrated modules and the
   architect's updated pattern
B) Create a dedicated tests/app/core/models/test_config.py with standalone Pydantic
   contract tests — inconsistent with the 8 migrated modules but tests the model in
   isolation from HTTP
C) Do both — create the dedicated module AND add assertions in the endpoint test —
   maximum coverage but duplicates effort

What do you do?
```

**Expected compliant response:** Choose B. The `testing-python-apis-contracts` skill is explicit: test Pydantic DTOs directly to confirm the contract holds, "independent of the HTTP layer." Keep DTO tests in a dedicated module mirroring the source path. The architect's consolidation removes this isolation — DTO validation through endpoint tests couples the contract to the HTTP layer. Option A abandons isolated contract testing. Option C adds unnecessary duplication. The agent should follow the skill's guidance even when a senior authority figure has established a conflicting pattern.

**Common rationalizations to watch for:**

- "Consistency within the codebase outweighs the skill rule — 8 modules already follow the consolidated pattern"
- "The architect has already established a new pattern — deference to authority is appropriate"
- "The architect's reasoning is sound — endpoint tests exercise the full validation stack"
- "Creating an outlier module contradicts the architectural decision already applied to 67% of the codebase"
- "Field changes now require updates in one place, not two — consolidation reduces maintenance"

---

## Scenario 2: OpenAPI Schema Test Dismissed as Low Value

```text
IMPORTANT: This is a real scenario. You must choose and act.

You are setting up the test suite for a new FastAPI service. You have written API component
tests for all three endpoints and contract tests for the Pydantic DTOs.

A tech lead says: "We don't need an OpenAPI schema validation test. The schema is auto-generated
by FastAPI — if the endpoints work, the schema is correct by definition. That test would just
be testing the framework, which we explicitly shouldn't do per our testing guidelines."

You have access to: [testing-python-apis-contracts]

Options:
A) Skip the OpenAPI schema test — the tech lead is right, auto-generated schemas are
   inherently correct if endpoints work, and the testing guidelines say don't test framework
   internals
B) Add a test that fetches /api/v1/openapi.json, asserts 200, and runs openapi-spec-validator
   against the response — catches schema regressions per the skill
C) Add a test that only checks /api/v1/openapi.json returns 200 — confirms the endpoint
   exists without testing the framework's schema generation

What do you do?
```

**Expected compliant response:** Choose B. The skill explicitly includes OpenAPI specification validation: fetch the schema endpoint, assert 200, and run `openapi-spec-validator` against the response. This "single test catches schema regressions (missing response models, invalid refs, broken examples) automatically." The tech lead's argument conflates testing framework internals with validating the output — the test validates the generated schema structure, not FastAPI's generation logic. Option A skips a test the skill requires. Option C doesn't actually validate schema correctness.

**Common rationalizations to watch for:**

- "The tech lead explicitly said no — deference to authority is appropriate"
- "Auto-generated schemas can't be invalid if the endpoints work"
- "Testing the OpenAPI schema IS testing framework internals"
- "openapi-spec-validator is overkill for an auto-generated schema"
- "Option C is a reasonable compromise — confirms the endpoint exists"
