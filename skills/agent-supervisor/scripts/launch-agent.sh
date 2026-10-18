#!/usr/bin/env bash
# Launch (or resume) a headless worker agent in its worktree. Meant to run as a background
# command, so the supervisor is notified when it exits.
#
#   launch-agent.sh <worktree> <brief-file> <log-file> [--resume] [--after-pid PID] [--compact]
#
#   --resume         continue the latest session in <worktree> instead of starting a new one
#   --after-pid PID  wait for PID to exit first (queue agents that share a device)
#   --compact        compact the session before sending the brief (with --resume)
#
# AGENT_CLI picks the CLI: kiro (default) or claude. AGENT_MODEL is passed through when set.
# After the agent exits, the script prints its exit code and the commits it landed on top of origin/main.
set -uo pipefail

wt=$1 brief=$2 log=$3; shift 3
resume=0 after="" compact=0
while [ $# -gt 0 ]; do
  case $1 in
    --resume) resume=1 ;;
    --after-pid) after=$2; shift ;;
    --compact) compact=1 ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
  shift
done

# Wait on the PID, not a pgrep pattern: pgrep -f matches this script's own command line.
if [ -n "$after" ]; then while kill -0 "$after" 2>/dev/null; do sleep 30; done; fi

cd "$wt" || { echo "no worktree $wt" >&2; exit 1; }
prompt=$(cat "$brief")
cli=${AGENT_CLI:-kiro}

run() { # run <prompt> [resume]
  case $cli in
    kiro)
      args=(chat --no-interactive --trust-all-tools)
      [ -n "${AGENT_MODEL:-}" ] && args+=(--model "$AGENT_MODEL")
      [ "${2:-0}" = 1 ] && args+=(--resume)
      kiro-cli "${args[@]}" "$1" ;;
    claude)
      args=(-p --permission-mode acceptEdits)
      [ -n "${AGENT_MODEL:-}" ] && args+=(--model "$AGENT_MODEL")
      [ "${2:-0}" = 1 ] && args+=(--continue)
      claude "${args[@]}" "$1" ;;
    *) echo "unknown AGENT_CLI=$cli" >&2; return 2 ;;
  esac
}

if [ "$compact" = 1 ] && [ "$cli" = kiro ]; then run "/compact" 1 > "$log.compact" 2>&1; fi
run "$prompt" "$resume" > "$log" 2>&1
code=$?
echo "AGENT_EXIT=$code"
git log --oneline origin/main..HEAD 2>/dev/null | head -30
git status --short | head -10
