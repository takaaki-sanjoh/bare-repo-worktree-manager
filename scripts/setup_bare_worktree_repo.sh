#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  setup_bare_worktree_repo.sh <repo-url> [target-dir] [main-branch]

Examples:
  setup_bare_worktree_repo.sh git@github.com:org/repo.git
  setup_bare_worktree_repo.sh https://github.com/org/repo.git ~/projects/repo
  setup_bare_worktree_repo.sh git@github.com:org/repo.git ~/projects/repo main
USAGE
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" || $# -lt 1 ]]; then
  usage
  exit $([[ $# -lt 1 ]] && echo 1 || echo 0)
fi

repo_url="$1"
target_dir="${2:-}"
requested_main_branch="${3:-}"

repo_basename="$(basename "$repo_url")"
repo_name="${repo_basename%.git}"

if [[ -z "$target_dir" ]]; then
  target_dir="$PWD/$repo_name"
fi

target_dir="$(python3 - <<'PY' "$target_dir"
import os, sys
print(os.path.abspath(os.path.expanduser(sys.argv[1])))
PY
)"

if [[ -e "$target_dir" ]] && [[ -n "$(find "$target_dir" -mindepth 1 -maxdepth 1 2>/dev/null | head -n 1)" ]]; then
  echo "Error: target directory exists and is not empty: $target_dir" >&2
  exit 2
fi

mkdir -p "$target_dir"

if [[ -e "$target_dir/.git" ]]; then
  echo "Error: $target_dir/.git already exists" >&2
  exit 3
fi

echo "[1/5] Cloning bare repository into $target_dir/.git"
git clone --bare "$repo_url" "$target_dir/.git"

echo "[2/5] Configuring remote fetch"
git -C "$target_dir" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"

echo "[3/5] Fetching remote refs"
git -C "$target_dir" fetch origin --prune

detect_default_branch() {
  local root="$1"
  local branch=""

  branch="$(git -C "$root" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  branch="${branch#origin/}"
  if [[ -n "$branch" ]]; then
    printf '%s\n' "$branch"
    return 0
  fi

  for candidate in main master; do
    if git -C "$root" show-ref --verify --quiet "refs/remotes/origin/$candidate" || git -C "$root" show-ref --verify --quiet "refs/heads/$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

repo_has_any_branch_refs() {
  local root="$1"
  git -C "$root" for-each-ref --count=1 --format='%(refname)' refs/heads refs/remotes | grep -q .
}

main_branch="$requested_main_branch"
if [[ -z "$main_branch" ]]; then
  main_branch="$(detect_default_branch "$target_dir" || true)"
fi

if [[ -z "$main_branch" ]] && ! repo_has_any_branch_refs "$target_dir"; then
  main_branch="main"
fi

if [[ -z "$main_branch" ]]; then
  echo "Error: could not determine default branch. Pass it explicitly as the third argument." >&2
  exit 4
fi

echo "[4/5] Creating main worktree via add_worktree.sh for branch $main_branch"
script_dir="$(cd "$(dirname "$0")" && pwd)"
bash "$script_dir/add_worktree.sh" "$target_dir" "$main_branch" "$target_dir/$main_branch"

echo "[5/5] Done"
new_branch_start_point="$main_branch"
if git -C "$target_dir" show-ref --verify --quiet "refs/remotes/origin/$main_branch"; then
  new_branch_start_point="origin/$main_branch"
fi

printf 'repo_root=%s\n' "$target_dir"
printf 'main_branch=%s\n' "$main_branch"
printf 'main_worktree=%s\n' "$target_dir/$main_branch"
printf 'main_worktree_created_via=%s\n' "$script_dir/add_worktree.sh"
printf 'next_existing_or_remote_command=%s\n' "bash $script_dir/add_worktree.sh $target_dir <branch-name>"
printf 'next_new_branch_command=%s\n' "bash $script_dir/add_worktree.sh $target_dir <branch-name> $target_dir/<branch-name> $new_branch_start_point"
