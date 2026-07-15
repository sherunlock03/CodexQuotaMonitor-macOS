#!/usr/bin/env bash
set -euo pipefail

# Some Command Line Tools updates can briefly leave the Swift driver and SDK
# one patch version apart. The build scripts set this value only when needed.
REAL_SWIFTC="$(xcrun --find swiftc)"
if [[ -n "${CODEX_SWIFT_INTERFACE_VERSION:-}" ]]; then
    exec "$REAL_SWIFTC" \
        -Xfrontend -interface-compiler-version -Xfrontend "$CODEX_SWIFT_INTERFACE_VERSION" \
        "$@"
fi
exec "$REAL_SWIFTC" "$@"
