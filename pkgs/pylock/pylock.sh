#!/usr/bin/env bash
set -euo pipefail

# Generate pylock.toml from current Python virtual environment
# Usage: pylock [--output FILE]

OUTPUT="${1:-pylock.toml}"
CUSTOM_COMPILE_CMD="${CUSTOM_COMPILE_CMD:-nix develop}"

# Check that we're in a venv
if [ -z "${VIRTUAL_ENV:-}" ]; then
  echo "Error: Not in an active virtual environment" >&2
  echo "Please activate a venv first: source .venv/bin/activate" >&2
  exit 1
fi

# Create temporary requirements file
REQUIREMENTS_TMP=$(mktemp --suffix=.in)
trap 'rm -f "$REQUIREMENTS_TMP"' EXIT

echo "Freezing installed packages from $VIRTUAL_ENV..." >&2
uv pip freeze > "$REQUIREMENTS_TMP"

echo "Generating $OUTPUT..." >&2
uv pip compile "$REQUIREMENTS_TMP" \
  --format pylock.toml \
  --custom-compile-command "$CUSTOM_COMPILE_CMD" \
  -o "$OUTPUT"

echo "✓ Generated $OUTPUT" >&2
