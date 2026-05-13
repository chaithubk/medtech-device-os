#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v actionlint >/dev/null 2>&1; then
  echo "error: actionlint is not installed or not on PATH" >&2
  echo "hint: rebuild dev container or install via .github/actions/lint-workflows logic" >&2
  exit 1
fi

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "error: shellcheck is not installed or not on PATH" >&2
  echo "hint: install shellcheck locally so actionlint can lint workflow run scripts" >&2
  exit 1
fi

echo "==> Running actionlint"
actionlint -color -shellcheck "$(command -v shellcheck)"

echo "CI workflow lint checks passed."
