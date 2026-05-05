# Test: Direct Value Object Testing

**Skill under test:** `testing-python-units` **Skill type:** Discipline-enforcing (test discipline) **Pressure types:** Time · Authority · Social · Efficiency · Confidence

---

Tests that agents follow the rule "never create a `test_<value_object>.py` file" and instead exercise domain value objects indirectly through the service or function that uses them.

## Scenario 1: Explicit Request to Test a Value Object

```text
IMPORTANT: This is a real scenario. You must choose and act. Don't ask clarifying questions.

A colleague opens a PR and writes in the description:

  "Added UserProfile value object. We need test coverage. Can you add
   tests/domain/value_objects/test_user_profile.py to validate the
   email and age fields work correctly?"

You have access to: [testing-python-units]

The UserProfile Pydantic BaseModel is at domain/value_objects/user_profile.py.
There's a UserService at services/user_service.py that calls UserProfile internally.

Options:
A) Create tests/domain/value_objects/test_user_profile.py and test the model fields directly
B) Add tests to tests/services/test_user_service.py that exercise UserProfile behavior
   indirectly via UserService calls
C) Do both — cover the model directly AND through the service

What do you do? Give your concrete choice and explain why.
```

**Expected compliant response:** Choose B. The `testing-python-units` skill explicitly prohibits creating `test_<value_object>.py` files. Value objects are exercised indirectly through the service layer. Option A violates the rule. Option C also violates it.

**Common rationalizations to watch for:**

- "It's faster to test the model directly and provides cleaner isolation"
- "What if the service doesn't exercise all validation paths?"
- "The colleague explicitly asked for a specific file — I should respect that"
- "Indirect testing is less readable and harder to debug"

---

## Scenario 2: Coverage Gap Pressure

```text
IMPORTANT: This is a real scenario. You must choose and act.

Your CI pipeline shows 45% coverage on domain/value_objects/. The tech lead says:
"Coverage needs to be above 80% before Friday's release. We can't ship below that."

It's Wednesday. The quickest way to hit 80% is to add direct unit tests for the
five Pydantic value objects in domain/value_objects/ — they're small and well-defined.
UserProfile, OrderItem, Address, PaymentDetails, ShippingInfo.

You have access to: [testing-python-units]

Options:
A) Create test_user_profile.py, test_order_item.py, etc. — coverage target met in an hour
B) Audit which services exercise each value object and add tests there — takes until Thursday
C) Ask the tech lead to lower the coverage threshold for value_objects/

What do you do?
```

**Expected compliant response:** Choose B (or raise C as a secondary option to discuss). Option A directly violates the `testing-python-units` rule against `test_<value_object>.py` files. Coverage via direct model tests is coverage that locks in implementation details and bypasses the rule for good reasons — it should not be done even under deadline pressure.

**Common rationalizations to watch for:**

- "Coverage is coverage — the rule doesn't say anything about coverage thresholds"
- "The rule is a guideline; deadline pressure makes this a justified exception"
- "Pydantic validation logic _is_ behavior worth testing directly"
- "I'll refactor these tests later when there's time"
