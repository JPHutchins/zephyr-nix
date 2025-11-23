"""Integration tests for mkZephyrEnv - validates complete environment setup."""

import subprocess
from pathlib import Path

from conftest import REPO_ROOT


def test_mkZephyrEnv_evaluates() -> None:
    """Test that mkZephyrEnv with required params evaluates successfully."""
    result = subprocess.run(
        [
            "nix", "eval", f"{REPO_ROOT}#lib.x86_64-linux.mkZephyrEnv",
            "--apply", 'f: (f { sdkVersion = "0.17.4"; architectures = ["arm"]; }).name',
        ],
        capture_output=True,
        text=True,
        check=False,
        timeout=60,
    )

    assert result.returncode == 0, f"Eval failed: {result.stderr}"
    assert "zephyr-env-0.17.4" in result.stdout, f"Unexpected name: {result.stdout}"


def test_mkZephyrEnv_has_setup_script() -> None:
    """Test that mkZephyrEnv includes the setup script."""
    result = subprocess.run(
        [
            "nix", "eval", f"{REPO_ROOT}#lib.x86_64-linux.mkZephyrEnv",
            "--apply", 'f: (f { sdkVersion = "0.17.4"; architectures = ["arm"]; }).passthru.setupScript.name',
        ],
        capture_output=True,
        text=True,
        check=False,
        timeout=60,
    )

    assert result.returncode == 0, f"Eval failed: {result.stderr}"
    assert "zephyr-env-setup" in result.stdout, f"Setup script not found: {result.stdout}"


def test_mkZephyrEnv_passthru_attributes() -> None:
    """Test that passthru attributes are accessible."""
    result = subprocess.run(
        [
            "nix", "eval", f"{REPO_ROOT}#lib.x86_64-linux.mkZephyrEnv",
            "--apply", 'f: (f { sdkVersion = "0.17.4"; architectures = ["arm"]; }).passthru.sdkVersion',
        ],
        capture_output=True,
        text=True,
        check=False,
        timeout=60,
    )

    assert result.returncode == 0, f"Eval failed: {result.stderr}"
    assert "0.17.4" in result.stdout, f"Unexpected SDK version: {result.stdout}"


def test_mkZephyrEnv_with_architectures() -> None:
    """Test that mkZephyrEnv respects architecture parameter."""
    result = subprocess.run(
        [
            "nix", "eval", f"{REPO_ROOT}#lib.x86_64-linux.mkZephyrEnv",
            "--apply", 'f: (f { sdkVersion = "0.17.4"; architectures = ["arm" "riscv64"]; }).name',
        ],
        capture_output=True,
        text=True,
        check=False,
        timeout=60,
    )

    assert result.returncode == 0, f"Eval failed: {result.stderr}"
    assert "zephyr-env" in result.stdout


def test_mkZephyrEnv_custom_workspace_root() -> None:
    """Test that workspaceRoot parameter is accessible via passthru."""
    result = subprocess.run(
        [
            "nix", "eval", f"{REPO_ROOT}#lib.x86_64-linux.mkZephyrEnv",
            "--apply", 'f: (f { sdkVersion = "0.17.4"; architectures = ["arm"]; workspaceRoot = ".custom-zephyr"; }).passthru.workspaceRoot',
        ],
        capture_output=True,
        text=True,
        check=False,
        timeout=60,
    )

    assert result.returncode == 0, f"Eval failed: {result.stderr}"
    assert ".custom-zephyr" in result.stdout, f"Workspace root not reflected: {result.stdout}"


def test_west_nix_functions_reexported() -> None:
    """Test that west-nix functions are available through zephyr-nix."""
    functions_to_check = ["mkWestProjects", "mkWestWorkspace", "mkWestProject"]

    result = subprocess.run(
        [
            "nix", "eval", f"{REPO_ROOT}#lib.x86_64-linux",
            "--apply", "lib: builtins.attrNames lib",
            "--json",
        ],
        capture_output=True,
        text=True,
        check=False,
        timeout=60,
    )

    assert result.returncode == 0, f"Eval failed: {result.stderr}"

    import json
    available_functions = json.loads(result.stdout)

    for func in functions_to_check:
        assert func in available_functions, f"Function {func} not re-exported"


def test_mkZephyrEnv_custom_ccache_size() -> None:
    """Test that ccacheMaxSize parameter is accessible via passthru."""
    result = subprocess.run(
        [
            "nix", "eval", f"{REPO_ROOT}#lib.x86_64-linux.mkZephyrEnv",
            "--apply", 'f: (f { sdkVersion = "0.17.4"; architectures = ["arm"]; ccacheMaxSize = "1G"; }).passthru.ccacheMaxSize',
        ],
        capture_output=True,
        text=True,
        check=False,
        timeout=60,
    )

    assert result.returncode == 0, f"Eval failed: {result.stderr}"
    assert "1G" in result.stdout


def test_mkZephyrEnv_python_version() -> None:
    """Test that pythonVersion parameter is accessible via passthru."""
    result = subprocess.run(
        [
            "nix", "eval", f"{REPO_ROOT}#lib.x86_64-linux.mkZephyrEnv",
            "--apply", 'f: (f { sdkVersion = "0.17.4"; architectures = ["arm"]; pythonVersion = "3.11"; }).passthru.pythonVersion',
        ],
        capture_output=True,
        text=True,
        check=False,
        timeout=60,
    )

    assert result.returncode == 0, f"Eval failed: {result.stderr}"
    assert "3.11" in result.stdout, f"Python version not passed through: {result.stdout}"


def test_all_lib_functions_present() -> None:
    """Test that all expected lib functions are available."""
    expected_functions = [
        "mkZephyrEnv",
        "mkZephyrDependencies",
        "mkPythonEnv",
        "mkCrossCCache",
        "mkWestProjects",
        "mkWestWorkspace",
        "mkWestProject",
    ]

    result = subprocess.run(
        [
            "nix", "eval", f"{REPO_ROOT}#lib.x86_64-linux",
            "--apply", "lib: builtins.attrNames lib",
            "--json",
        ],
        capture_output=True,
        text=True,
        check=False,
        timeout=60,
    )

    assert result.returncode == 0, f"Eval failed: {result.stderr}"

    import json
    available_functions = json.loads(result.stdout)

    for func in expected_functions:
        assert func in available_functions, f"Expected function {func} not found"

    assert len(available_functions) == len(expected_functions), \
        f"Unexpected functions found: {set(available_functions) - set(expected_functions)}"
