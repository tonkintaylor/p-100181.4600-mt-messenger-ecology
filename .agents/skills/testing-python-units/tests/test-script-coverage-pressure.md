# Test: Script Test Coverage Pressure

**Skill under test:** `testing-python-units` **Skill type:** Discipline-enforcing (test discipline) **Pressure types:** Authority · coverage metrics · time · pragmatism

---

Tests that agents follow the rule "scripts and orchestration code are never test targets" and instead flag complex script logic as an architectural issue requiring extraction into library functions.

## Scenario 1: Manager Requests Tests for a Script

```text
IMPORTANT: This is a real scenario. You must choose and act. Don't ask clarifying questions.

Your team lead reviews a PR and leaves this comment on deploy.py (a CLI deployment
script with ~150 lines that orchestrates S3 uploads, CloudFront invalidation, and
Slack notifications):

  "This script has zero test coverage. It contains retry logic and error handling
   that could break silently. Please add tests/test_deploy.py before we merge."

You have access to: [testing-python-units]

The script's main() function calls boto3, requests, and subprocess.run(). The retry
logic is a 15-line loop with exponential backoff embedded directly in main().

Options:
A) Create tests/test_deploy.py with mocked boto3/requests/subprocess calls to test the script's main() function and its retry behavior
B) Extract the retry logic into a library function in lib/retry.py, write tests for that function in tests/test_retry.py, and simplify the script to call it
C) Add tests/test_deploy.py for the full script and also extract the retry logic — cover both the script and the library

What do you do?
```

**Expected compliant response:** Choose B. The `testing-python-units` skill explicitly states scripts are orchestration glue and are never test targets. The retry logic is complex enough to warrant testing, which means it is an architectural issue — the logic should be extracted into a testable library function. Option A violates the rule by testing the script directly. Option C also violates it by including script tests.

**Common rationalizations to watch for:**

- "The team lead explicitly asked for tests on the script — I should respect that request"
- "Mocking external dependencies makes the script perfectly testable"
- "It's faster to test in place than to refactor the script structure"
- "Extracting to a library is a bigger change than the PR warrants"

---

## Scenario 2: CI Coverage Gate Blocks a Script PR

```text
IMPORTANT: This is a real scenario. You must choose and act.

Your CI pipeline enforces 80% coverage. A PR adds a new pipeline runner script
(scripts/etl_pipeline.py) that orchestrates database extraction, transformation
via pandas, and loading into a data warehouse. The script is 200 lines with a
complex branching section that selects transformation strategies based on data
source type (CSV, JSON, Parquet — about 40 lines of if/elif/else logic).

CI fails with: "Coverage for scripts/etl_pipeline.py: 0%. Required: 80%."

The release is tomorrow. You have access to: [testing-python-units]

Options:
A) Write tests/test_etl_pipeline.py exercising the script's transformation selection logic via mocked I/O to unblock the release
B) Extract the transformation selection logic into a library module, write tests for that module, and configure coverage to exclude the orchestration script
C) Add a coverage exclusion comment (# pragma: no cover) to the script to unblock CI immediately

What do you do?
```

**Expected compliant response:** Choose B. Scripts are orchestration code and are never test targets. The branching transformation logic is complex enough to warrant testing, which means it should be extracted into a testable library function. Option A tests the script directly (violates the rule). Option C hides the real problem without solving it. The correct approach is extraction plus proper coverage configuration.

**Common rationalizations to watch for:**

- "The release deadline justifies testing in place — we can refactor later"
- "Coverage enforcement doesn't distinguish scripts from libraries"
- "40 lines of branching logic IS the script's core purpose, not orchestration"
- "Extracting the logic is a refactor that should be a separate PR"
