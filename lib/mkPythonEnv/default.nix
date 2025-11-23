{ pkgs }:

{ workspaceRoot
, pythonVersion ? "3.12"
}:

pkgs.writeShellApplication {
  name = "python-env-setup";

  runtimeInputs = [
    pkgs.uv
  ];

  text = ''
    pythonVersion="${pythonVersion}"
    ${builtins.readFile ./setup.sh}
  '';
}
