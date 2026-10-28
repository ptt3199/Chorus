#!/usr/bin/env bash
# Merge upstream main into main, rebase ptt on it, push, and reinstall.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "error: you have uncommitted changes. Commit or stash them first." >&2
    exit 1
fi

echo "==> Fetching upstream and origin"
git fetch upstream
git fetch origin

echo "==> Fast-forwarding main to upstream/main"
git checkout main
if ! git merge --ff-only upstream/main; then
    echo "error: main cannot fast-forward to upstream/main." >&2
    echo "main has commits that upstream does not. Keep PTT work on the ptt branch only." >&2
    exit 1
fi

echo "==> Pushing main to origin"
git push origin main

echo "==> Rebasing ptt on main"
git checkout ptt
if ! git rebase main; then
    echo "Conflicting files:"
    git diff --name-only --diff-filter=U
    echo "Resolve the conflicts (see Chorus/PTT/HOOKS.md: keep each PTT hook one line), then run: git rebase --continue && scripts/install-ptt.sh"
    exit 1
fi

echo "==> Pushing ptt to origin"
git push --force-with-lease origin ptt

echo "==> Installing"
scripts/install-ptt.sh
