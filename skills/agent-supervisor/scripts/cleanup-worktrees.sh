#!/usr/bin/env bash
# List (default) or remove finished agent worktrees of a repo.
#
#   cleanup-worktrees.sh <main-repo-path> [--apply] [--base origin/main]
#
# A worktree is removable only when all of these hold:
#   - its commits are already in the base: an ancestor, or every commit has an equivalent patch there (squash/cherry-pick);
#   - it has no uncommitted changes to tracked files and no untracked files except ignored ones and known local config;
#   - no running process has its working directory inside it (Linux /proc check), so you never delete a running agent's folder.
# The main checkout is never touched. The local branch is deleted with the worktree; remote branches are left alone.
set -uo pipefail

repo=$1; shift
apply=0 base=origin/main
while [ $# -gt 0 ]; do
  case $1 in
    --apply) apply=1 ;;
    --base) base=$2; shift ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
  shift
done
# ponytail: local config that agents copy in but never commit; extend per project.
LOCAL_CONFIG='google-services.json|GoogleService-Info.plist|\.env\.local|local\.properties'

git -C "$repo" fetch -q origin 2>/dev/null || echo "warning: fetch failed; checking against the local $base" >&2
main=$(git -C "$repo" rev-parse --show-toplevel)

busy() { # any process with its cwd inside $1?
  [ -d /proc ] || return 1
  for c in /proc/[0-9]*/cwd; do
    t=$(readlink "$c" 2>/dev/null) || continue
    case "$t" in "$1"|"$1"/*) return 0 ;; esac
  done
  return 1
}

git -C "$repo" worktree list --porcelain | awk '/^worktree /{print substr($0,10)}' | while read -r wt; do
  [ "$wt" = "$main" ] && continue
  [ -d "$wt" ] || { echo "PRUNE    $wt (folder missing)"; continue; }
  branch=$(git -C "$wt" branch --show-current)
  reason=""
  if ! git -C "$wt" merge-base --is-ancestor HEAD "$base" 2>/dev/null \
     && git -C "$wt" cherry "$base" HEAD 2>/dev/null | grep -q '^+'; then reason="unmerged commits"; fi
  dirty=$(git -C "$wt" status --porcelain | grep -Ev "$LOCAL_CONFIG" | head -1)
  [ -n "$dirty" ] && reason="${reason:+$reason, }uncommitted changes"
  busy "$wt" && reason="${reason:+$reason, }in use by a running process"
  if [ -n "$reason" ]; then echo "KEEP     $wt [$branch]: $reason"; continue; fi
  if [ "$apply" = 1 ]; then
    git -C "$repo" worktree remove --force "$wt" && { [ -n "$branch" ] && git -C "$repo" branch -D "$branch" >/dev/null; } \
      && echo "REMOVED  $wt [$branch]"
  else
    echo "REMOVABLE $wt [$branch]"
  fi
done
git -C "$repo" worktree prune
[ "$apply" = 1 ] || echo "(dry run; re-run with --apply to remove the REMOVABLE ones)"
