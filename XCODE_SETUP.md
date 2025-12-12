# Xcode Project Configuration

This document outlines the manual steps needed to configure the Xcode project for building.

## File Organization

The project uses the following structure:
```
GarageValueTracker/
├── Models/
│   ├── VehicleEntity.swift
│   ├── CostEntryEntity.swift
│   ├── ValuationSnapshotEntity.swift
│   └── UserSettingsEntity.swift
├── API/
│   ├── APIModels.swift
│   ├── VehicleAPIService.swift
│   └── MarketAPIService.swift
├── Views/
│   ├── Garage/
│   │   ├── GarageListView.swift
│   │   ├── VehicleDetailView.swift
│   │   ├── AddVehicleView.swift
│   │   └── AddCostEntryView.swift
│   ├── Watchlist/
│   │   ├── WatchlistView.swift
│   │   └── WatchlistDetailView.swift
│   ├── DealChecker/
│   │   └── DealCheckerView.swift
│   ├── SwapInsight/
│   │   └── SwapInsightView.swift
│   ├── UpgradePath/
│   │   └── UpgradePathView.swift
│   └── Settings/
│       └── SettingsView.swift
├── GarageValueTrackerApp.swift
├── ContentView.swift
├── AppDelegate.swift
└── SceneDelegate.swift
```

## Required Project Settings

### Build Settings
- **Deployment Target**: iOS 18.0 or later
- **Swift Language Version**: Swift 5.9+

### Frameworks & Libraries
- SwiftUI
- SwiftData
- Foundation

### Info.plist Permissions
No special permissions required for MVP. NHTSA API is public and doesn't require auth.

## Adding Files to Xcode

1. Open `GarageValueTracker.xcodeproj` in Xcode
2. Select all the new `.swift` files in Finder
3. Drag them into the Xcode project navigator
4. Ensure "Copy items if needed" is checked
5. Select "GarageValueTracker" as the target
6. Organize into the folder structure shown above

## Removing Old Files

Delete these files from the Xcode project (already deleted from filesystem):
- `ViewController.swift` (no longer needed)
- `Main.storyboard` references in project settings

## App Lifecycle Configuration

The app uses SwiftUI's modern app lifecycle:
- Entry point: `GarageValueTrackerApp.swift` with `@main`
- No storyboards required
- SwiftData model container initialized at app launch

## Build & Run

After adding all files to Xcode:
1. Select target device (iOS 18+ simulator or device)
2. Press ⌘R to build and run
3. The app should launch with empty garage state

## Troubleshooting

### "Cannot find type X in scope"
- Ensure all model files are in the correct target membership
- Check that import statements are present

### SwiftData errors
- Verify iOS deployment target is 18.0+
- Check that all `@Model` classes are properly imported

### Build failures
- Clean build folder: ⌘⇧K
- Delete derived data
- Restart Xcode



