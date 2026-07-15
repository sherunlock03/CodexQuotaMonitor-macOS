#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

SDK_PATH="$(xcrun --show-sdk-path)"
SDK_INTERFACE="$(find "$SDK_PATH/usr/lib/swift/Swift.swiftmodule" -name '*-apple-macos.swiftinterface' -print -quit)"
COMPILER_VERSION="$(swiftc --version | sed -n 's/.*Apple Swift version \([0-9.]*\).*/\1/p' | head -1)"
SDK_VERSION="$(sed -n 's/.*Apple Swift version \([0-9.]*\).*/\1/p' "$SDK_INTERFACE" | head -1)"

export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT_DIR/.build/module-cache"
mkdir -p "$CLANG_MODULE_CACHE_PATH"

if [[ -n "$SDK_VERSION" && "$COMPILER_VERSION" != "$SDK_VERSION" ]]; then
    export CODEX_SWIFT_INTERFACE_VERSION="$SDK_VERSION"
    export SWIFT_EXEC="$ROOT_DIR/scripts/swiftc_compat.sh"
fi

"$ROOT_DIR/scripts/generate_icon.sh"

COMMON_BUILD_ARGS=(
    --disable-sandbox
    -c release
    -Xswiftc -module-cache-path
    -Xswiftc "$CLANG_MODULE_CACHE_PATH"
)
ARM_BUILD_ARGS=("${COMMON_BUILD_ARGS[@]}" --scratch-path "$ROOT_DIR/.swiftpm-build/arm64" --arch arm64)
INTEL_BUILD_ARGS=("${COMMON_BUILD_ARGS[@]}" --scratch-path "$ROOT_DIR/.swiftpm-build/x86_64" --arch x86_64)

swift build "${ARM_BUILD_ARGS[@]}" --product CodexQuotaMonitor
swift build "${INTEL_BUILD_ARGS[@]}" --product CodexQuotaMonitor
ARM_BIN_DIR="$(swift build "${ARM_BUILD_ARGS[@]}" --show-bin-path)"
INTEL_BIN_DIR="$(swift build "${INTEL_BUILD_ARGS[@]}" --show-bin-path)"
APP_DIR="$ROOT_DIR/dist/CodexQuotaMonitor.app"
STAGING_ROOT="$(mktemp -d /tmp/CodexQuotaMonitor-build.XXXXXX)"
STAGING_APP="$STAGING_ROOT/CodexQuotaMonitor.app"
trap 'rm -rf "$STAGING_ROOT"' EXIT

mkdir -p "$STAGING_APP/Contents/MacOS" "$STAGING_APP/Contents/Resources"
lipo -create \
    "$ARM_BIN_DIR/CodexQuotaMonitor" \
    "$INTEL_BIN_DIR/CodexQuotaMonitor" \
    -output "$STAGING_APP/Contents/MacOS/CodexQuotaMonitor"
cp "$ROOT_DIR/Resources/Info.plist" "$STAGING_APP/Contents/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$STAGING_APP/Contents/Resources/AppIcon.icns"
chmod +x "$STAGING_APP/Contents/MacOS/CodexQuotaMonitor"
xattr -cr "$STAGING_APP"

if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$STAGING_APP"
fi

xattr -cr "$STAGING_APP"
rm -rf "$APP_DIR"
ditto "$STAGING_APP" "$APP_DIR"
# File-provider-backed Documents folders may attach Finder metadata to the
# copied bundle; clear it without changing the already-created signature.
xattr -cr "$APP_DIR"

echo "Built: $APP_DIR"
