#!/usr/bin/env bash
# Progress bars for the worker agents, one line per worktree. Run it from the main worktree,
# or under `watch -n 10` for a live view:  watch -n 10 scripts/status.sh
#
#   status.sh [base-ref]      base-ref defaults to origin/main
#
# Progress = commits landed on top of base-ref / units expected. launch-agent.sh records the
# expected count when AGENT_UNITS is set. Without it you get the commit count and no bar.
# "running" means some process has the worktree as its working directory (needs lsof).
base=${1:-origin/main}
cwds=$(lsof -a -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')

bar() { # bar <done> <total>
  local d=$1 t=$2 w=20 f i out=""
  [ "$d" -gt "$t" ] && d=$t
  f=$((d * w / t))
  for ((i = 0; i < w; i++)); do [ $i -lt $f ] && out+="█" || out+="░"; done
  printf '%s %d/%d' "$out" "$d" "$t"
}

git worktree list --porcelain | awk '/^worktree /{p=substr($0,10)} /^branch /{print p "\t" substr($0,19)}' |
while IFS=$'\t' read -r wt branch; do
  [ "$wt" = "$(git rev-parse --show-toplevel)" ] && continue
  commits=$(git -C "$wt" rev-list --count "$base..HEAD" 2>/dev/null || echo 0)
  dirty=$(git -C "$wt" status --short | wc -l)
  total=$(cat "$(git -C "$wt" rev-parse --git-dir)/agent-units" 2>/dev/null)
  if grep -qxF "$wt" <<<"$cwds"; then state="running"; else state="idle"; fi
  if [ -n "$total" ] && [ "$total" -gt 0 ] 2>/dev/null; then p=$(bar "$commits" "$total"); else p="$commits commits"; fi
  printf '%-28s %-8s %s%s\n' "$branch" "$state" "$p" "$([ "$dirty" -gt 0 ] && echo "  (+$dirty uncommitted)")"
done
