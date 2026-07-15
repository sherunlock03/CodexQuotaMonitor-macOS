# Codex Quota Monitor for macOS

**English** | [简体中文](README.md)

A lightweight, native macOS monitor for Codex usage limits. It lives in the menu bar and provides a standalone dashboard for five-hour and weekly quotas, reset times, token activity, and usage trends.

![macOS](https://img.shields.io/badge/macOS-13%2B-111827?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.10%2B-F05138?logo=swift&logoColor=white)
![Universal 2](https://img.shields.io/badge/Universal_2-Apple_Silicon_%7C_Intel-2563EB)
![License](https://img.shields.io/badge/License-MIT-16A34A)

## Preview

![Codex quota dashboard](docs/screenshots/quota-window-light.png)

## Features

- Shows five-hour and weekly remaining quota in the menu bar
- Provides a standalone dashboard while continuing to run after the window is closed
- Includes persistent, high-contrast dark and light themes
- Displays quota percentages, reset countdowns, and remaining reset credits
- Refreshes every 90 seconds with a manual refresh option
- Estimates hourly burn rate and exhaustion trends from recent samples
- Aggregates the last 14 days of token activity from local Codex sessions
- Falls back to the latest local quota record when the network is unavailable
- Enforces a single application instance and activates the existing window on relaunch
- Uses native SwiftUI with no Electron, Node.js, or third-party runtime dependencies
- Builds as Universal 2 for both Apple Silicon and Intel Macs

## Requirements

- macOS 13 Ventura or later
- An active login through the Codex app or Codex CLI
- Apple Command Line Tools or Xcode when building from source

## Build and Run

```bash
git clone https://github.com/sherunlock03/CodexQuotaMonitor-macOS.git
cd CodexQuotaMonitor-macOS
./scripts/test.sh
./scripts/build_app.sh
open dist/CodexQuotaMonitor.app
```

The build script creates:

```text
dist/CodexQuotaMonitor.app
```

Move the app to `/Applications` before regular use. If macOS blocks the first launch, right-click the app in Finder and choose **Open**.

## Data and Privacy

- `~/.codex/auth.json` is re-read for every refresh.
- The login token is used only in memory and is never written to logs, settings, or analytics files.
- Network requests are sent only to `https://chatgpt.com/backend-api/wham/usage`.
- Fourteen-day token activity aggregates only dates and token counts from `~/.codex/sessions`; conversation content is neither stored nor uploaded.
- Lightweight trend samples are stored in `~/.codex/quota-monitor/usage-history.json` and contain only timestamps and quota percentages.

## Project Layout

```text
Sources/CodexQuotaMonitor/   SwiftUI app, quota service, parser, and local analytics
Tests/SelfTest/              Dependency-free parser and trend self-tests
Resources/                   Info.plist and the natively rendered app icon
docs/screenshots/            README screenshots
scripts/                     Build, self-test, and icon-generation scripts
```

## Important Notice

OpenAI does not currently provide an official Codex quota API for third-party menu bar applications. This project uses the account usage endpoint currently called by Codex, so server-side API or schema changes may require parser updates.

This is an unofficial community project and is not affiliated with or endorsed by OpenAI.

## Acknowledgements

The data model and interaction design were inspired by the Windows project [SherUnlocked-4869/CodexQuotaWidget](https://github.com/SherUnlocked-4869/CodexQuotaWidget).

## License

[MIT](LICENSE)
