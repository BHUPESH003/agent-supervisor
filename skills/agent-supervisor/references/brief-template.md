# Brief template

Fill this in per agent and save it as a file; the launcher reads it. Keep it under about 80 lines. Agents follow short, concrete briefs better than long ones. Delete any section that doesn't apply.

```markdown
You are the <area> agent for <project> (this folder only: <worktree path>).
You run unattended. When something is ambiguous, decide sensibly and note the decision in your final report.

## Goal
<One paragraph: the outcome, in the user's words if possible. Why it matters.>

## Context
- The stack and where things live: <modules or paths>. Read <steering/rules file> first.
- The reference to match, if any: <web app path, design file, spec, API contract>.
- Already done, don't redo: <merged PRs or areas>.

## Scope, in this order: one unit at a time
1. <unit 1>
2. <unit 2>
...
For EACH unit:
1. Look at its current state, only for this unit.
2. Implement. Shared pieces go in <shared module> when several units need them.
3. Run the tests of the touched module only: <command>.
4. Verify, e.g. install it and screenshot this screen.
5. Commit.
6. Move to the next unit.
A commit must land for unit 1 before you look at unit 2.
Stop after <last unit> and report.

## Rules
- Don't change <behaviour / data / API / navigation> beyond what's listed.
- Dependencies: prefer what's already installed. If you add one, use its latest stable version (check the registry; never use alpha, beta or RC).
- Commit per unit with the repo's git identity (never pass -c user.*). Run git status before every commit: no build output (bin/, build/), no screenshots, no secrets or local config (<files>). Don't push.
- Don't run the full build or lint. CI does that.

## Safety
- Environment: <staging URL / sandbox>. Never call <prod>.
- Never: <send messages, payments, approvals, deletes, DB scripts, printing secrets>.
- Test accounts: <where credentials live>. Never print them.
- <Device rules, if it uses a phone: see device-testing.md>

## Final answer
Short:
- what changed per unit;
- what's left or unverified;
- anything risky you did, such as logging an account out or touching data;
- where the artifacts are.
```

## Follow-up messages to a resumed session

Keep them shorter, and state what changed since the agent's last turn:

```markdown
<What happened: "PR #21 is merged; this folder is now on branch X, fresh from main.">
<New instruction or correction, with the reason.>
<Scope for this round, one unit at a time, as before.>
Same rules as before. Short report at the end.
```

## Fixing CI failures

```markdown
CI failed on PR #<n>. The failing tasks and errors are in the log below.
Fix only these, one commit per root cause. Run the failing module's tests locally.
Don't touch unrelated code. Don't push.
<trimmed error log>
```
