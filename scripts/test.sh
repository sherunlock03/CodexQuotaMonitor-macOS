#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SDK_PATH="$(xcrun --show-sdk-path)"
SDK_INTERFACE="$(find "$SDK_PATH/usr/lib/swift/Swift.swiftmodule" -name '*-apple-macos.swiftinterface' -print -quit)"
COMPILER_VERSION="$(swiftc --version | sed -n 's/.*Apple Swift version \([0-9.]*\).*/\1/p' | head -1)"
SDK_VERSION="$(sed -n 's/.*Apple Swift version \([0-9.]*\).*/\1/p' "$SDK_INTERFACE" | head -1)"
MODULE_CACHE="$ROOT_DIR/.build/module-cache"
TEST_BINARY="$ROOT_DIR/.build/CodexQuotaSelfTest"
mkdir -p "$MODULE_CACHE"

SWIFTC="$(xcrun --find swiftc)"
if [[ -n "$SDK_VERSION" && "$COMPILER_VERSION" != "$SDK_VERSION" ]]; then
    export CODEX_SWIFT_INTERFACE_VERSION="$SDK_VERSION"
    SWIFTC="$ROOT_DIR/scripts/swiftc_compat.sh"
fi

"$SWIFTC" \
    -sdk "$SDK_PATH" \
    -module-cache-path "$MODULE_CACHE" \
    "$ROOT_DIR/Sources/CodexQuotaMonitor/Models.swift" \
    "$ROOT_DIR/Sources/CodexQuotaMonitor/QuotaParser.swift" \
    "$ROOT_DIR/Sources/CodexQuotaMonitor/UsageAnalyticsService.swift" \
    "$ROOT_DIR/Tests/SelfTest/main.swift" \
    -o "$TEST_BINARY"

"$TEST_BINARY"
