# NetMonitor

A native macOS menu bar app that monitors your daily network usage in real time.

## Features

- **Live speeds** - Upload/download speeds updated every 2 seconds in the menu bar popover
- **Per-app breakdown** - See which apps are consuming bandwidth (via nettop)
- **Per-interface tracking** - WiFi vs Mobile Hotspot usage separated
- **Historical data** - Daily summaries stored locally with 30-day retention
- **Usage alerts** - Configurable notifications when thresholds are exceeded
- **Real-time dashboard** - Charts and stats refresh every 5 seconds

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15+ (for building)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (for generating the .xcodeproj)

## Build & Run

```bash
brew install xcodegen
cd NetMonitor
xcodegen generate
xcodebuild build -project NetMonitor.xcodeproj -scheme NetMonitor -configuration Release
```

Then launch the app:

```bash
open ~/Library/Developer/Xcode/DerivedData/NetMonitor-*/Build/Products/Release/NetMonitor.app
```

Or copy it to Applications:

```bash
cp -r ~/Library/Developer/Xcode/DerivedData/NetMonitor-*/Build/Products/Release/NetMonitor.app /Applications/
```

## How It Works

- **Interface stats**: Uses `sysctl(NET_RT_IFLIST2)` for 64-bit byte counters per network interface
- **Per-app tracking**: Spawns `/usr/bin/nettop` every 10 seconds to get per-process network deltas
- **Storage**: SwiftData (SQLite) for persisting samples and daily summaries
- **Alerts**: Evaluates thresholds every 60 seconds via UNUserNotificationCenter

## Architecture

```
App/            - Entry point, AppDelegate with NSStatusItem
Models/         - SwiftData models (InterfaceSample, AppTrafficSample, DailySummary, UsageAlert)
Services/       - Core logic (SamplingEngine, InterfaceStatsCollector, ProcessTrafficCollector, AlertEngine)
ViewModels/     - Observable view models for dashboard and alerts
Views/          - SwiftUI views (menu bar popover, dashboard tabs)
```

## Notes

- The app runs as a background agent (no Dock icon) - look for the arrow icon in your menu bar
- ZscalerTunnel and similar VPN/proxy processes will show inflated numbers since all traffic passes through them
- First launch will request notification permissions for usage alerts
- If macOS blocks the app ("unidentified developer"), go to System Settings > Privacy & Security > Open Anyway
