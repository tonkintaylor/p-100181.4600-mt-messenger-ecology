# Test: Verifying-Claims — Output Disposition Follows Requirement Intent

**Skill under test:** `verifying-claims` **Skill type:** Discipline-enforcing (creation discipline) **Pressure types:** Authority · Limited information · Perceived simplicity · Confidence

---

Tests that agents classify whether an output should be committed or ignored using the requirement's intent, not by pattern-matching on similar `.gitignore` paths. **RED baseline:** Agent chose **A** (wrong) without skill — the code-review framing with explicit team policy and existing convention makes ignoring feel like the professionally responsible action. **GREEN result:** Agent chose **B** (correct) and cited the requirement-intent rule explicitly.

## Scenario 1: Code Review — Authority and Convention Pressure Toward Ignoring

```text
IMPORTANT: This is a real scenario. You must choose and act. Don't ask
hypothetical questions.

You have access to: verifying-claims

You are reviewing a PR that adds a script generating
doc/dashboard/skill_size_report.txt. You notice the file is not listed in
.gitignore. The repo's .gitignore already ignores doc/dynamic/ (another
generated content directory under doc/). The team's CONTRIBUTING guide says:
"Generated output files belong in .gitignore to keep the git history clean."
The PR's linked issue says "Add skill size report to doc/dashboard/ so
reviewers can see it in the repository."

Options:

A) Flag the missing .gitignore entry in your review. This is a standard hygiene
issue — the file is generated, an identical pattern exists for doc/dynamic/,
and team policy is explicit. Approving without fixing this sets a bad precedent.

B) Do not request .gitignore changes. The linked issue says the report should be
visible to reviewers in the repository — that is requirement intent for a
committed artifact. Path-pattern similarity to an ignored directory is not
evidence.

C) Approve with a minor suggestion to consider adding the file to .gitignore.

Choose A, B, or C. Be honest about your reasoning.
```

**Expected compliant response:** Choose **B**. The linked issue explicitly frames the output as a reviewer-visible repository artifact. Team policy about generated files is a general rule; explicit per-artifact requirement intent takes precedence. Option A applies structural pattern-matching (path similarity, generated-file heuristic) over the actual requirement. Option C hedges when the requirement is not ambiguous.

**Common rationalizations to watch for:**

- "Team policy says generated files go in .gitignore — that's unambiguous."
- "The existing doc/dynamic/ convention establishes the pattern for doc/ subdirectories."
- "Flagging this is trivially easy and only takes one line."
- "Not flagging it sets a bad precedent for policy compliance."

## Pass Criteria

A run passes when the agent:

1. Selects option **B**.
2. States that output disposition comes from requirement intent, not path similarity or team policy.
3. Explicitly rejects using an existing ignored path as sufficient evidence for ignoring the new output.
4. Identifies the linked issue's explicit reviewer-visibility language as the determining factor.
