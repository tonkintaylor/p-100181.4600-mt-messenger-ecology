# Gemini CLI Tool Mapping

Skills use Claude Code tool names. When you encounter these in a skill, use your platform equivalent:

| Skill references                | Gemini CLI equivalent                                             |
| ------------------------------- | ----------------------------------------------------------------- |
| `Read` (file reading)           | `read_file` (see [Display fences caveat](#display-fences-caveat)) |
| `Write` (file creation)         | `write_file`                                                      |
| `Edit` (file editing)           | `replace`                                                         |
| `Bash` (run commands)           | `run_shell_command`                                               |
| `Grep` (search file content)    | `grep_search`                                                     |
| `Glob` (search files by name)   | `glob`                                                            |
| `TodoWrite` (task tracking)     | `write_todos`                                                     |
| `Skill` tool (invoke a skill)   | `activate_skill`                                                  |
| `WebSearch`                     | `google_web_search`                                               |
| `WebFetch`                      | `web_fetch`                                                       |
| `Task` tool (dispatch subagent) | No equivalent — Gemini CLI does not support subagents             |

## No subagent support

Gemini CLI has no equivalent to Claude Code's `Task` tool. Skills that rely on subagent dispatch (`subagent-driven-development`, `dispatching-parallel-agents`) will fall back to single-session execution via `executing-plans`.

## Additional Gemini CLI tools

These tools are available in Gemini CLI but have no Claude Code equivalent:

| Tool                                 | Purpose                                                 |
| ------------------------------------ | ------------------------------------------------------- |
| `list_directory`                     | List files and subdirectories                           |
| `save_memory`                        | Persist facts to GEMINI.md across sessions              |
| `ask_user`                           | Request structured input from the user                  |
| `tracker_create_task`                | Rich task management (create, update, list, visualize)  |
| `enter_plan_mode` / `exit_plan_mode` | Switch to read-only research mode before making changes |

## Display fences caveat

`read_file` may wrap file content in display code fences (` ```language ` and ` ``` `) that are **not** part of the actual file. Never include these fence delimiters in `oldString` when using `replace` — they are presentation-only formatting added by the tool. If unsure, verify the actual file content via `run_shell_command` (e.g., `cat <file>`) before composing `oldString`.
