#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SDK_PATH="$(xcrun --show-sdk-path)"
MODULE_CACHE="$ROOT_DIR/.build/module-cache"
GENERATOR="$ROOT_DIR/.build/GenerateAppIcon"
ICONSET="$ROOT_DIR/Resources/AppIcon.iconset"
mkdir -p "$MODULE_CACHE" "$ICONSET"

SWIFTC="$(xcrun --find swiftc)"
if [[ -n "${CODEX_SWIFT_INTERFACE_VERSION:-}" ]]; then
    SWIFTC="$ROOT_DIR/scripts/swiftc_compat.sh"
fi

"$SWIFTC" \
    -sdk "$SDK_PATH" \
    -module-cache-path "$MODULE_CACHE" \
    "$ROOT_DIR/scripts/GenerateAppIcon.swift" \
    -o "$GENERATOR"
"$GENERATOR" "$ICONSET" "$ROOT_DIR/Resources/AppIcon.icns"
