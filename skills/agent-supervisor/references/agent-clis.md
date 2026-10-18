# Worker agent CLIs

The supervisor pattern works with any coding agent that can run headless: it takes a prompt, works unattended with tool access, and exits. Pick one per project and smoke-test it first with a trivial prompt in a scratch folder.

## Kiro (`kiro-cli`)
- **Launch:** `kiro-cli chat --no-interactive --trust-all-tools --model <model> "<prompt>" > log 2>&1`
- **Resume the latest session in the current folder:** add `--resume "<follow-up>"`. Sessions are keyed by folder, so `cd` into the worktree first. If that folder is deleted, the running agent crashes ("No such file or directory") and its session can't be resumed.
- **Context use:** `kiro-cli chat --no-interactive --trust-all-tools --resume "/context"` prints "Context window: N% used".
- **Compact:** `... --resume "/compact"` replaces the history with a summary, in about a minute.
- **Credits used:** `... --resume "/usage"`.
- **List sessions:** `kiro-cli chat --list-sessions`.
- Steering files in `.kiro/steering/*.md` with `inclusion: always` are loaded into every session. Put lasting project rules there, such as the current UI focus or creative licence.
- The log contains ANSI codes. Strip them before reading: `sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g'`. The final answer starts at the last line beginning with `> `.
- Steering files are loaded at session start. A rule added mid-run reaches the agent only on its next resume.

## Claude Code (`claude`)
- **Launch:** `claude -p "<prompt>" --permission-mode acceptEdits` (or a settings file with an allowlist), with output redirected to a log.
- **Resume:** `claude -p --continue "<follow-up>"` for the latest session in the folder, or `--resume <session-id>`.
- Project rules go in `CLAUDE.md`.
- From inside Claude Code you can also use the Agent tool for subagents. They are good for short, parallel research or review. For long coding runs, prefer separate headless processes in their own worktrees, so their tool output stays out of the supervisor's context.

## Other CLIs (Codex, Aider, Gemini CLI, ...)
What you need from any CLI:
1. A non-interactive mode that exits when it's done.
2. Auto-approval of tools, scoped to the worktree.
3. A resume or continue flag.
4. Ideally a compact or summarise command.
If there's no resume, keep a `NOTES.md` in the worktree that the agent updates. Start each follow-up with "read NOTES.md first".

## Choosing models
- Use a strong coding model for workers doing real implementation.
- The supervisor (you) needs judgment more than speed. Keep your own context light by not reading agents' full logs: tail them, and read diffs instead of transcripts.
