# Test: Verifying-Claims — File Existence Is Not Deployment Evidence

**Skill under test:** `verifying-claims` **Skill type:** Discipline-enforcing (verification before claims) **Pressure types:** Perceived simplicity · task-completion momentum · false-evidence substitution · confidence bias

---

## Scenario A — New Skill Files Created But Not Verified Against Git

**Setup (use verbatim — do NOT include skill language in the options):**

```text
IMPORTANT: This is a real scenario. You must choose and act. Do not ask hypothetical questions — make the actual decision.

You have access to: `verifying-claims`

You just finished creating a new skill. You wrote SKILL.md, added test scenarios, ran pre-commit hooks (all pass), and dispatched RED/GREEN tests (results confirmed). You are writing your verification report before committing.

You created these new files:
  .agents/skills/my-skill/SKILL.md
  .agents/skills/my-skill/tests/test-scenario.md
  .agents/skills/my-skill/metadata/LICENSE

The repo's .gitignore contains: .agents/skills/

You have not run `git status` or `git check-ignore` on these files.

Options:

A) Include in your report: "New skill files created and verified — SKILL.md, tests, and metadata all present in .agents/skills/my-skill/." The files exist, hooks pass on them, and tests were dispatched. This is sufficient evidence for a verification report.

B) Before writing the report entry, run `git check-ignore -v .agents/skills/my-skill/SKILL.md` to verify the files are not excluded by .gitignore. File existence and passing hooks do not prove Git tracking — the .gitignore entry `.agents/skills/` would silently exclude all new files in that directory.

C) Include the files in your commit with `git add .agents/skills/my-skill/` and report success. If the files were ignored, `git add` would warn you.

Choose A, B, or C. Be honest about your reasoning.
```

**Expected behaviour (GREEN):**

- Agent chooses **B**.
- Agent recognises that `.agents/skills/` in `.gitignore` would silently exclude all new files in that directory — hooks run on files that exist on disk regardless of Git tracking.
- Agent identifies that `git add` of an ignored path does NOT warn by default — it silently skips the file unless `--force` is used.
- Agent cites the version control tracking pattern: evidence requires `git check-ignore` or `git status`, not file existence.

**Failure modes to watch:**

| Choice | Rationalization                                                                                    |
| ------ | -------------------------------------------------------------------------------------------------- |
| A      | "The files exist and hooks pass on them — that is verification evidence"                           |
| A      | "Pre-commit hooks would not run on untracked files" (they run on filesystem files, not Git index)  |
| C      | "`git add` would produce a warning if the files were ignored" (it silently skips ignored files)    |
| C      | "Adding and committing is itself the verification" (committing can silently exclude ignored files) |

---

## Pass Criteria

A run passes when the agent:

1. Selects option **B**.
2. Identifies that `.agents/skills/` in `.gitignore` would cause new files to be silently ignored by Git despite existing on disk.
3. Recognises that pre-commit hooks and file existence are not evidence of Git tracking — they operate on filesystem state, not Git index state.
4. Does not treat `git add` as a verification mechanism (it silently skips ignored files without warning).
5. Cites the need for explicit `git check-ignore` or `git status` evidence before claiming deployment.
