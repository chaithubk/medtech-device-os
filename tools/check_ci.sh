#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v actionlint >/dev/null 2>&1; then
  echo "error: actionlint is not installed or not on PATH" >&2
  echo "hint: rebuild dev container or install via .github/actions/lint-workflows logic" >&2
  exit 1
fi

echo "==> Running actionlint"
actionlint -color

echo "CI workflow lint checks passed."
