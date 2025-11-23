# zephyr-nix Tests

Test suite for zephyr-nix library functions.

## Setup

```bash
cd tests
uv venv
source .venv/bin/activate
uv pip install -e .
```

## Running Tests

```bash
# Run all tests
pytest

# Run specific test file
pytest test_mkPythonEnv.py

# Run with verbose output
pytest -v

# Run specific test
pytest test_mkPythonEnv.py::test_bootstrap_mode_no_pylock
```

## Test Structure

- `conftest.py` - Shared pytest configuration and fixtures
- `test_mkPythonEnv.py` - Tests for the mkPythonEnv library function
- `fixtures/` - Test fixtures and sample files

## Test Coverage

### mkPythonEnv

- **Bootstrap mode**: Verifies that `mkPythonEnv` returns just `uv` when no `pylock.toml` exists
- **Build from pylock**: Validates building a complete venv from a `pylock.toml` file
- **Python version**: Tests that the `pythonVersion` parameter is respected
- **Caching**: Ensures identical `pylock.toml` files produce the same derivation (content-addressed caching)
