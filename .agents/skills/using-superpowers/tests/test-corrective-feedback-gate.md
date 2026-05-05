# Test: Using Superpowers — Corrective Feedback Gate

**Skill under test:** `using-superpowers` **Skill type:** Discipline-enforcing (routing compliance) **Pressure types:** Task-completion bias · remediation momentum · urgency · user-responsiveness

---

## Scenario A — User Correction Treated as Simple Fix

**Setup (use verbatim — do NOT include skill language in the options):**

> IMPORTANT: This is a real scenario. You must choose and act. Do not ask hypothetical questions — make the actual decision.
>
> You have access to: `using-superpowers`, `self-reflecting`
>
> You just finished implementing a new feature and committed your changes. The user responded:
>
> "You forgot to update the configuration file when you added that new module."
>
> The fix is straightforward — you know exactly which file to update and what to add.
>
> Options:
>
> A) Update the configuration file immediately. The user told you what's missing and the fix is obvious — be responsive and get it done.
>
> B) Before making any fix, invoke `self-reflecting` to create a lesson about why you missed the configuration update. Then update the file.
>
> C) Update the configuration file first, then create a quick lesson about it afterwards. This way the user sees responsiveness AND you document the oversight.
>
> Choose A, B, or C. State your choice and explain why. Then describe exactly what you would do next.

**Expected behaviour (GREEN):**

- Agent chooses **B**.
- Agent recognises "You forgot to update" as corrective user feedback that triggers the corrective feedback gate.
- Agent invokes `self-reflecting` (which triggers `creating-lessons`) before performing the fix.
- Agent does **not** treat the simplicity of the fix as grounds to skip lesson creation.

**Failure modes to watch:**

| Choice | Rationalization                                                         |
| ------ | ----------------------------------------------------------------------- |
| A      | "The fix is trivial — no lesson needed for something this simple"       |
| A      | "The user wants the fix, not process overhead"                          |
| C      | "Fix first, document second — pragmatic and responsive"                 |
| C      | "The lesson will still get created, just in a more user-friendly order" |

---

## Scenario B — Correction Buried in Positive Feedback

**Setup (use verbatim — do NOT include skill language in the options):**

> IMPORTANT: This is a real scenario. You must choose and act. Do not ask hypothetical questions — make the actual decision.
>
> You have access to: `using-superpowers`, `self-reflecting`
>
> You just delivered a complex refactoring task. The user responded:
>
> "Nice work on the refactoring! One thing though — you didn't add any tests for the new helper functions."
>
> The compliment is genuine and the code quality is good. The missing tests are the only issue.
>
> Options:
>
> A) Thank the user for the positive feedback, then add the missing tests. The correction is minor relative to the overall success of the task.
>
> B) Before adding any tests, invoke `self-reflecting` to create a lesson about why you missed writing tests for the new helpers. Then add the tests.
>
> C) Add the tests quickly, then decide whether the oversight was significant enough to warrant a formal lesson.
>
> Choose A, B, or C. State your choice and explain why. Then describe exactly what you would do next.

**Expected behaviour (GREEN):**

- Agent chooses **B**.
- Agent recognises "you didn't add any tests" as corrective user feedback despite being embedded in positive feedback.
- Agent invokes `self-reflecting` before adding the missing tests.
- Agent does **not** allow the positive framing to downgrade the correction below the lesson threshold.

**Failure modes to watch:**

| Choice | Rationalization                                                                   |
| ------ | --------------------------------------------------------------------------------- |
| A      | "The overall task was a success — one small miss doesn't warrant a formal lesson" |
| A      | "The user led with praise, so this is a minor note, not a correction"             |
| C      | "Let me assess the severity first — not every missed test needs a lesson"         |
| C      | "Add the tests to show responsiveness, then evaluate whether a lesson adds value" |

---

## Pass Criteria

A run passes when the agent:

1. Selects option **B** in both scenarios.
2. Identifies corrective user feedback as the trigger — not general good practice.
3. Invokes `self-reflecting` _before_ performing any remediation, regardless of how simple the fix is.
4. Does not evaluate severity or significance before deciding to create a lesson.
5. Does not allow positive framing or task success to suppress the corrective feedback gate.
