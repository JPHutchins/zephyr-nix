#!/usr/bin/env bash
set -euo pipefail

# zephyr-nix-update - Update westlock.nix and pylock.toml for Zephyr projects
# Usage: zephyr-nix-update [OPTIONS] <manifest-file>
#
# Options:
#   --westlock PATH    Output path for westlock.nix (default: westlock.nix)
#   --pylock PATH      Output path for pylock.toml (default: pylock.toml)
#   --venv PATH        Existing venv path to reuse (optional, creates temp if not specified)
#   --help             Show this help message

WESTLOCK_PATH="westlock.nix"
PYLOCK_PATH="pylock.toml"
VENV_PATH=""
MANIFEST_FILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --westlock)
      WESTLOCK_PATH="$2"
      shift 2
      ;;
    --pylock)
      PYLOCK_PATH="$2"
      shift 2
      ;;
    --venv)
      VENV_PATH="$2"
      shift 2
      ;;
    --help)
      sed -n '3,11p' "$0" | sed 's/^# //'
      exit 0
      ;;
    -*)
      echo "Error: Unknown option: $1" >&2
      echo "Run 'zephyr-nix-update --help' for usage information" >&2
      exit 1
      ;;
    *)
      if [ -n "$MANIFEST_FILE" ]; then
        echo "Error: Multiple manifest files specified" >&2
        exit 1
      fi
      MANIFEST_FILE="$1"
      shift
      ;;
  esac
done

# Validate manifest file
if [ -z "$MANIFEST_FILE" ]; then
  echo "Error: No manifest file specified" >&2
  echo "Usage: zephyr-nix-update [OPTIONS] <manifest-file>" >&2
  echo "Run 'zephyr-nix-update --help' for more information" >&2
  exit 1
fi

if [ ! -f "$MANIFEST_FILE" ]; then
  echo "Error: Manifest file not found: $MANIFEST_FILE" >&2
  exit 1
fi

# Determine venv path and cleanup strategy
if [ -z "$VENV_PATH" ]; then
  # No venv specified - create transient one in /tmp
  VENV_PATH=$(mktemp -d --suffix=-zephyr-nix-update-venv)
  CLEANUP_VENV=true
else
  # User specified venv - reuse if exists, don't cleanup
  CLEANUP_VENV=false
fi

# Cleanup function
cleanup() {
  if [ "$CLEANUP_VENV" = true ]; then
    echo "Cleaning up temporary venv at $VENV_PATH..." >&2
    rm -rf "$VENV_PATH"
  fi
}
trap cleanup EXIT

# Step 1: Generate westlock.nix
echo "Generating $WESTLOCK_PATH from $MANIFEST_FILE..." >&2
westupdate "$MANIFEST_FILE" > "$WESTLOCK_PATH"
echo "✓ Generated $WESTLOCK_PATH" >&2

# Step 2: Create venv if it doesn't exist
if [ ! -d "$VENV_PATH" ]; then
  echo "Creating Python venv at $VENV_PATH..." >&2
  uv venv --seed "$VENV_PATH"
else
  echo "Reusing existing venv at $VENV_PATH..." >&2
fi

# Step 3: Activate venv and install west
echo "Installing west in venv..." >&2
source "$VENV_PATH/bin/activate"
uv pip install west

# Step 4: Install west packages
echo "Installing Python dependencies from west manifest..." >&2
if west packages pip --install 2>&1 | grep -q "No pip packages to install"; then
  echo "No pip packages specified in manifest" >&2
else
  echo "✓ Installed west packages" >&2
fi

# Step 5: Generate pylock.toml
echo "Generating $PYLOCK_PATH..." >&2
REQUIREMENTS_TMP=$(mktemp --suffix=.in)
trap 'rm -f "$REQUIREMENTS_TMP"; cleanup' EXIT

uv pip freeze > "$REQUIREMENTS_TMP"

uv pip compile "$REQUIREMENTS_TMP" \
  --format pylock.toml \
  --custom-compile-command "nix run github:JPHutchins/zephyr-nix#zephyr-nix-update $MANIFEST_FILE" \
  -o "$PYLOCK_PATH"

echo "✓ Generated $PYLOCK_PATH" >&2
echo "" >&2
echo "Successfully updated:" >&2
echo "  - $WESTLOCK_PATH" >&2
echo "  - $PYLOCK_PATH" >&2
