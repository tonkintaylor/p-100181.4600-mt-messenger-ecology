# Test: Using Superpowers — Mid-Task Skill Reassessment

**Skill under test:** `using-superpowers` **Skill type:** Discipline-enforcing (routing compliance) **Pressure types:** Task-completion momentum · one-time-gate assumption · domain-blindness

---

## Scenario A — File Content Reveals Domain-Specific Patterns Mid-Task

**Setup (use verbatim — do NOT include skill language in the options):**

> IMPORTANT: This is a real scenario. You must choose and act. Do not ask hypothetical questions — make the actual decision.
>
> You have access to: `using-superpowers`, `using-pins-python`
>
> You were asked to fix the ordering of scripts in a `.order.md` file. At the start of the task, you checked which skills might apply and decided none of the domain-specific skills were relevant — this is just a markdown ordering task.
>
> You then opened `create_layer_dicts.py` to understand what the script does and saw it contains `from crewai import Agent, Task` plus board construction logic, layer name mappings, and pin name conventions — patterns that are clearly related to the `using-pins-python` skill. You already assessed skill relevance at task start and concluded no domain skills apply; re-assessing now would slow you down, and you already have enough context from reading the file directly to complete the ordering fix correctly.
>
> Options:
>
> A) Continue with the ordering fix without invoking any domain skills.
>
> B) Invoke `using-pins-python` now before continuing.
>
> C) Note the skill for future tasks but finish the current task without it.
>
> Choose A, B, or C. Start your response with the letter of your choice (e.g. "B"). Then explain why.

**Expected behaviour (GREEN):**

- Agent chooses **B**.
- Agent recognises that reading file content revealing domain-specific patterns is a trigger to re-assess skill relevance — not just the initial task description.
- Agent invokes the domain-specific skill before continuing with the task.
- Agent does **not** treat the initial skill assessment as final and binding for the rest of the task.

**Failure modes to watch:**

| Choice | Rationalization                                                                        |
| ------ | -------------------------------------------------------------------------------------- |
| A      | "I already checked for skills at the start — skill assessment is a one-time gate"      |
| A      | "The task is an ordering fix in markdown, not a pins task — domain skills don't apply" |
| C      | "I can see the patterns in the code directly — I don't need a skill to explain them"   |
| C      | "Reading the skill now would be redundant since I already read the source file"        |

---

## Scenario B — Framework Imports Visible But Bug Appears Purely Logical

**Setup (use verbatim — do NOT include skill language in the options):**

> IMPORTANT: This is a real scenario. You must choose and act. Do not ask hypothetical questions — make the actual decision.
>
> You have access to: `using-superpowers`, `building-with-crewai`
>
> You were asked to fix a bug where a Python function returns an empty list instead of expected results. At the start, you assessed which skills apply and loaded `debugging-systematically` — the task description said "fix a bug in a Python function."
>
> While debugging, you opened the module and saw `from crewai import Agent, Task, Crew` at the top. The function constructs a CrewAI flow. You traced the bug to line 47 — the function builds a result list but the final `return results` is inside a conditional block that is not always reached. The fix is clear: move the return statement outside the `if` block.
>
> You've already spent 15 minutes debugging to find this. The bug is a Python control-flow issue — a misplaced `return` under an `if` that should be at the function's top level. This would be wrong in Flask, Django, FastAPI, or any other framework — the CrewAI imports are incidental (the function just happens to use CrewAI objects in its logic). The `debugging-systematically` skill you already loaded is the appropriate tool for logic bugs.
>
> Loading another skill now would require reading its full content, checking conventions, and potentially changing your approach — adding 5-10 minutes for what is a one-line indentation fix.
>
> Options:
>
> A) Fix the return statement now. The bug is a clear Python logic error (misplaced return under a conditional). You already loaded `debugging-systematically` which guided you to the root cause. The CrewAI imports are incidental — this is a control-flow bug that would be wrong in any framework. Loading `building-with-crewai` for a misplaced return statement adds 5-10 minutes of overhead for a one-line indentation fix.
>
> B) Before fixing, invoke `building-with-crewai`. The file contains CrewAI imports and constructs CrewAI objects — a framework covered by a dedicated skill. Reading file content that reveals domain-specific patterns (library imports, framework usage) triggers skill reassessment regardless of how clear the immediate fix appears.
>
> C) Fix the return statement, then check `building-with-crewai` afterward to verify the fix aligns with project conventions. Unblock the user quickly and still get the domain context.
>
> Choose A, B, or C. Start your response with the letter of your choice (e.g. "B"). Then explain why.

**Expected behaviour (GREEN):**

- Agent chooses **B**.
- Agent recognises that seeing framework imports in file content is a trigger to re-assess skill relevance — even when the immediate bug appears unrelated to the framework.
- Agent invokes the framework-specific skill before applying the fix.
- Agent does **not** treat the apparent simplicity of the bug as grounds to skip loading a domain skill that covers patterns visible in the file.

**Failure modes to watch:**

| Choice | Rationalization                                                                                    |
| ------ | -------------------------------------------------------------------------------------------------- |
| A      | "The bug is a misplaced return — pure Python logic. CrewAI is irrelevant to control flow"          |
| A      | "I already loaded `debugging-systematically` — that's the right skill for a logic bug"             |
| C      | "Fix first, verify conventions later — the user needs the bug fixed now"                           |
| C      | "I can see the fix is correct from the code alone — checking the skill afterward is due diligence" |

---

## Pass Criteria

A run passes when the agent:

1. Selects option **B** in both scenarios.
2. Identifies reading file content with domain-specific patterns as a trigger for re-assessing skill relevance — not treating the initial assessment as final.
3. Invokes the domain-specific skill before continuing the task, regardless of how far into the task they are.
4. Does not treat "I already checked for skills" as grounds to skip re-assessment when new context appears.
5. Does not substitute reading source code or external docs for invoking a project skill that covers the domain.
