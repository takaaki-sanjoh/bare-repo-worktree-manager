#!/usr/bin/env bash
set -euo pipefail

if [[ ${1:-} == "-h" || ${1:-} == "--help" || $# -lt 1 ]]; then
  echo "Usage: verify_bare_worktree_repo.sh <target-dir> [main-branch]"
  exit $([[ $# -lt 1 ]] && echo 1 || echo 0)
fi

root="$1"
expected_branch="${2:-}"

root="$(python3 - <<'PY' "$root"
import os, sys
print(os.path.abspath(os.path.expanduser(sys.argv[1])))
PY
)"

if [[ ! -d "$root/.git" ]]; then
  echo "Error: missing bare git directory at $root/.git" >&2
  exit 2
fi

if [[ "$(git -C "$root" rev-parse --is-bare-repository)" != "true" ]]; then
  echo "Error: $root/.git is not configured as a bare repository" >&2
  exit 3
fi

fetch_value="$(git -C "$root" config --get remote.origin.fetch || true)"
if [[ "$fetch_value" != "+refs/heads/*:refs/remotes/origin/*" ]]; then
  echo "Error: remote.origin.fetch is not set correctly" >&2
  exit 4
fi

if [[ -z "$expected_branch" ]]; then
  expected_branch="$(git -C "$root" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  expected_branch="${expected_branch#origin/}"
  if [[ -z "$expected_branch" ]]; then
    for candidate in main master; do
      if [[ -d "$root/$candidate" ]]; then
        expected_branch="$candidate"
        break
      fi
    done
  fi
fi

if [[ -z "$expected_branch" || ! -d "$root/$expected_branch" ]]; then
  echo "Error: expected main worktree directory not found" >&2
  exit 5
fi

if [[ ! -f "$root/$expected_branch/.git" ]]; then
  echo "Error: worktree git file missing at $root/$expected_branch/.git" >&2
  exit 6
fi

if git -C "$root" show-ref --verify --quiet "refs/remotes/origin/$expected_branch"; then
  upstream_branch="$(git -C "$root/$expected_branch" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
  if [[ "$upstream_branch" != "origin/$expected_branch" ]]; then
    echo "Error: main worktree branch is not tracking origin/$expected_branch" >&2
    exit 7
  fi
fi

git -C "$root" worktree list --porcelain >/dev/null

echo "verified_root=$root"
echo "verified_main_branch=$expected_branch"
git -C "$root" worktree list
