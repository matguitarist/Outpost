# Outpost

A native macOS menu bar monitor for your home server, built with fluid materials, live telemetry, and zero bloat.

Shared rules for my Mac apps (build and check, design rules, skills, git):
@~/.claude/mac-app-conventions.md

## Layout

- `Sources/Outpost/` the app. `App.swift` has the window, menus, and the database location.
- `Sources/OutpostKit/` rules and data logic with no SwiftUI. Tests in `Tests/OutpostKitTests/`.
- `outpost-agent/` lightweight Linux Rust telemetry agent.
- `Package.swift` a Swift package. There is no Xcode project.
- `build.sh` builds, signs, and installs `~/Applications/Outpost.app`.
- Release: `tools/release.sh <version>` (settings in `release.conf`, version in `Info.plist.in`). Use the mac-release skill.
- `Icon/AppIcon.icon` the app icon, an Icon Composer file (JSON plus SVG layers). `build.sh` compiles it with `tools/make_icon.sh`; `tools/icon_review.sh` renders every look into one PNG.
- `docs/` the brief, the screen index, and the user stories, when they exist.

## Checks specific to this app

- `APP_SNAPSHOT_MIN=1 tools/snap.sh` shoots the window at its smallest size.
- Never test against real data in `~/Library/Application Support/Outpost/` from a test.
