"""Tests for pylock tool."""

import subprocess
import tempfile
from pathlib import Path
from typing import Final

import pytest

from conftest import REPO_ROOT


FIXTURES_DIR: Final = Path(__file__).parent / "fixtures" / "pylock"


@pytest.fixture(scope="session")
def build_pylock() -> Path:
    """Build pylock once per test session.

    Returns the path to the pylock executable.
    """
    print("\nBuilding pylock with Nix...")
    result = subprocess.run(
        ["nix", "build", ".#pylock", "--out-link", "result-pylock"],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )

    if result.returncode != 0:
        pytest.fail(
            f"Failed to build pylock:\n"
            f"stdout: {result.stdout}\n"
            f"stderr: {result.stderr}"
        )

    pylock_exe = REPO_ROOT / "result-pylock/bin/pylock"
    if not pylock_exe.exists():
        pytest.fail(f"Executable not found after build: {pylock_exe}")

    return pylock_exe


def test_pylock_requires_venv(build_pylock: Path) -> None:
    """Test that pylock fails gracefully when not in a venv."""
    result = subprocess.run(
        [str(build_pylock)],
        capture_output=True,
        text=True,
        check=False,
        env={"PATH": "/usr/bin:/bin"},  # Clear VIRTUAL_ENV
    )

    assert result.returncode != 0, "Expected pylock to fail outside venv"
    assert "Not in an active virtual environment" in result.stderr


def test_pylock_generates_from_venv(build_pylock: Path) -> None:
    """Test that pylock generates a valid pylock.toml from a venv."""
    with tempfile.TemporaryDirectory() as tmpdir:
        workspace_dir = Path(tmpdir)

        # Create a venv
        result = subprocess.run(
            ["uv", "venv", ".venv"],
            cwd=workspace_dir,
            capture_output=True,
            text=True,
            check=False,
        )
        assert result.returncode == 0, f"Failed to create venv: {result.stderr}"

        # Install a simple package into the venv
        venv_path = workspace_dir / ".venv"
        result = subprocess.run(
            ["uv", "pip", "install", "--python", str(venv_path / "bin" / "python"), "certifi"],
            cwd=workspace_dir,
            capture_output=True,
            text=True,
            check=False,
        )
        assert result.returncode == 0, f"Failed to install certifi: {result.stderr}"

        # Run pylock
        pylock_output = workspace_dir / "pylock.toml"

        result = subprocess.run(
            [str(build_pylock), str(pylock_output)],
            cwd=workspace_dir,
            capture_output=True,
            text=True,
            check=False,
            env={
                "VIRTUAL_ENV": str(venv_path),
                "PATH": f"{venv_path}/bin:/usr/bin:/bin",
            },
        )

        assert result.returncode == 0, (
            f"pylock failed:\n"
            f"stderr: {result.stderr}\n"
            f"stdout: {result.stdout}"
        )

        # Verify pylock.toml was created
        assert pylock_output.exists(), "pylock.toml was not created"

        # Verify it's valid TOML and contains expected content
        content = pylock_output.read_text()
        assert "lock-version" in content, "Missing lock-version field"
        assert "requires-python" in content, "Missing requires-python field"
        assert "[[packages]]" in content, "Missing [[packages]] section"
        assert "certifi" in content.lower(), "Missing certifi package"


def test_pylock_output_is_deterministic(build_pylock: Path) -> None:
    """Test that pylock produces the same output for the same venv."""
    with tempfile.TemporaryDirectory() as tmpdir:
        workspace_dir = Path(tmpdir)

        # Create venv and install packages
        result = subprocess.run(
            ["uv", "venv", ".venv"],
            cwd=workspace_dir,
            capture_output=True,
            text=True,
            check=False,
        )
        assert result.returncode == 0

        venv_path = workspace_dir / ".venv"
        result = subprocess.run(
            ["uv", "pip", "install", "--python", str(venv_path / "bin" / "python"), "certifi"],
            cwd=workspace_dir,
            capture_output=True,
            text=True,
            check=False,
        )
        assert result.returncode == 0

        env = {
            "VIRTUAL_ENV": str(venv_path),
            "PATH": f"{venv_path}/bin:/usr/bin:/bin",
        }

        # Generate pylock.toml twice (must use pylock.*.toml naming)
        pylock1 = workspace_dir / "pylock.test1.toml"
        pylock2 = workspace_dir / "pylock.test2.toml"

        for output in [pylock1, pylock2]:
            result = subprocess.run(
                [str(build_pylock), str(output)],
                cwd=workspace_dir,
                capture_output=True,
                text=True,
                check=False,
                env=env,
            )
            assert result.returncode == 0

        # Compare outputs (should be identical)
        content1 = pylock1.read_text()
        content2 = pylock2.read_text()

        assert content1 == content2, (
            "pylock output is not deterministic:\n"
            f"First run:\n{content1}\n"
            f"Second run:\n{content2}"
        )
