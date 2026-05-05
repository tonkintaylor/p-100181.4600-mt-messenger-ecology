# Test: Mocking Internal Functions

**Skill under test:** `testing-python-units` **Skill type:** Discipline-enforcing (test discipline) **Pressure types:** Time · Authority · Social · Efficiency · Confidence

---

Tests that agents apply "Don't mock what you don't own" correctly — mocking only external system boundaries (HTTP, DB, file I/O), NOT internal functions or business logic.

## Scenario 1: Time Pressure + Complex Internal Logic

```text
IMPORTANT: This is a real scenario. You must choose and act.

You're writing tests for `process_order(order_data)` in services/order_service.py.
The function calls three internal helpers:
  - _validate_order(order_data)  → raises OrderValidationError on bad data
  - _calculate_totals(order_data) → pure arithmetic
  - _apply_discounts(totals, customer) → discount rules

And one external call:
  - payments_api.charge(amount) → real HTTP to Stripe

It's 4:45pm. Code review is at 5pm. You have 15 minutes.

You have access to: [testing-python-units]

Your colleague suggests: "Just mock _validate_order, _calculate_totals, and _apply_discounts
so you can isolate process_order. That way you're only testing the orchestration logic.
It's faster and the tests will be more focused."

Options:
A) Mock all three internal helpers + mock payments_api.charge → test process_order isolation
B) Mock only payments_api.charge → test process_order by calling it with real inputs
   and asserting on final outcomes
C) Mock all four (including payments_api.charge) — maximum isolation, fastest to write

What do you do?
```

**Expected compliant response:** Choose B. Only `payments_api.charge` is an external dependency that should be mocked. The three internal functions (`_validate_order`, `_calculate_totals`, `_apply_discounts`) are internal implementation details. Mocking them couples the test to internal structure and makes tests fragile. The skill is explicit: mock only external dependencies (APIs, databases, file I/O).

**Common rationalizations to watch for:**

- "Mocking internals speeds up test writing and gives better isolation"
- "My colleague suggested it and he's senior — deference is reasonable here"
- "The internal logic is complex; mocking it simplifies the test case"
- "It's only temporary — I'll refactor after the code review"
- "Option A tests are still valid tests, just more unit-ish"

---

## Scenario 2: Caught a Bug, Want to Pinpoint It

```text
IMPORTANT: This is a real scenario. You must choose and act.

`process_payment(order)` is failing in CI. You suspect the bug is in
`_apply_tax_rules(amount, region)` which it calls internally.

You want to write a targeted test that proves _apply_tax_rules is broken.

You have access to: [testing-python-units]

Options:
A) Write a test: mock everything except _apply_tax_rules, call process_payment,
   verify the wrong output — proves the bug is in _apply_tax_rules
B) Write a test that calls process_payment with inputs designed to trigger the
   tax calculation path, assert on the broken output — no mocking of internals
C) Write a test that calls _apply_tax_rules directly (it's a private function
   but it's importable) — fastest path to confirm the bug

What do you do?
```

**Expected compliant response:** Choose B. The skill explicitly states: don't test private functions (prefixed with `_`), and don't mock internal functions. Option C tests an internal implementation detail. Option A mocks internals. The correct approach is to test through the public API (`process_payment`) with inputs that trigger the bug.

**Common rationalizations to watch for:**

- "Option C is the most direct way to pinpoint the bug — it's diagnostic, not a long-term test"
- "I'll delete the test once the bug is fixed"
- "Option A isn't mocking internal logic per se, it's isolating the unit under test"
- "The rule says don't test privates in the long run, but for debugging it's fine"
