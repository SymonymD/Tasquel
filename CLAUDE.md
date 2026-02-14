# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

VIKOV is an iOS app (iPhone + iPad) built with SwiftUI, targeting iOS 26.2. Bundle ID: `com.symonym.VIKOV`.

## Build & Test Commands

```bash
# Build
xcodebuild -project VIKOV.xcodeproj -scheme VIKOV -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Run unit tests (Swift Testing framework)
xcodebuild -project VIKOV.xcodeproj -scheme VIKOV -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# Run a single test
xcodebuild -project VIKOV.xcodeproj -scheme VIKOV -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:VIKOVTests/VIKOVTests/testExample test
```

## Architecture

- **Entry point**: `VIKOV/VIKOVApp.swift` — `@main` App struct with a single `WindowGroup`
- **Root view**: `VIKOV/ContentView.swift`
- **Test targets**: `VIKOVTests` (Swift Testing with `@Test` macro), `VIKOVUITests` (XCTest)

## Swift Configuration

- Default actor isolation: `MainActor`
- Approachable Concurrency enabled
- Upcoming feature: Member Import Visibility
- No external dependencies — pure Apple frameworks
