# Bare Worktree Notes

This skill follows the bare repository layout described in the referenced Zenn article.

## Target layout

```text
myapp/
├── .git/
├── main/
├── feature-a/
└── feature-b/
```

The important design choice is to treat `main` like any other branch and create it as a worktree.
If the remote repository is empty, bootstrap `main` locally with an initial empty commit before creating that first worktree.

## Required setup sequence

1. Clone as a bare repository into `<repo>/.git`
2. Set `remote.origin.fetch` to `+refs/heads/*:refs/remotes/origin/*`
3. Fetch remote refs
4. Resolve the default branch
5. Add the main branch as a worktree through `scripts/add_worktree.sh`

## Canonical commands

```bash
git clone --bare <repo-url> <repo>/.git
cd <repo>
git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
git fetch origin
bash scripts/add_worktree.sh <repo-root> <main-branch> <repo-root>/<main-branch> [origin/<main-branch>]
```

Use the same helper for the initial main worktree and for repeated additions after setup:

```bash
bash scripts/add_worktree.sh <repo-root> <branch-name> [worktree-path] [start-point]
```

This matters because a bare clone may already contain a local branch with the same name. In that case,
`git worktree add --track -b <branch> ... origin/<branch>` fails because `-b` tries to create a branch that already exists.

Treating `main` like any other branch keeps the branching rules in one place and avoids duplicating local-vs-remote branch handling between setup and later worktree creation.
For an empty remote, there is no `origin/main` yet, so subsequent local branch creation should start from `main` until the branch is pushed.

## Additional worktree examples

Existing local branch or remote branch:

```bash
bash scripts/add_worktree.sh myapp feature-a
```

New branch from remote main:

```bash
bash scripts/add_worktree.sh myapp feature-new myapp/feature-new origin/main
```

Delete a worktree:

```bash
git worktree remove feature-a
git worktree prune
git worktree list
```

## Practical caveats

- bare clones often do not have `remote.origin.fetch` configured for remote branch tracking, so this must be set explicitly
- untracked files such as `.env` are per-worktree
- dependency installs are per-worktree
