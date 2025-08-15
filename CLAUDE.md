# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

JustSwim is an Apple Watch swimming workout tracking application built with Swift and SwiftUI. It uses HealthKit for workout tracking and Core Motion for wall tap detection.

## Development Commands

### Build and Run
- **Build**: Use Xcode's build command (⌘+B) or `xcodebuild build -scheme "JustSwim Watch App"`
- **Run on Simulator**: `xcrun simctl boot "Apple Watch Series 10 (46mm)"` then run from Xcode (⌘+R)
- **Run on Device**: Requires physical Apple Watch paired with iPhone
- **Clean Build**: Clean from Xcode (⌘+Shift+K) or `xcodebuild clean`

### Testing
- **Run All Tests**: Use Xcode's test command (⌘+U) or `xcodebuild test -scheme "JustSwim Watch App"`
- **Run Specific Test**: Select test in Xcode Test Navigator
- **UI Tests**: `xcodebuild test -scheme "JustSwim Watch App" -only-testing:JustSwim_Watch_AppUITests`

### Linting and Code Quality
- **SwiftLint** (if installed): `swiftlint` in project root
- **Format Code**: Use Xcode's built-in formatting (Control+I for indentation)

## Architecture Overview

### MVVM Pattern
The app follows Model-View-ViewModel architecture:

- **Models** (`/Models/`): Business logic and state management
  - `WorkoutState.swift`: Central state manager using ObservableObject pattern, handles all workout phases, timing, and HealthKit integration
  - `HealthKitManager.swift` / `MockHealthKitManager.swift`: Dual implementation for device/simulator
  - `WallTapDetector.swift`: Accelerometer-based wall detection using Core Motion

- **Views** (`/Views/`): SwiftUI view components
  - `MainView.swift`: Entry point for starting workouts
  - `WorkoutView.swift`: Orchestrates workout flow between different phases
  - `ActiveWorkoutView.swift`: Main workout interface during swimming
  - View hierarchy flows: MainView → PoolSizeSelector → WorkoutView → ActiveWorkoutView → WorkoutSummaryView

### Key Design Patterns

1. **Protocol-Based HealthKit**: Uses `HealthKitProtocol` to abstract HealthKit functionality, enabling simulator testing with `MockHealthKitManager`

2. **Conditional Compilation**: 
   ```swift
   #if targetEnvironment(simulator)
       // Use MockHealthKitManager
   #else
       // Use real HealthKitManager
   #endif
   ```

3. **State Management**: Single source of truth in `WorkoutState` with `@Published` properties for UI updates

4. **MainActor Compliance**: All UI operations marked with `@MainActor` for thread safety

### HealthKit Integration Points

- **Authorization**: Request in `WorkoutState.requestHealthKitAuthorization()`
- **Workout Session**: Managed via `HKWorkoutSession` and `HKLiveWorkoutBuilder`
- **Data Types**: Swimming distance, stroke count, heart rate, calories
- **Metadata**: Stores manual set transitions and pool configuration

### Critical Implementation Details

1. **Wall Tap Detection**: Uses CMMotionManager accelerometer data with threshold detection in `WallTapDetector`

2. **Water Lock**: Automatically engaged during workouts via `WKInterfaceDevice.current().enableWaterLock()`

3. **Set/Rest States**: Manual toggle between swimming and resting states, tracked in HealthKit metadata

4. **Pool Configuration**: Supports 25/50 yard/meter pools, stored in UserDefaults and workout metadata

## Testing Approach

- Uses Swift Testing framework (not XCTest)
- Mock implementations for simulator testing
- Separate UI test targets for integration testing
- Test on both simulator and physical device for HealthKit features

## Common Development Tasks

### Adding New Workout Features
1. Update `WorkoutState` model with new state properties
2. Modify HealthKit integration if new data types needed
3. Update views to display new information
4. Add corresponding mock implementation for simulator

### Modifying UI Components
1. Views are in `/Views/` directory
2. Follow existing SwiftUI patterns
3. Ensure `@StateObject` / `@ObservedObject` proper usage
4. Test on multiple watch sizes (42mm, 46mm)

### Working with HealthKit
1. Always check authorization status first
2. Use protocol methods for testability
3. Handle both device and simulator environments
4. Test data persistence and recovery scenarios