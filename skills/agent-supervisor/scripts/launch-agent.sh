#!/usr/bin/env bash
# Launch (or resume) a headless worker agent in its worktree. Meant to run as a background
# command, so the supervisor is notified when it exits.
#
#   launch-agent.sh <worktree> <brief-file> <log-file> [--resume] [--after-pid PID] [--compact]
#
#   --resume         continue the latest session in <worktree> instead of starting a new one
#   --after-pid PID  wait for PID to exit first (queue agents that share a device)
#   --compact        compact the session before sending the brief (with --resume)
#   --compact-above N  with --resume: read the session's context use and compact only if it is
#                    over N percent (40 is the playbook's threshold). Needs a CLI that can report context use.
#
# AGENT_CLI picks the CLI: kiro (default), claude, or custom (any headless CLI, see below).
# AGENT_MODEL is passed through with AGENT_MODEL_FLAG (default --model) when set.
# AGENT_UNITS = number of units in the brief; scripts/status.sh uses it for the progress bar.
# After the agent exits, the script prints its exit code and the commits it landed on top of origin/main.
set -uo pipefail

wt=$1 brief=$2 log=$3; shift 3
resume=0 after="" compact=0 above=""
while [ $# -gt 0 ]; do
  case $1 in
    --resume) resume=1 ;;
    --after-pid) after=$2; shift ;;
    --compact) compact=1 ;;
    --compact-above) above=$2; shift ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
  shift
done

# Wait on the PID, not a pgrep pattern: pgrep -f matches this script's own command line.
if [ -n "$after" ]; then while kill -0 "$after" 2>/dev/null; do sleep 30; done; fi

cd "$wt" || { echo "no worktree $wt" >&2; exit 1; }
# Expected unit count, read by status.sh for the progress bar.
[ -n "${AGENT_UNITS:-}" ] && echo "$AGENT_UNITS" > "$(git rev-parse --git-dir)/agent-units"
prompt=$(cat "$brief")
cli=${AGENT_CLI:-kiro}

# Per-CLI settings: base command, resume flag, and the prompts that print context use / compact.
# Any other CLI: AGENT_CLI=custom plus AGENT_CMD, AGENT_RESUME_FLAG, AGENT_CTX_PROMPT, AGENT_COMPACT_PROMPT.
case $cli in
  kiro)   cmd=(kiro-cli chat --no-interactive --trust-all-tools); resume_flag=--resume;   ctx_prompt=/context; compact_prompt=/compact ;;
  claude) cmd=(claude -p --permission-mode acceptEdits);          resume_flag=--continue; ctx_prompt=/context; compact_prompt=/compact ;;
  custom) read -ra cmd <<<"${AGENT_CMD:?set AGENT_CMD for AGENT_CLI=custom}"
          resume_flag=${AGENT_RESUME_FLAG:-}; ctx_prompt=${AGENT_CTX_PROMPT:-}; compact_prompt=${AGENT_COMPACT_PROMPT:-} ;;
  *) echo "unknown AGENT_CLI=$cli" >&2; exit 2 ;;
esac

run() { # run <prompt> [resume]
  local args=("${cmd[@]}")
  [ -n "${AGENT_MODEL:-}" ] && args+=("${AGENT_MODEL_FLAG:---model}" "$AGENT_MODEL")
  [ "${2:-0}" = 1 ] && [ -n "$resume_flag" ] && args+=("$resume_flag")
  "${args[@]}" "$1"
}

# Context use of the latest session in this folder, as an integer percent (empty if unknown).
# Matches "Context window: N% used" or a "Tokens: ... (N%)" line.
ctx_pct() {
  [ -n "$ctx_prompt" ] || return
  run "$ctx_prompt" 1 2>&1 | sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g' |
    sed -nE 's/.*Context window: *([0-9]+)%.*/\1/p; s/.*Tokens:.*\(([0-9]+)%\).*/\1/p' | head -1
}
if [ "$resume" = 1 ] && [ -n "$above" ]; then
  pct=$(ctx_pct)
  if [ -n "$pct" ] && [ "$pct" -gt "$above" ]; then compact=1; echo "context ${pct}% > ${above}%: compacting"; fi
fi
if [ "$compact" = 1 ] && [ -n "$compact_prompt" ]; then run "$compact_prompt" 1 > "$log.compact" 2>&1; fi
run "$prompt" "$resume" > "$log" 2>&1
code=$?
echo "AGENT_EXIT=$code"
git log --oneline origin/main..HEAD 2>/dev/null | head -30
git status --short | head -10
