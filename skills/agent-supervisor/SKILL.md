---
name: agent-supervisor
description: Run a software project with Claude as the supervisor and other coding agents as workers. The workers can be Kiro, Claude subagents, Codex or any headless coding CLI, running in parallel git worktrees, while Claude plans, briefs, watches, reviews and opens PRs. Use this skill whenever the user wants to "spin up agents", "run this with agents", "parallelize the work", "fan out", or have agents build a feature, app, migration, refactor, UI redesign, upgrade or device test, even if they don't say "supervisor". It is also for supervising long-running agents: checking on them, redirecting them, resuming them, fixing CI after them, or cleaning up their worktrees.
---

# Agent supervisor

You are the **supervisor**. Worker agents write the code. You plan, write briefs, launch and watch the workers, review diffs, push, and open PRs. The user merges. This split keeps your context free for judgment calls, and it keeps every change reviewable as a PR.

This playbook comes from building a production Android app from scratch with about 15 parallel worker agents. Each rule below exists because skipping it cost real time once. The reasons are given so you can apply them to situations the rules don't cover.

## Delegate only what earns it

Every worker costs a brief, a launch, a review and a fresh context. For small work that overhead is bigger than the work, so the default is: **you do basic tasks yourself, and delegate the complex ones.**

Before delegating, run through this in order:
1. **Is a worker already on this context?** Check the running agents (`scripts/status.sh`) and the worktrees. If one owns the same files, module or feature, **send the task to it** (resume at its next commit boundary, section 5). It already has the context, so it is the cheapest and most accurate choice, even for a small task.
   **A task that spans several modules (2, 3, n) gets split by who holds the context.** Cut it into one piece per module. Give each piece to the running worker that already knows that module, and only that piece, so no worker spends time learning a module it doesn't own. A piece nobody has context on goes through steps 2 and 3 below (you, or one new agent). Pieces that must meet, such as an interface between modules, get one owner: the worker holding the most of it, or you if it's a small glue change after the pieces land. Sequence dependent pieces at commit boundaries (section 5), and run independent ones in parallel. If one worker holds all the modules involved, it takes the whole task.
2. **Is the task basic?** Examples: a one-file fix, a rename, a config or doc edit, a quick lookup, applying a known review comment, a command you can run now. Do it yourself, in your own checkout or the relevant worktree when no worker is running there. Don't brief a new agent for it.
3. **Otherwise delegate** (new agent, own worktree) when the work is any of: multi-file or multi-unit, long-running, needs its own build and test loop, parallelizable with other work, or would flood your context with logs and diffs.
4. **Never edit in a worktree where a worker is running.** Queue the change for that worker instead, or wait for it to finish. Two writers in one folder is the collision section 1 warns about.

When in doubt, a task that takes you under about five minutes and touches no running worker's files is yours.

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

## Pick the lightest model

Choose a model per agent, when you write its brief. The default is the lightest tier that can do the work well; step up only when the work needs it. A strong model on a mechanical task costs several times more and is often slower, with no better result.

| Work | Tier |
|---|---|
| Mechanical and well-specified: renames, formatting, lint or type fixes, dependency bumps, boilerplate, config edits, docs, simple tests, cleanup, CI log triage | **Light** (Haiku-class, or the CLI's cheapest coding model) |
| Ordinary feature work: a screen, endpoint or module against a clear spec or reference, tests for it, fixing a CI failure with a known cause | **Mid** (Sonnet-class). This is the usual default for implementation |
| Ambiguous or cross-cutting: architecture, tricky debugging, concurrency, security or payment paths, large refactors, migrations, anything where a wrong guess is expensive to undo | **Strong** (Opus-class) |

- **Judge the unit, not the project.** One project usually has all three tiers. Give the design-heavy agent a strong model and the cleanup agent a light one.
- **Start light when a unit is cheap to redo.** If the first commit is wrong or the agent flounders, resume on the next tier up. Don't escalate on a hunch.
- **Don't go light on risky work to save credits.** Money, auth, data migrations and toolchain upgrades get the strong tier.
- **A precise brief lets a lighter model succeed.** If you can write exact steps and file paths, drop a tier.
- **Reviews and your own planning stay with you.** Read diffs yourself; don't hand the judgment to a light worker.
- **Ask the user when it matters.** If the user hasn't named a worker agent (Kiro, Codex, Claude, ...) or model, and the choice isn't obvious from the project or the CLIs installed, ask with the question tool (AskUserQuestion in Claude Code) before launching. Offer 2-4 options, put your recommendation first marked "(Recommended)", and say the cost or speed trade-off in each description. Also ask when a unit sits on the border between tiers, or when the strong tier would cost noticeably more. Use one question for the agent CLI and one for the model tier; batch them in a single call. Don't ask when the user already decided, when only one CLI is available, or for clear-cut light or mid work: pick the default and say so.
- **Say what you chose.** Tell the user the model per agent and why, in one line each, so they can override it.
- Model names differ per CLI and change often. Read the list from the CLI rather than from memory (see `references/agent-clis.md`).

## 3. Launch and watch

- **Run each agent as a background command** that writes to a log file and prints a done line, so you get a notification when it ends. `scripts/launch-agent.sh` does this. Don't poll in a loop; wait for the notification.
- **Wait on a process ID, not a pattern.** `pgrep -f "<pattern>"` matches the watcher's own shell, because the pattern appears in its command line. We hit this twice: one watcher never fired, and a kill loop killed its own shell. Capture the PID (`$!`, or `ps -eo pid,args | awk '/kiro-cli chat/ && !/awk/'`) and wait with `while kill -0 $PID; do sleep 30; done`.
- **Give the user a live view.** Launch with `AGENT_UNITS=<n>` set, then `scripts/status.sh` prints one progress bar per worktree (units committed / expected, running or idle, uncommitted files). Tell the user they can run `watch -n 10 <path>/scripts/status.sh` in a spare terminal from the main worktree. Run it yourself for status answers too.
- **To check status**, look at `git log origin/main..HEAD` in the agent's worktree (commits landed), `git status` (work in progress) and the tail of its log. Report in plain words: which unit it's on, what has landed, and a rough ETA from the time per unit so far.
- **Watch the machine.** Several Gradle, Kotlin or Node daemons from finished worktrees can eat most of the RAM, and the harness may then reap your background watchers. Kill idle daemons from older toolchain versions and leave the ones in use.

## 4. Verify once, then fix

Don't let every agent run full builds, and don't re-run them yourself per PR. Merge the finished branches into one PR, or push each one, and let **CI be the single verifier**. Group the CI failures by area, then resume the agent that owns each area to fix them. The user pushed back hard on duplicated verification: "merge them all and verify at once and then spawn separate agents for fix".

Before pushing, review each diff yourself for scope, secrets and junk files. That review is cheap and it's your job; full builds are CI's job.

## 5. Reuse agents and keep their context healthy

- **Resume, don't restart.** A follow-up such as fixing CI, the next batch or a redirect goes to the session that already has the context (`--resume` in the same folder). A cold agent re-reads the codebase at full cost. Resumed sessions took minutes and few credits; fresh ones took far longer.
- **Compact above roughly 40% context.** Check the agent's context use before resuming it with a big task, and compact first if it's high. `launch-agent.sh --resume --compact-above 40` does this check and the compact for you (any CLI that can report context use; see `references/agent-clis.md`). Compacting also removes poison from the history. For example, an oversized image in the history makes every later request fail. Delete the file, compact, then resume.
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
