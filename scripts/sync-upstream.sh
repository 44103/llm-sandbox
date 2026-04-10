#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_URL="https://github.com/imishinist/sandbox.git"

if ! git remote get-url upstream &>/dev/null; then
  echo "Adding upstream remote..."
  git remote add upstream "$UPSTREAM_URL"
fi

git fetch upstream
git merge upstream/main
