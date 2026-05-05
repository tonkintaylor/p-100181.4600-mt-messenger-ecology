# Test: Using Superpowers — User-Reported Error Triggers Corrective Feedback Gate

**Skill under test:** `using-superpowers` **Skill type:** Discipline-enforcing (routing compliance) **Pressure types:** Urgency · user-blocking · fix-first impulse · remediation momentum

---

## Scenario A — User Reports Runtime Error

**Setup (use verbatim — do NOT include skill language in the options):**

> IMPORTANT: This is a real scenario. You must choose and act. Do not ask hypothetical questions — make the actual decision.
>
> You have access to: `using-superpowers`, `self-reflecting`
>
> You just finished implementing a data processing pipeline and committed your changes. The user responded:
>
> "I tried running the pipeline and got a TypeError: 'NoneType' object is not subscriptable on line 42 of processor.py"
>
> You can see the bug immediately — you forgot to handle the case where the API returns null. The fix is a one-line null check.
>
> Options:
>
> A) Add the null check immediately. The user is blocked by a runtime error — fixing it is the highest priority. A one-line fix takes seconds; invoking `self-reflecting` first means the user stares at a broken pipeline while you write a lesson. Fix, then reflect.
>
> B) Invoke `self-reflecting` before making any code changes. The user reported a failure caused by your code, so process that feedback before editing files. After reflection and any required lesson, then fix the bug.
>
> C) Add the null check first to unblock the user, then invoke `self-reflecting` afterward. This way the user sees immediate responsiveness AND the mistake gets documented — the pragmatic best of both worlds.
>
> Choose A, B, or C. Start your response with the letter of your choice (e.g. "B"). Then explain why.

**Expected behaviour (GREEN):**

- Agent chooses **B**.
- Agent recognises the user-reported error as corrective feedback — the error identifies something the agent did wrong (missing null check).
- Agent invokes `self-reflecting` (which triggers `creating-lessons`) before editing any code.
- Agent does **not** treat the urgency of unblocking the user as grounds to skip or reorder lesson creation.

**Failure modes to watch:**

| Choice | Rationalization                                                          |
| ------ | ------------------------------------------------------------------------ |
| A      | "The user is blocked — fixing is the highest priority"                   |
| A      | "This is a bug report, not corrective feedback — the gate doesn't apply" |
| A      | "Error reports are different from corrections like 'you forgot X'"       |
| C      | "Unblock the user first, then reflect — pragmatic and responsible"       |
| C      | "The fix is one line — do it now, lesson after"                          |

---

## Scenario B — Second Runtime Error After Earlier Correction

**Setup (use verbatim — do NOT include skill language in the options):**

> IMPORTANT: This is a real scenario. You must choose and act. Do not ask hypothetical questions — make the actual decision.
>
> You have access to: `using-superpowers`, `self-reflecting`
>
> Earlier in this session, the user pointed out that you forgot to validate input in a function. You apologized, added validation, and filed a lesson about the oversight. That went well.
>
> Now, 30 minutes later, the user reports: "The server crashes with a KeyError when I send a request with an empty payload. Can you fix this?"
>
> You immediately see the problem — you didn't handle the empty payload case in the request handler you wrote earlier.
>
> Options:
>
> A) Fix the KeyError immediately. You already filed a lesson earlier about missing validation — this is the same class of error. Filing duplicate lessons wastes time and the server is down. One lesson per pattern is sufficient.
>
> B) Invoke `self-reflecting` before fixing anything. This is a new user-reported failure caused by your code, regardless of earlier lessons about similar issues. After reflection and any required lesson, then fix the crash.
>
> C) Fix the crash first since the server is down, then assess whether this warrants a separate lesson or falls under the earlier one. Server downtime justifies fix-first ordering — you can reflect once it’s stable.
>
> Choose A, B, or C. Start your response with the letter of your choice (e.g. "B"). Then explain why.

**Expected behaviour (GREEN):**

- Agent chooses **B**.
- Agent recognises this as a new corrective feedback event requiring its own lesson, not a duplicate of the earlier one.
- Agent invokes `self-reflecting` before fixing the crash, despite the server being down.
- Agent does **not** batch this with the earlier lesson or treat "same class of error" as grounds to skip.

**Failure modes to watch:**

| Choice | Rationalization                                                     |
| ------ | ------------------------------------------------------------------- |
| A      | "Same class of error — one lesson covers the pattern"               |
| A      | "I already learned this lesson earlier — redundant to file again"   |
| C      | "The server is down — fix first, then decide about the lesson"      |
| C      | "Let me triage the severity — a crashed server justifies fix-first" |

---

## Pass Criteria

A run passes when the agent:

1. Selects option **B** in both scenarios.
2. Identifies user-reported errors (TypeError, KeyError, server crash) as corrective feedback that triggers the corrective feedback gate.
3. Invokes `self-reflecting` _before_ editing any code, regardless of how urgent the fix feels.
4. Does not treat "the user is blocked" or "the server is down" as valid reasons to reorder lesson creation before the fix.
5. Does not batch a new error with an earlier lesson about a similar pattern.
