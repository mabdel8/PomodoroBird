# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a SwiftUI-based Pomodoro Timer app for iOS/macOS using SwiftData for local persistence. The app features a clean, modern interface with focus sessions, task management, and break reminders.

## Architecture

### Core Components

1. **PomodoroAppApp.swift** - Main app entry point with SwiftData model container setup
2. **ContentView.swift** - Root view with TabView containing TimerView and TaskManagerView
3. **Models.swift** - SwiftData models for data persistence
4. **TaskManagerView.swift** - Task creation and management interface
5. **Item.swift** - Contains legacy model definitions (appears to be from Xcode template)

### Data Models

The app uses SwiftData with these main models:

- **FocusTag** - Color-coded categories for tasks and sessions
- **Task** - User-created tasks that can be associated with focus sessions
- **FocusSession** - Records of completed/attempted focus sessions
- **AppTimerState** - Singleton state management for timer persistence

All models use denormalized data (storing tag info directly in Task/FocusSession) for CloudKit compatibility.

### Key Features

- **Timer Interface**: Circular progress indicator, customizable duration (5-120 minutes)
- **Break Management**: Automatic break suggestions, manual break initiation
- **Task Integration**: Link focus sessions to specific tasks
- **Session Tracking**: Complete history of focus sessions and breaks
- **Daily Progress**: Tracks total work time per day

## Development Commands

### Building and Running

```bash
# Build the project
xcodebuild -project PomodoroApp.xcodeproj -scheme PomodoroApp build

# Run on simulator
xcodebuild -project PomodoroApp.xcodeproj -scheme PomodoroApp -destination 'platform=iOS Simulator,name=iPhone 15' build

# Clean build folder
xcodebuild -project PomodoroApp.xcodeproj clean
```

### Testing

```bash
# Run unit tests
xcodebuild test -project PomodoroApp.xcodeproj -scheme PomodoroApp -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test
xcodebuild test -project PomodoroApp.xcodeproj -scheme PomodoroApp -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:PomodoroAppTests/SpecificTestClass
```

## Code Patterns and Conventions

### SwiftData Integration

- All models use `@Model` macro for SwiftData persistence
- Use `@Query` for reactive data fetching in views
- Models store denormalized tag data for CloudKit compatibility
- Environment `modelContext` for CRUD operations

### UI Architecture

- Custom "Geist" font throughout the app
- Consistent color scheme (blue primary, orange for breaks)
- Circular timer display with animated progress
- Tab-based navigation (Timer/Tasks)

### State Management

- Timer state managed locally with `@State` variables
- SwiftData handles persistence automatically
- Session state preserved across app launches via AppTimerState model

### Key Implementation Details

1. **Timer Logic**: Uses `Timer.scheduledTimer` with 1-second intervals
2. **Break System**: Stores paused focus session state when break is initiated
3. **Task Association**: Tasks linked to sessions via UUID references
4. **Progress Tracking**: Calculates daily work time from completed focus sessions

## Important Notes

- The app currently has two sets of models (Models.swift contains legacy definitions, while current models are defined in PomodoroAppApp.swift schema)
- Timer state persistence allows resuming sessions after app termination
- Break suggestions appear every 25 minutes of completed work time
- All text uses custom "Geist" font with consistent weight hierarchy