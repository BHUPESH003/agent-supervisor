---
name: agent-supervisor
description: Run a software project with Claude as the supervisor and other coding agents as workers. The workers can be Kiro, Claude subagents, Codex or any headless coding CLI, running in parallel git worktrees, while Claude plans, briefs, watches, reviews and opens PRs. Use this skill whenever the user wants to "spin up agents", "run this with agents", "parallelize the work", "fan out", or have agents build a feature, app, migration, refactor, UI redesign, upgrade or device test, even if they don't say "supervisor". It is also for supervising long-running agents: checking on them, redirecting them, resuming them, fixing CI after them, or cleaning up their worktrees.
---

# Agent supervisor

You are the **supervisor**. Worker agents write the code. You plan, write briefs, launch and watch the workers, review diffs, push, and open PRs. The user merges. This split keeps your context free for judgment calls, and it keeps every change reviewable as a PR.

This playbook comes from building a production Android app from scratch with about 15 parallel worker agents. Each rule below exists because skipping it cost real time once. The reasons are given so you can apply them to situations the rules don't cover.

## 1. Before launching anything

- **Use one git worktree and one branch per agent.** Run `git worktree add -b <branch> ../<repo>-<area> origin/main`. Agents that share a folder overwrite each other's files and their build outputs collide. Copy in any untracked config the build needs, such as `google-services.json` or `.env.local`, and never commit it.
- **Split the work by ownership, not by layer.** Each agent should own a set of files that no other agent touches. Shared files (routing, the design system, version catalogs) belong to one agent or to a small integration step afterwards.
- **Check that the agent CLI works headless** with a one-line prompt before you launch ten agents. See `references/agent-clis.md` for Kiro, Claude Code and generic CLIs.
- **Look up the latest stable versions** of any toolchain or dependency an agent will add (the registry or the release page). Versions from model memory are often a year old. In our project nobody checked, and the user rightly asked why a brand-new project used outdated versions.

## 2. Write the brief

Use `references/brief-template.md`. The parts that matter most:

1. **Work one unit at a time.** For each screen, endpoint or module: capture it, fix it, verify it, commit it, then move on. Require the first commit before the agent looks at the second unit. If you don't, agents spend their first half hour surveying everything (screenshotting every screen, reading every file) and land nothing. The user noticed this and objected.
2. **Run only scoped tests.** The agent runs the touched module's tests, never the full build and lint. CI does that once (see section 4).
3. **Spell out safety.** Name the environment it may touch (staging, a sandbox). List what it must never do (prod calls, sending messages or payments, printing secrets, pushing). Say who runs database scripts. Agents follow explicit rules well and invent their own badly.
4. **Set the commit rules.** The agent commits per unit with the repo's git identity, never passes `-c user.*`, and never pushes; you push after review. It checks `git status` before every commit so build junk (`bin/`, screenshots) doesn't slip in.
5. **Ask for a short final report:** what changed per unit, what's left, anything risky it did. You relay what matters to the user.

## 3. Launch and watch

- **Run each agent as a background command** that writes to a log file and prints a done line, so you get a notification when it ends. `scripts/launch-agent.sh` does this. Don't poll in a loop; wait for the notification.
- **Wait on a process ID, not a pattern.** `pgrep -f "<pattern>"` matches the watcher's own shell, because the pattern appears in its command line. We hit this twice: one watcher never fired, and a kill loop killed its own shell. Capture the PID (`$!`, or `ps -eo pid,args | awk '/kiro-cli chat/ && !/awk/'`) and wait with `while kill -0 $PID; do sleep 30; done`.
- **To check status**, look at `git log origin/main..HEAD` in the agent's worktree (commits landed), `git status` (work in progress) and the tail of its log. Report in plain words: which unit it's on, what has landed, and a rough ETA from the time per unit so far.
- **Watch the machine.** Several Gradle, Kotlin or Node daemons from finished worktrees can eat most of the RAM, and the harness may then reap your background watchers. Kill idle daemons from older toolchain versions and leave the ones in use.

## 4. Verify once, then fix

Don't let every agent run full builds, and don't re-run them yourself per PR. Merge the finished branches into one PR, or push each one, and let **CI be the single verifier**. Group the CI failures by area, then resume the agent that owns each area to fix them. The user pushed back hard on duplicated verification: "merge them all and verify at once and then spawn separate agents for fix".

Before pushing, review each diff yourself for scope, secrets and junk files. That review is cheap and it's your job; full builds are CI's job.

## 5. Reuse agents and keep their context healthy

- **Resume, don't restart.** A follow-up such as fixing CI, the next batch or a redirect goes to the session that already has the context (`--resume` in the same folder). A cold agent re-reads the codebase at full cost. Resumed sessions took minutes and few credits; fresh ones took far longer.
- **Compact above roughly 40% context.** Check the agent's context use before resuming it with a big task, and compact first if it's high. Compacting also removes poison from the history. For example, an oversized image in the history makes every later request fail. Delete the file, compact, then resume.
- **Redirect at a commit boundary.** You can't message a headless agent mid-run. To change its direction, wait until its next commit lands, kill it, and resume the same session with the new instruction. A background script can do this: wait for the commit count to rise, then kill and resume. Write lasting rules into the project's agent steering or rules file too, so future sessions pick them up.
- **Keep one session per worktree folder.** Resume usually picks the most recent session in a folder. Run one-off agents, such as a device tester, in a different folder so they don't hijack the long-lived agent's session.

## 6. Risky changes get their own PR

- **Toolchain and major library upgrades** go in a separate PR from code cleanup, and are merged only after CI plus an on-device or staging smoke test. If an agent mixes them, split its commits: cherry-pick the upgrade commits onto a fresh branch from main and resolve conflicts there.
- **Rebase finished work onto current main yourself.** Other PRs will have landed meanwhile. Expect import-path and API changes in files the agent never saw, and grep for the old API across the whole tree after the cherry-pick.
- **Clean unpushed history yourself.** If an agent committed junk (build output, screenshots), remove it from that commit before pushing. Check out that commit detached, `git rm --cached`, amend, then cherry-pick the rest of the branch on top. Afterwards, confirm that the only difference from the agent's tip is the junk.

## 7. Device and app testing with agents

Agents can drive a real phone over adb, or a browser, and take screenshots to compare the app with a reference design. This works well, but needs the device hygiene rules in `references/device-testing.md`. The short version:
- Only one agent uses a device at a time, so queue the device users.
- Pin the device with `ANDROID_SERIAL`.
- Keep the app in the foreground.
- Skip screenshots over 2 MB.
- Never type credentials anywhere except a verified sign-in screen.

## 8. Cleanup

Remove worktrees only when **no agent is running in them**. We once deleted a folder from under a running test agent and it crashed. Use `scripts/cleanup-worktrees.sh`. It's a dry run by default. It removes only worktrees whose branch is merged into origin/main (or whose commits are already there), that have no uncommitted changes, and that no process is using. Give the user the command to run; deleting is their call.

## Working with the user

- **The user merges.** You push branches and open PRs with clear descriptions: what changed, what wasn't verified, and departures from spec. Don't merge unless they ask.
- **Confirm before outward-facing or destructive actions:** public repos, deleting branches, mutating live data, publishing.
- **Status answers** come first, in plain words: what's running, what landed, what's next, and the ETA. Then any decision you need from them.
- **When an agent did something surprising**, tell the user plainly. Examples: it typed a password somewhere odd, logged an account out, or touched data. Finding out later is worse.
