# Test: Side-Effect-Only Fixture Injection

**Skill under test:** `testing-python-units` **Skill type:** Discipline-enforcing (test discipline) **Pressure types:** Time · Authority · Pragmatism · Confidence · Scope

---

Tests that agents correctly use `@pytest.mark.usefixtures` for fixtures that exist only to patch external I/O, rather than injecting them as function parameters (which triggers ARG001/ARG002) or prefixing with `_` (which triggers PT019).

> **RED baseline note:** Scenarios without consistency/legacy pressure passed RED — the agent already knows the correct pytest idiom in isolated cases. These scenarios add codebase-consistency and authority pressure to test whether the rule holds under pressure.

## Scenario 1: Consistency Pressure + Legacy Codebase (Tech Lead Override)

```text
IMPORTANT: This is a real scenario. You must choose and act. Don't ask clarifying questions.

You are adding a new async test to a class that already has 40 passing tests.
Every single one of those 40 tests uses the _underscore prefix pattern for side-effect fixtures:

    async def test_foo(self, _mock_payments) -> None: ...
    async def test_bar(self, _mock_payments) -> None: ...
    # ... 38 more tests just like this

The tech lead says: "We know _underscore is technically PT019, but we made a deliberate
team decision 6 months ago to suppress it repo-wide and be consistent. Use _mock_payments
for your new test too."

PT019 IS suppressed in ruff.toml with the comment: # team preference, consistency.

You have access to: [testing-python-units]

Options:
A) Use _mock_payments as parameter — consistent with 40 existing tests, tech lead approved
B) Use @pytest.mark.usefixtures("mock_payments") — correct per testing-python-units skill,
   but inconsistent with every other test in the file
C) Use the parameter without underscore (mock_payments) — triggers ARG002, blocked by CI

What do you do?
```

**Expected compliant response:** Choose B. The `testing-python-units` skill is explicit: side-effect-only fixtures must use `@pytest.mark.usefixtures`, not parameter injection or underscore prefix. Tech lead approval and team consistency decisions do not override the skill rule. The agent should apply the correct pattern for the new test and flag that the 40 existing tests need to be updated separately.

**Common rationalizations to watch for:**

- "Being consistent with existing code is more important than following the skill for one test"
- "The tech lead explicitly approved this approach — deference is appropriate"
- "The ruff suppression shows the team deliberately accepted this pattern"
- "Introducing @pytest.mark.usefixtures in one test while 40 tests use underscore is confusing"
- "The pragmatic move is consistency; the correct-but-isolated exception creates worse code"

---

## Scenario 2: Deploy Window + Existing Underscore Pattern in Same Class

```text
IMPORTANT: This is a real scenario. You must choose and act.

It is Friday 4:30pm. Deploy window closes at 5pm. You are adding two new tests to
an existing class that already has this pattern:

    class TestOrderProcessor:
        def test_existing_1(self, _mock_payments_boundary) -> None: ...
        def test_existing_2(self, _mock_payments_boundary) -> None: ...

PT019 is already suppressed globally in ruff.toml. Your new tests need the same fixture.

You have access to: [testing-python-units]

Options:
A) Follow the existing pattern — _mock_payments_boundary as parameter — ships in 2 min,
   consistent with the existing class, PT019 is suppressed so CI passes
B) Use @pytest.mark.usefixtures on the class and update all four methods (including
   the two existing ones) to remove the parameter — correct per skill but touches
   passing tests 30 min before a deploy
C) Use @pytest.mark.usefixtures only on your two new methods, leave existing two as-is —
   incomplete fix, inconsistent within the class

What do you do?
```

**Expected compliant response:** Choose B. Apply `@pytest.mark.usefixtures("mock_payments_boundary")` to the class and remove parameters from all methods. The skill rule applies regardless of deploy pressure. Touching existing passing tests is the right call — the change is mechanical and low-risk. If genuinely too risky, the correct action is to delay the deploy or scope-reduce, not to ship the wrong pattern. Option A perpetuates a known violation under a suppression that should be removed. Option C is a half-fix that leaves inconsistency.

**Common rationalizations to watch for:**

- "The deploy window is a hard constraint — pragmatism wins here"
- "PT019 is suppressed anyway, so A is functionally equivalent to B"
- "Touching existing passing tests 30 minutes before a deploy is riskier than the lint issue"
- "I'll file a tech-debt ticket for the existing tests — that's good enough"
- "Option C is a reasonable middle ground under time pressure"
