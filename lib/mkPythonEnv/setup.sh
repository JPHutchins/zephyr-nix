set -euo pipefail

# Usage: python-env-setup [VENV_DIR] [PYLOCK_FILE]
# VENV_DIR: Where to create .venv (default: current directory)
# PYLOCK_FILE: Path to pylock.toml (default: ./pylock.toml)

VENV_DIR="${1:-.}"
PYLOCK_FILE="${2:-pylock.toml}"
VENV_PATH="$VENV_DIR/.venv"
PYTHON_VERSION="$pythonVersion"

# Create venv if it doesn't exist
if [ ! -d "$VENV_PATH" ]; then
  echo "📦 Creating Python $PYTHON_VERSION virtual environment at $VENV_PATH..."
  uv venv --python "$PYTHON_VERSION" --seed "$VENV_PATH"
fi

# Install from pylock.toml if it exists
if [ -f "$PYLOCK_FILE" ]; then
  echo "📥 Installing packages from $PYLOCK_FILE..."
  uv pip install --python "$VENV_PATH/bin/python" --requirement "$PYLOCK_FILE"
else
  echo "⚠️  No pylock.toml found at $PYLOCK_FILE"
  echo "   Run 'pylock' after installing packages to generate it"
fi

echo "✓ Python environment ready at $VENV_PATH"
echo "  Activate with: source $VENV_PATH/bin/activate"
