"""Tests for mkPythonEnv library function."""

import subprocess
import tempfile
from pathlib import Path
from typing import Final

from conftest import REPO_ROOT


FIXTURES_DIR: Final = Path(__file__).parent / "fixtures" / "mkPythonEnv"


def generate_pylock_toml(requirements_in: Path, output: Path, python_version: str = "3.12") -> None:
    """Generate a pylock.toml file from requirements.in using uv."""
    result = subprocess.run(
        [
            "uv", "pip", "compile",
            str(requirements_in),
            "--format", "pylock.toml",
            "-o", str(output),
            "--python-version", python_version,
            "--custom-compile-command", "nix develop",
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, f"Failed to generate pylock.toml: {result.stderr}"


def test_setup_without_pylock() -> None:
    """Test mkPythonEnv creates venv without pylock.toml."""
    with tempfile.TemporaryDirectory() as tmpdir:
        workspace_dir = Path(tmpdir) / "workspace"
        workspace_dir.mkdir()

        flake_content = f"""
{{
  inputs = {{
    zephyr-nix.url = "path:{REPO_ROOT}";
    nixpkgs.follows = "zephyr-nix/nixpkgs";
  }};

  outputs = {{ self, zephyr-nix, nixpkgs }}: {{
    packages.x86_64-linux.default = zephyr-nix.lib.x86_64-linux.mkPythonEnv {{
      workspaceRoot = ./.;
    }};
  }};
}}
"""
        (workspace_dir / "flake.nix").write_text(flake_content)

        result = subprocess.run(
            ["nix", "build", ".#default", "--out-link", "result-setup"],
            cwd=workspace_dir,
            capture_output=True,
            text=True,
            check=False,
        )

        assert result.returncode == 0, f"Build failed: {result.stderr}"

        setup_script = workspace_dir / "result-setup" / "bin" / "python-env-setup"
        result = subprocess.run(
            [str(setup_script), str(workspace_dir)],
            capture_output=True,
            text=True,
            check=False,
        )

        assert result.returncode == 0, f"Setup failed: {result.stderr}"

        venv_path = workspace_dir / ".venv"
        assert venv_path.exists()
        assert (venv_path / "bin" / "python").exists() or (venv_path / "bin" / "python3").exists()


def test_setup_with_pylock() -> None:
    """Test mkPythonEnv installs from pylock.toml."""
    with tempfile.TemporaryDirectory() as tmpdir:
        workspace_dir = Path(tmpdir) / "workspace"
        workspace_dir.mkdir()

        requirements_in = FIXTURES_DIR / "simple" / "requirements.in"
        pylock_path = workspace_dir / "pylock.toml"

        generate_pylock_toml(requirements_in, pylock_path, python_version="3.12")

        flake_content = f"""
{{
  inputs = {{
    zephyr-nix.url = "path:{REPO_ROOT}";
    nixpkgs.follows = "zephyr-nix/nixpkgs";
  }};

  outputs = {{ self, zephyr-nix, nixpkgs }}: {{
    packages.x86_64-linux.default = zephyr-nix.lib.x86_64-linux.mkPythonEnv {{
      workspaceRoot = ./.;
    }};
  }};
}}
"""
        (workspace_dir / "flake.nix").write_text(flake_content)

        result = subprocess.run(
            ["nix", "build", ".#default", "--out-link", "result-setup"],
            cwd=workspace_dir,
            capture_output=True,
            text=True,
            check=False,
        )

        assert result.returncode == 0

        setup_script = workspace_dir / "result-setup" / "bin" / "python-env-setup"
        result = subprocess.run(
            [str(setup_script), str(workspace_dir), str(pylock_path)],
            capture_output=True,
            text=True,
            check=False,
            timeout=120,
        )

        assert result.returncode == 0, f"Setup failed: {result.stderr}"

        venv_path = workspace_dir / ".venv"
        python_exe = venv_path / "bin" / "python"
        if not python_exe.exists():
            python_exe = venv_path / "bin" / "python3"

        result = subprocess.run(
            [str(python_exe), "-c", "import certifi"],
            capture_output=True,
            text=True,
            check=False,
        )

        assert result.returncode == 0, f"certifi not installed: {result.stderr}"


def test_python_version() -> None:
    """Test pythonVersion parameter."""
    with tempfile.TemporaryDirectory() as tmpdir:
        workspace_dir = Path(tmpdir) / "workspace"
        workspace_dir.mkdir()

        flake_content = f"""
{{
  inputs = {{
    zephyr-nix.url = "path:{REPO_ROOT}";
    nixpkgs.follows = "zephyr-nix/nixpkgs";
  }};

  outputs = {{ self, zephyr-nix, nixpkgs }}: {{
    packages.x86_64-linux.default = zephyr-nix.lib.x86_64-linux.mkPythonEnv {{
      workspaceRoot = ./.;
      pythonVersion = "3.11";
    }};
  }};
}}
"""
        (workspace_dir / "flake.nix").write_text(flake_content)

        result = subprocess.run(
            ["nix", "build", ".#default", "--out-link", "result-setup"],
            cwd=workspace_dir,
            capture_output=True,
            text=True,
            check=False,
        )

        assert result.returncode == 0

        setup_script = workspace_dir / "result-setup" / "bin" / "python-env-setup"
        result = subprocess.run(
            [str(setup_script), str(workspace_dir)],
            capture_output=True,
            text=True,
            check=False,
            timeout=120,
        )

        assert result.returncode == 0

        venv_path = workspace_dir / ".venv"
        python_exe = venv_path / "bin" / "python"
        if not python_exe.exists():
            python_exe = venv_path / "bin" / "python3"

        result = subprocess.run(
            [str(python_exe), "--version"],
            capture_output=True,
            text=True,
            check=False,
        )

        assert result.returncode == 0
        assert "3.11" in result.stdout
