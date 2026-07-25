#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# init.sh — one-time local setup: creates a Python venv at .venv, installs
# pre-commit into it, and registers the git hook (.pre-commit-config.yaml).
# Safe to re-run — creating an already-existing .venv is a no-op, and
# `pre-commit install` just overwrites the existing hook.
#
# Uses .venv/bin/pip and .venv/bin/pre-commit directly rather than `source
# .venv/bin/activate` first: activation only changes the CURRENT shell, which
# doesn't persist once this script's subshell exits, so calling the venv's
# binaries by their full path is what actually works from inside a script.
# You still need to `source .venv/bin/activate` yourself afterwards for
# everyday manual use (e.g. to get `pre-commit` on your PATH directly).
#
# Usage: run once from the repo root:
#   ./scripts/init.sh
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/.."
VENV_DIR="$REPO_ROOT/.venv"

command -v python3 >/dev/null 2>&1 || { echo "::error:: python3 not found in PATH." >&2; exit 1; }

if [ ! -d "$VENV_DIR" ]; then
  echo "→ Creating venv at $VENV_DIR ..."
  python3 -m venv "$VENV_DIR"
else
  echo "→ Venv already exists at $VENV_DIR, reusing it."
fi

echo "→ Installing/upgrading pre-commit ..."
"$VENV_DIR/bin/pip" install --upgrade pip pre-commit --quiet

echo "→ Registering the pre-commit git hook ..."
(cd "$REPO_ROOT" && "$VENV_DIR/bin/pre-commit" install)

echo
echo "Done. For everyday use, activate the venv in your shell:"
echo "  source .venv/bin/activate"
echo
echo "The git hook is already active regardless (pre-commit runs it via"
echo "$VENV_DIR/bin/pre-commit, no activation needed for that part)."
