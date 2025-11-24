{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
, which
, ncurses
, python310
, libxcrypt-legacy
, architectures ? [ "arm" ]
, version ? "0.17.4"
}:

let
  # Map friendly architecture names to Zephyr SDK toolchain names
  archMap = {
    arm = "arm-zephyr-eabi";
    riscv64 = "riscv64-zephyr-elf";
    x86_64 = "x86_64-zephyr-elf";
    xtensa-esp32 = "xtensa-espressif_esp32_zephyr_elf";
    xtensa-esp32s2 = "xtensa-espressif_esp32s2_zephyr_elf";
    xtensa-esp32s3 = "xtensa-espressif_esp32s3_zephyr_elf";
    arc = "arc-zephyr-elf";
    arc64 = "arc64-zephyr-elf";
    mips = "mips-zephyr-elf";
    nios2 = "nios2-zephyr-elf";
    sparc = "sparc-zephyr-elf";
  };

  # Normalize architecture names
  normalizedArchs = map (arch: archMap.${arch} or arch) architectures;

  # Host platform string for downloads (currently only supports Linux x86_64)
  hostPlatform = "linux-x86_64";

  # Base URL for downloads
  baseUrl = "https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${version}";

  # Minimal SDK contains setup scripts and CMake configs
  minimalSdk = fetchurl {
    url = "${baseUrl}/zephyr-sdk-${version}_${hostPlatform}_minimal.tar.xz";
    sha256 = {
      "1.0.0-beta1" = "sha256-x38xbm4EMoNo20w1y8iXtluAmTSUhY5Fzec+lvVhCVw=";
      "0.17.4" = "sha256-pyWL9QyJLEZpcSsqrN/NXjAyRbzzbLRYopYDmmZFlPU=";
      "0.17.3" = "sha256-Vbv0qgG+Qqe9GSnpLiJ/e6J8HDmn7Cs+GUNgQeFoPLo=";
    }.${version} or (throw "Unsupported Zephyr SDK version: ${version}");
  };

  # Note: Host tools are included in the minimal SDK as a self-extracting script
  # We'll run that script during installation instead of downloading separately

  # Toolchain hashes - indexed by version, then toolchain name
  toolchainHashes = {
    "0.17.4" = {
      "arm-zephyr-eabi" = "sha256-G2EIT+EgdqNjmqLQKLUlj0HrPQ99RqFiZJSeHSE/GRU=";
      "riscv64-zephyr-elf" = "sha256-RZlVmTeNsHDlzDhJ8y+EvSFNmIRNjtypPhPNctLbxQw=";
    };
    "0.17.3" = {
      "arm-zephyr-eabi" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # TODO: fetch if needed
    };
  };

  # Fetch a single toolchain
  fetchToolchain = arch: fetchurl {
    url = "${baseUrl}/toolchain_${hostPlatform}_${arch}.tar.xz";
    sha256 = toolchainHashes.${version}.${arch}
      or (throw "Hash not available for toolchain ${arch} version ${version}");
  };

  # All toolchain downloads (only if architectures are specified)
  toolchainTarballs = if architectures == [] then [] else map fetchToolchain normalizedArchs;

in
stdenv.mkDerivation rec {
  pname = "zephyr-sdk";
  inherit version;

  # Use a dummy src to satisfy stdenv
  src = minimalSdk;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    which  # Needed by host tools self-extracting script
    python310  # Needed by host tools self-extracting script
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    ncurses
    python310
    libxcrypt-legacy
  ];

  unpackPhase = ''
    runHook preUnpack

    tar xf $src
    cd zephyr-sdk-*

    ${lib.concatMapStringsSep "\n" (tarball: "tar xf ${tarball}") toolchainTarballs}

    chmod +x ./zephyr-sdk-*-hosttools-standalone-*.sh
    ./zephyr-sdk-*-hosttools-standalone-*.sh -y -d .
    rm -f ./zephyr-sdk-*-hosttools-standalone-*.sh

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -r * "$out/"

    cat > "$out/environment-setup-zephyr.sh" <<'EOF'
#!/bin/sh
export ZEPHYR_SDK_INSTALL_DIR="$out"
export ZEPHYR_TOOLCHAIN_VARIANT="zephyr"
export CMAKE_PREFIX_PATH="$out/cmake:''${CMAKE_PREFIX_PATH:-}"
EOF
    chmod +x "$out/environment-setup-zephyr.sh"

    runHook postInstall
  '';

  dontBuild = true;
  dontStrip = true;

  postFixup = ''
    # Patch shebangs in all scripts
    patchShebangs "$out"
  '';

  meta = with lib; {
    description = "Zephyr SDK - Cross-compilation toolchains for Zephyr RTOS";
    longDescription = ''
      The Zephyr SDK contains toolchains for cross-compiling Zephyr applications
      for various architectures. This package includes only the selected architectures
      to minimize download size and build time.
    '';
    homepage = "https://github.com/zephyrproject-rtos/sdk-ng";
    license = licenses.asl20;
    platforms = [ "x86_64-linux" ];
    maintainers = with maintainers; [ ];
  };
}
