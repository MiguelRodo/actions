#!/usr/bin/env bash
set -euo pipefail

git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

if git ls-remote --heads origin gh-pages | grep -q gh-pages; then
  echo "gh-pages branch already exists"
  exit 0
fi

echo "Creating gh-pages branch"
current_branch=$(git rev-parse --abbrev-ref HEAD)
git checkout --orphan gh-pages
git rm -rf .
echo "# GitHub Pages" > README.md
git add README.md
git commit -m "Initialize gh-pages branch"
git push origin gh-pages
git checkout "$current_branch"
