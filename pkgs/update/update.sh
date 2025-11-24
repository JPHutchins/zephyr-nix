#!/usr/bin/env bash
set -euo pipefail

# update - Update westlock.nix and pylock.toml for Zephyr projects
# Usage: update [OPTIONS] [manifest-file]
#
# Options:
#   --westlock PATH    Output path for westlock.nix (default: westlock.nix)
#   --pylock PATH      Output path for pylock.toml (default: pylock.toml)
#   --venv PATH        Existing venv path to reuse (optional, creates temp if not specified)
#   --python-version V Python version for pylock.toml (default: 3.12)
#   --verbose          Show detailed progress messages
#   --help             Show this help message
#
# Arguments:
#   manifest-file      West manifest file (default: west.yml or west.yaml)

WESTLOCK_PATH="westlock.nix"
PYLOCK_PATH="pylock.toml"
VENV_PATH=""
PYTHON_VERSION="3.12"
MANIFEST_FILE=""
VERBOSE=false

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
    --python-version)
      PYTHON_VERSION="$2"
      shift 2
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      sed -n '3,15p' "$0" | sed 's/^# //'
      exit 0
      ;;
    -*)
      echo "Error: Unknown option: $1" >&2
      echo "Run 'update --help' for usage information" >&2
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

# Default to west.yml or west.yaml if not specified
if [ -z "$MANIFEST_FILE" ]; then
  if [ -f "west.yml" ]; then
    MANIFEST_FILE="west.yml"
  elif [ -f "west.yaml" ]; then
    MANIFEST_FILE="west.yaml"
  else
    echo "Error: No manifest file found" >&2
    echo "Looked for: west.yml, west.yaml" >&2
    echo "Run 'update --help' for usage information" >&2
    exit 1
  fi
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

# Will be set after creating workspace
WEST_WORKSPACE=""

# Logging helpers
log() {
  if [ "$VERBOSE" = true ]; then
    echo "$@" >&2
  fi
}

# Cleanup function
cleanup() {
  if [ -n "$WEST_WORKSPACE" ]; then
    log "Cleaning up temporary workspace at $WEST_WORKSPACE..."
    rm -rf "$WEST_WORKSPACE"
  fi
  if [ "$CLEANUP_VENV" = true ]; then
    log "Cleaning up temporary venv at $VENV_PATH..."
    rm -rf "$VENV_PATH"
  fi
}
trap cleanup EXIT

# Step 1: Resolve absolute path to manifest before any directory changes
MANIFEST_FILE_ABS="$(realpath "$MANIFEST_FILE")"

# Step 2: Generate westlock.nix
log "Generating $WESTLOCK_PATH from $MANIFEST_FILE..."
westupdate "$MANIFEST_FILE_ABS" > "$WESTLOCK_PATH"
log "✓ Generated $WESTLOCK_PATH"

# Step 3: Create venv if it doesn't exist or is invalid
if [ ! -d "$VENV_PATH" ] || [ ! -f "$VENV_PATH/bin/activate" ]; then
  log "Creating Python venv at $VENV_PATH..."
  uv venv --seed "$VENV_PATH" 2>&1 | while read -r line; do log "$line"; done
else
  log "Reusing existing venv at $VENV_PATH..."
fi

# Step 4: Activate venv and install west
log "Installing west in venv..."
# shellcheck disable=SC1091
source "$VENV_PATH/bin/activate"
uv pip install west 2>&1 | while read -r line; do log "$line"; done

# Step 5: Initialize west workspace
# Create a temporary workspace directory
WEST_WORKSPACE=$(mktemp -d --suffix=-west-workspace)

log "Initializing west workspace in $WEST_WORKSPACE..."
pushd "$WEST_WORKSPACE" > /dev/null 2>&1

# Copy manifest to workspace and initialize
cp "$MANIFEST_FILE_ABS" west.yml
west init -l . 2>&1 | while read -r line; do log "$line"; done

# Update to clone all repositories
log "Cloning west repositories (this may take a while)..."
west update 2>&1 | while read -r line; do log "$line"; done

# Step 5: Install west packages
log "Installing Python dependencies from west workspace..."
west packages pip --install 2>&1 | while read -r line; do log "$line"; done
log "✓ Installed west packages"

popd > /dev/null 2>&1

# Step 6: Generate pylock.toml
log "Generating $PYLOCK_PATH..."
REQUIREMENTS_TMP=$(mktemp --suffix=.in)
trap 'rm -f "$REQUIREMENTS_TMP"; cleanup' EXIT

log "Freezing installed packages..."
uv pip freeze > "$REQUIREMENTS_TMP" 2>&1 | while read -r line; do log "$line"; done

log "Compiling pylock.toml..."
uv pip compile "$REQUIREMENTS_TMP" \
  --python-version "$PYTHON_VERSION" \
  --format pylock.toml \
  --custom-compile-command "nix run github:JPHutchins/zephyr-nix#update" \
  -o "$PYLOCK_PATH" 2>&1 | while read -r line; do log "$line"; done

log "✓ Generated $PYLOCK_PATH"
echo "Updated: $WESTLOCK_PATH, $PYLOCK_PATH"
