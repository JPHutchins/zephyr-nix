#!/usr/bin/env bash
set -euo pipefail

# Helper script to get the hash for a new Zephyr SDK version

VERSION="${1:-}"

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 0.17.0"
    exit 1
fi

URL="https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${VERSION}/zephyr-sdk-${VERSION}_linux-x86_64_minimal.tar.xz"

echo "Fetching SDK version ${VERSION}..."
echo "URL: ${URL}"
echo ""

HASH=$(nix-prefetch-url --unpack "$URL")

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Add this to pkgs/zephyr-sdk/default.nix:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  sdkHash = {"
echo "    \"${VERSION}\" = \"sha256-${HASH}\";"
echo "  }.version or (throw \"Unsupported Zephyr SDK version: \${version}\");"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
