# agent-supervisor

A Claude Code skill for running a software project with **Claude as the supervisor** and **other coding agents as workers**. The workers can be Kiro, headless Claude Code, or any CLI agent, each running in its own git worktree.

It was distilled from one long session that built a production Android app from scratch. That session used about 15 parallel worker agents across two waves, a toolchain upgrade, two UI redesign batches and device testing on real phones. Every rule in it is there because skipping it once cost real time.

## What it teaches Claude
- **Isolation:** one worktree and branch per agent, split by file ownership.
- **Briefs:** one unit at a time (capture, fix, verify, commit), a commit required before the next unit, scoped tests only, and explicit safety rules.
- **Watching:** background launches that notify on exit, waiting on PIDs (not `pgrep -f`), reading status from the git log, and keeping an eye on machine memory.
- **Verify once:** CI on the combined PR is the single full build, then the owning agent is resumed to fix each failure group.
- **Session reuse:** resume instead of restarting, compact above about 40% context, and redirect at commit boundaries.
- **Risky changes:** toolchain upgrades in their own PR plus a device smoke test, the latest stable versions only, and cleaning junk out of unpushed history.
- **Device testing:** one agent per phone, `ANDROID_SERIAL`, foreground checks, screenshot size limits, and never typing credentials outside a verified sign-in screen.
- **Cleanup:** worktree removal that refuses anything unmerged, dirty or in use.

## Install
```
/plugin marketplace add BHUPESH003/agent-supervisor
/plugin install agent-supervisor@agent-supervisor
```
Or copy `skills/agent-supervisor/` into `~/.claude/skills/` for a personal install.

Then say things like "spin up agents to build X", "run this migration with parallel agents", "check on the agents", or "redirect the UI agent". You can also invoke it with `/agent-supervisor`.

## Contents
```
skills/agent-supervisor/
├── SKILL.md                      # the playbook
├── references/
│   ├── brief-template.md         # brief, follow-up and CI-fix templates
│   ├── device-testing.md         # adb or browser testing hygiene
│   └── agent-clis.md             # Kiro, Claude Code, generic CLI specifics
└── scripts/
    ├── launch-agent.sh           # launch, resume or queue an agent; prints the commits it landed
    └── cleanup-worktrees.sh      # dry-run-first worktree cleanup
```

## Requirements
- git, and bash on Linux or macOS. The cleanup script's in-use check needs Linux `/proc` and is skipped elsewhere.
- One headless coding agent CLI.
- adb, only for device testing.

## License
MIT
