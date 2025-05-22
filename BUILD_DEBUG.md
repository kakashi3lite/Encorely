# AI-Mixtapes Build Debugging Guide

## Project Structure

```
AI-Mixtapes/
├── AppDelegate.swift          # App initialization and Core Data setup
├── SceneDelegate.swift        # UI scene management
├── ContentView.swift          # Main SwiftUI view
├── Info.plist                 # App configuration
├── project.yml               # XcodeGen project configuration
├── AI_Mixtapes.xcdatamodeld  # Core Data model
├── LaunchScreen.storyboard   # App launch screen
├── Models/                   # Data models
├── Services/                 # Business logic and services
├── Views/                    # UI components
├── ViewModels/              # View state management
├── utils/                    # Utility functions
└── Tests/                   # Unit and integration tests

## Common Build Issues and Solutions

### 1. Core Data Model Issues
- Issue: Core Data model not found or initialization errors
- Solution: 
  - Verify AI_Mixtapes.xcdatamodeld exists and has correct entities
  - Check AppDelegate Core Data setup
  - Run `File > New > File > Core Data > Data Model` if missing

### 2. Intent Definition Conflicts
- Issue: Multiple commands produce Intent.swift
- Solution:
  - Move Intents.intentdefinition to Resources folder
  - Update project.yml to specify single source for intent compilation
  - Clean build folder and rebuild

### 3. Missing Resources
- Issue: Missing LaunchScreen or assets
- Solution:
  - Create Assets.xcassets if missing
  - Add LaunchScreen.storyboard
  - Verify Info.plist references

### 4. Project Structure
- Issue: File reference warnings
- Solution:
  - Use proper group structure in project.yml
  - Avoid duplicate file references
  - Use createIntermediateGroups: true

### 5. Dependencies
Required dependencies:
- AVFoundation for audio processing
- CoreML for AI features
- CoreData for data persistence
- Combine for reactive programming

## Build Process

1. Clean Build:
```bash
xcodebuild clean -project AI-Mixtapes.xcodeproj -scheme AI-Mixtapes
```

2. Generate Project:
```bash
xcodegen generate
```

3. Build Project:
```bash
xcodebuild build -project AI-Mixtapes.xcodeproj -scheme AI-Mixtapes -configuration Debug
```

## Missing Features Checklist

- [ ] Core Data Model
  - MixTape entity
  - Song entity
  - Relationships and attributes

- [ ] Launch Screen
  - App icon
  - Splash animation

- [ ] Asset Catalog
  - App icons
  - Color sets
  - Image assets

- [ ] Schemes and Configuration
  - Debug/Release configurations
  - Test scheme
  - Archive scheme

## Troubleshooting Steps

1. Clean DerivedData:
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/*
```

2. Reset Package Cache:
```bash
rm -rf ~/Library/Caches/org.swift.swiftpm/
```

3. Validate Project Structure:
```bash
xcodebuild -list -project AI-Mixtapes.xcodeproj
```

4. Check Build Settings:
```bash
xcodebuild -project AI-Mixtapes.xcodeproj -scheme AI-Mixtapes -showBuildSettings
```

## Required Tools

- Xcode 15.0+
- XcodeGen 2.43.0+
- Swift 5.0+
- iOS 15.0+ deployment target
