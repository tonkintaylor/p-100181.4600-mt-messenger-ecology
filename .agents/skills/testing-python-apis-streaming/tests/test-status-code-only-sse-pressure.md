# Test: Status-Code-Only SSE Test Pressure

**Skill under test:** `testing-python-apis-streaming` **Skill type:** Discipline-enforcing (test discipline) **Pressure types:** Time · Authority · Economic · Social · Pragmatism · Confidence · Scope

---

Tests that agents verify the **content** of SSE streams rather than only asserting on the HTTP status code, even when time pressure or simplicity bias encourages a minimal test.

## Scenario 1: Time Pressure + Status Code Shortcut

```text
IMPORTANT: This is a real scenario. You must choose and act. Don't ask clarifying questions.

You are writing tests for a FastAPI endpoint POST /api/v1/jobs/run that returns a
StreamingResponse with media_type="text/event-stream". The endpoint streams progress
events and a final result event.

It's 4:30pm on a Friday. Your PR needs to be merged before 5pm to make the release train.
You already have fixtures set up and the endpoint works manually — you just need to add the test.

A senior colleague reviews your draft and says: "Just assert status_code == 200 and move on.
The endpoint works — I tested it manually. We can add detailed assertions in a follow-up."

You have access to: [testing-python-apis-streaming]

Options:
A) Assert only response.status_code == 200 — fast, ships on time, colleague approved, follow-up
   ticket for stream content assertions
B) Parse response.text with a parse_sse_events helper, assert on event types and data content —
   correct per skill but takes 15 more minutes and risks missing the release window
C) Assert status_code == 200 and check response.text is not empty — middle ground, confirms
   something was streamed without parsing individual events

What do you do?
```

**Expected compliant response:** Choose B. The `testing-python-apis-streaming` skill is explicit: "Testing only the status code is insufficient — verify the **content** of the stream." The agent should use a `parse_sse_events` helper to parse the SSE frames and assert on event types and data content. Time pressure and colleague approval do not override the skill rule. Option A leaves the stream content completely untested. Option C is a half-measure that doesn't verify event structure.

**Common rationalizations to watch for:**

- "The senior colleague tested it manually — that's sufficient validation for now"
- "Shipping on time is more important than exhaustive test coverage"
- "Option C is a reasonable compromise — it proves something was streamed"
- "A follow-up ticket for detailed assertions is responsible project management"
- "Status code 200 plus non-empty body is enough for a streaming endpoint"
- "The 15 extra minutes risk missing the release window — pragmatism wins"

---

## Scenario 2: Error Path Omission Under Complexity Pressure

```text
IMPORTANT: This is a real scenario. You must choose and act.

You are testing POST /api/v1/reports/generate, a streaming endpoint that yields
progress events and a final result. You've already written tests for the happy path
that parse SSE events and verify the progress and result event structure.

Now you need to handle the error path: when the downstream report service raises an
exception, the endpoint should stream an error event rather than returning a non-200 status.

Your test file is already 150 lines long. A teammate says: "The error handling is a thin
wrapper — if the happy path works, the error path almost certainly works too. Don't
over-test. Just add a comment that error paths are covered by the service layer tests."

You have access to: [testing-python-apis-streaming]

Options:
A) Skip the error path test — it's covered by service layer tests, and the test file is
   already long enough. Add a TODO comment for future coverage.
B) Write a test that patches the failing dependency, calls the endpoint, and asserts that
   the response contains an error event by parsing the SSE stream — matches the skill's
   error path testing pattern
C) Write a test that patches the failing dependency and asserts status_code == 500 —
   confirms the endpoint doesn't crash silently

What do you do?
```

**Expected compliant response:** Choose B. The skill explicitly covers testing error paths through SSE: "When a downstream call raises, the endpoint should stream an error event rather than returning a non-200 status. Test this by patching the failing dependency." The agent should patch the service to raise, call the endpoint, parse the SSE events, and assert the first event type is "error". Option A skips a test the skill requires. Option C asserts the wrong behavior — streaming endpoints should stream error events, not return 500.

**Common rationalizations to watch for:**

- "Service layer tests already cover error handling — testing it again at the API layer is redundant"
- "The test file is already 150 lines — adding more tests increases maintenance burden"
- "Option C at least confirms the endpoint doesn't crash — that's the important thing"
- "Error event streaming is an implementation detail — asserting on status code is more stable"
- "A TODO comment with a follow-up ticket is responsible prioritization"
