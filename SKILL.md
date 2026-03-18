---
name: bare-repo-worktree-manager
description: manage a local git workspace layout built on a bare repository plus git worktrees. use when the user asks codex or chatgpt to initialize or clone a repository into this layout, prepare a repo for parallel agent work, add another workspace or worktree later, or maintain a clean multi-worktree local repo structure. prefer executing the bundled shell scripts for setup, validation, and adding worktrees, then report the resulting paths and next commands.
---

# Bare Repo Worktree Manager

Use this skill to create and manage a local repository with this layout:

```text
<repo-name>/
├── .git/          # bare repository
├── <main-branch>/ # main worktree
└── ...            # additional worktrees added later
```

This skill is optimized for requests like "repository setup", "set up this repo locally", "prepare this repo for parallel worktrees", or "add another workspace/worktree" when the user is using this bare-repo-plus-worktree layout.

## Supported tasks

1. Initialize a new local bare-repo-plus-worktree workspace from a GitHub SSH or HTTPS URL.
2. Verify that an existing workspace root follows the expected layout.
3. Add another worktree safely for an existing branch, remote branch, or new branch.

## Default workflow

1. Identify whether the user wants initial setup, verification, or an additional worktree.
2. For initial setup:
   - Read the repository URL from the user.
   - Choose the target directory:
     - If the user gave an explicit path, use it.
     - Otherwise create the repository under the current working directory using the repo name derived from the URL.
   - Run `scripts/setup_bare_worktree_repo.sh` to create the bare repository, configure fetch, detect the default branch, and invoke `scripts/add_worktree.sh` for the main worktree.
   - Run `scripts/verify_bare_worktree_repo.sh` on the created directory.
3. For adding another worktree:
   - Treat the provided directory as the workspace root that contains `.git/` and sibling worktrees.
   - Run `scripts/add_worktree.sh` instead of composing `git worktree add` by hand.
   - Verify the result with `git -C <repo-root> worktree list` and, when useful, `scripts/verify_bare_worktree_repo.sh`.
4. Report:
   - repository root path
   - detected or requested main branch when relevant
   - created or verified worktree path
   - the next safe command for adding another worktree
   - any follow-up warnings

## Execution rules

- Prefer doing the requested workspace operation directly when terminal access is available.
- Do not stop after printing commands unless the user explicitly asked for instructions only.
- Accept both SSH and HTTPS GitHub URLs.
- Use `python3` for any Python subprocesses or inline scripts.
- Always set `remote.origin.fetch` to `+refs/heads/*:refs/remotes/origin/*` after bare clone, then fetch.
- Always create the main branch as a worktree. Do not leave the bare repo without a checked-out worktree.
- During setup, resolve the default branch in `scripts/setup_bare_worktree_repo.sh`, then add the main worktree through `scripts/add_worktree.sh` rather than calling `git worktree add` directly.
- If `origin/<main-branch>` exists, let `scripts/add_worktree.sh` create the main worktree branch so it tracks that remote branch.
- If the remote repository is empty, initialize `main` locally with an empty commit so the first worktree can still be created.
- When adding another worktree later, do not assume `--track -b <branch> origin/<branch>` is safe. In a bare clone, a same-named local branch may already exist.
- Use `scripts/add_worktree.sh` for the initial main worktree and every additional worktree so existing local branches, remote-only branches, and new branches are handled correctly.
- If the default branch cannot be inferred from `origin/HEAD`, fall back in this order: user-specified branch, `main`, `master`.
- When setup initialized an empty remote locally, use the local `main` branch as the start-point for the next new branch until `main` is pushed upstream.
- If the target directory already exists and is non-empty, stop and explain the conflict instead of overwriting it.

## Commands to run

Initial setup:

```bash
bash scripts/setup_bare_worktree_repo.sh <repo-url> [target-dir] [main-branch]
```

Workspace verification:

```bash
bash scripts/verify_bare_worktree_repo.sh <target-dir> [main-branch]
```

Add another worktree safely:

```bash
bash scripts/add_worktree.sh <target-dir> <branch-name> [worktree-path] [start-point]
```

## What to tell the user after running a workspace command

Always summarize the result in practical terms:

- `repo root`: the directory that contains `.git/` and worktrees
- `main worktree`: `<repo root>/<main-branch>` when setup or validation identifies it; note that setup creates it via `scripts/add_worktree.sh`
- `new or requested worktree`: the path that was just created or checked, when applicable
- `add a worktree for an existing local or remote branch`: `bash scripts/add_worktree.sh <repo root> <branch-name>`
- `add a new branch worktree from the main branch`: `bash scripts/add_worktree.sh <repo root> <branch-name> <repo root>/<branch-name> origin/<main-branch>`

Use examples like these when helpful:

```bash
bash scripts/add_worktree.sh myapp feature-a
bash scripts/add_worktree.sh myapp feature-new myapp/feature-new origin/main
git -C myapp worktree list
```

## Warnings to include when relevant

Mention these operational caveats after successful setup:

- some IDEs may not fully understand bare repository plus worktree layouts
- `.env` and other untracked files must be managed per worktree
- dependency installation like `npm install` or `pip install` is usually needed in each worktree

## Resources

- See `references/bare-worktree-notes.md` for the rationale and the exact conventions this skill follows.
- Use `scripts/setup_bare_worktree_repo.sh` for setup.
- Treat `scripts/setup_bare_worktree_repo.sh` as the bare-clone/bootstrap step and `scripts/add_worktree.sh` as the single helper for main and additional worktrees.
- Use `scripts/verify_bare_worktree_repo.sh` for validation.
