#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  add_worktree.sh <repo-root> <branch-name> [worktree-path] [start-point]

Examples:
  add_worktree.sh ~/projects/myapp main ~/projects/myapp/main
  add_worktree.sh ~/projects/myapp feature-a
  add_worktree.sh ~/projects/myapp feature-new ~/projects/myapp/feature-new origin/main
USAGE
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

# Use the same entrypoint for the initial default-branch worktree and later branch worktrees.

repo_root="$1"
branch_name="$2"
worktree_path="${3:-}"
start_point="${4:-}"

repo_root="$(python3 - <<'PY' "$repo_root"
import os, sys
print(os.path.abspath(os.path.expanduser(sys.argv[1])))
PY
)"

if [[ ! -d "$repo_root/.git" ]]; then
  echo "Error: missing bare git directory at $repo_root/.git" >&2
  exit 2
fi

if [[ -z "$worktree_path" ]]; then
  worktree_path="$repo_root/$branch_name"
fi

worktree_path="$(python3 - <<'PY' "$worktree_path"
import os, sys
print(os.path.abspath(os.path.expanduser(sys.argv[1])))
PY
)"

if [[ -e "$worktree_path" ]]; then
  echo "Error: worktree path already exists: $worktree_path" >&2
  exit 3
fi

worktree_list="$(git -C "$repo_root" worktree list --porcelain)"

branch_in_use_path="$(
  WORKTREE_LIST="$worktree_list" python3 - <<'PY' "$branch_name"
import os, sys

target = f"refs/heads/{sys.argv[1]}"
current_path = None

for raw_line in os.environ.get("WORKTREE_LIST", "").splitlines():
    line = raw_line.rstrip("\n")
    if line.startswith("worktree "):
        current_path = line.split(" ", 1)[1]
    elif line.startswith("branch ") and line.split(" ", 1)[1] == target:
        print(current_path or "")
        raise SystemExit(0)

raise SystemExit(0)
PY
)"

if [[ -n "$branch_in_use_path" ]]; then
  echo "Error: branch $branch_name is already checked out in another worktree: $branch_in_use_path" >&2
  exit 4
fi

if git -C "$repo_root" show-ref --verify --quiet "refs/heads/$branch_name"; then
  git -C "$repo_root" worktree add "$worktree_path" "$branch_name"
  if git -C "$repo_root" show-ref --verify --quiet "refs/remotes/origin/$branch_name"; then
    git -C "$worktree_path" branch --set-upstream-to="origin/$branch_name" "$branch_name"
  fi
elif git -C "$repo_root" show-ref --verify --quiet "refs/remotes/origin/$branch_name"; then
  git -C "$repo_root" worktree add --track -b "$branch_name" "$worktree_path" "origin/$branch_name"
else
  if [[ -z "$start_point" ]]; then
    echo "Error: branch $branch_name does not exist locally or on origin. Pass a start-point as the fourth argument." >&2
    exit 5
  fi
  git -C "$repo_root" worktree add -b "$branch_name" "$worktree_path" "$start_point"
fi

printf 'repo_root=%s\n' "$repo_root"
printf 'branch_name=%s\n' "$branch_name"
printf 'worktree_path=%s\n' "$worktree_path"
