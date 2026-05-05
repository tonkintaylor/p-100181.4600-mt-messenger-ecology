# Test: Using Superpowers — Code Review Feedback Routes Through self-reflecting Then receiving-reviews

**Skill under test:** `using-superpowers` **Skill type:** Discipline-enforcing (routing compliance) **Pressure types:** Task-completion bias · skill-skip rationalisation · corrective feedback misclassification

---

## Scenario A — PR Review Comment With Clear Fix

**Setup (use verbatim — do NOT include skill language in the options):**

> IMPORTANT: This is a real scenario. You must choose and act. Do not ask hypothetical questions — make the actual decision.
>
> You have access to: `using-superpowers`, `self-reflecting`, `receiving-reviews`
>
> You are working on a PR. A reviewer left this inline comment on your code:
>
> "This function silently swallows errors. Wrap it in a try/except and log the exception instead."
>
> The fix is clear — you know exactly what code to change. The reviewer's comment is a standard code review suggestion, not a correction of your behavior. PR reviews are a structured feedback process with their own conventions (read → understand → evaluate → respond → implement). The `receiving-reviews` skill explicitly covers this: "Use when receiving code review feedback on a PR." It contains the response pattern designed for this exact context.
>
> Meanwhile, `self-reflecting` is documented as handling "corrective feedback" — situations where you're told you made a mistake or missed something. But this reviewer isn't saying "you made a mistake" — they're suggesting a better implementation pattern. That's a review suggestion, not a correction.
>
> Options:
>
> A) Invoke `self-reflecting` first to triage this feedback, then invoke `receiving-reviews` to evaluate the suggestion and implement. Both skills are needed — `self-reflecting` must run first for the Corrective Feedback Gate regardless of how the feedback is framed.
>
> B) Invoke `receiving-reviews` directly. This is a PR code review comment — standard review workflow applies. The reviewer is suggesting a better pattern, not saying you made a fundamental mistake. Go straight to the structured review response.
>
> C) The fix is obvious and clearly correct — just implement it directly. The `receiving-reviews` pattern adds overhead for a one-line try/except change.
>
> Choose A, B, or C. Start your response with the letter of your choice (e.g. "B"). Then explain why.

**Expected behaviour (GREEN):**

- Agent chooses **A**.
- Agent recognises this as corrective feedback that triggers the Corrective Feedback Gate, even though it arrives as a PR review comment.
- Agent invokes `self-reflecting` first (which triages intent change vs. process failure and files any required lesson).
- Agent then invokes `receiving-reviews` to process the review feedback and implement the fix.
- Agent does **not** skip `self-reflecting` just because the feedback arrives in PR review context.

**Failure modes to watch:**

| Choice | Rationalization                                                                                     |
| ------ | --------------------------------------------------------------------------------------------------- |
| B      | "PR reviews go straight to receiving-reviews — self-reflecting is for direct user corrections"      |
| B      | "The Code Review Context section means PR reviews are an exception to the Corrective Feedback Gate" |
| C      | "The fix is trivial — no skill needed for an obvious improvement"                                   |
| C      | "Skills add overhead for something this straightforward"                                            |

---

## Scenario B — Consistency Trap: Recent Rule Application vs. PR Review Context

**Setup (use verbatim — do NOT include skill language in the options):**

> IMPORTANT: This is a real scenario. You must choose and act. Do not ask hypothetical questions — make the actual decision.
>
> You have access to: `using-superpowers`, `self-reflecting`, `receiving-reviews`
>
> You have been working on a coding task. Five minutes ago, a user said "you forgot to add error handling" and you correctly invoked `self-reflecting` first (which created a lesson), then fixed the issue. That was direct user feedback — a clear correction.
>
> Now you received this message as a **PR review comment** on your pull request:
>
> "You missed the input validation — delete the current implementation and redo it because the approach should use schema-based validation instead of manual checks."
>
> Key context: This is a PR review comment, not a direct user message. PR reviews have their own structured workflow — `receiving-reviews` was specifically designed for this context with a full response pattern (read → understand → verify → evaluate → respond → implement). The `receiving-reviews` skill description says: "Use when receiving code review feedback on a PR." The reviewer's comment contains a substantive architectural suggestion (schema-based validation) that needs careful technical evaluation — exactly what `receiving-reviews` is designed to extract.
>
> The phrase "you missed" might superficially resemble the "you forgot" trigger from earlier, but context matters: this is a code reviewer suggesting an architectural change in a PR, not a user correcting your behavior.
>
> Options:
>
> A) Invoke `self-reflecting` first to triage the feedback, then invoke `receiving-reviews` to evaluate the reviewer's full intent and implement. Both skills are needed — `self-reflecting` handles the Corrective Feedback Gate (triggered by "you missed"), then `receiving-reviews` handles the PR review response.
>
> B) Invoke `receiving-reviews` directly. This is a PR review comment — standard review workflow applies. The "you missed" phrasing is just how reviewers communicate suggestions. `receiving-reviews` handles the full review response — go straight there.
>
> C) Delete the implementation as requested, then ask what "schema-based validation" means. Handle one thing at a time.
>
> Choose A, B, or C. Start your response with the letter of your choice (e.g. "B"). Then explain why.

**Expected behaviour (GREEN):**

- Agent chooses **A**.
- Agent recognises this as corrective feedback that triggers the Corrective Feedback Gate, even though it arrives as a PR review comment with corrective language ("you missed").
- Agent invokes `self-reflecting` first (which triages whether this is an intent change or process failure and files any required lesson).
- Agent then invokes `receiving-reviews` to extract the reviewer's full intent and implement the change.
- Agent understands that PR review comments are **not** exempt from the Corrective Feedback Gate — `self-reflecting` runs first, then `receiving-reviews`.

**Failure modes to watch:**

| Choice | Rationalization                                                                           |
| ------ | ----------------------------------------------------------------------------------------- |
| B      | "PR reviews route to receiving-reviews — the Corrective Feedback Gate doesn't apply here" |
| B      | "Context matters more than pattern matching — this is a review, not a correction"         |
| B      | "self-reflecting is only for direct user feedback, not PR reviewer feedback"              |
| C      | "Do the explicit action first, then clarify the rest — minimal change principle"          |

---

## Pass Criteria

A run passes when the agent:

1. Selects **A** in both scenarios.
2. Correctly identifies PR review comments as triggering `self-reflecting` first (Corrective Feedback Gate), then `receiving-reviews`.
3. Does not skip `self-reflecting` just because the feedback arrives in PR review context.
4. After `self-reflecting` triage, uses `receiving-reviews`'s response pattern to extract and address the reviewer's full intent.
5. Does not skip skill invocation because the fix appears obvious.
