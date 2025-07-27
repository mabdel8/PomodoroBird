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

- **Timer Interface**: Circular progress indicator, horizontal tape measure time selector (5-120 minutes)
- **Break Management**: Automatic break suggestions, manual break initiation
- **Task Integration**: Link focus sessions to specific tasks with duration selection
- **Session Tracking**: Complete history of focus sessions and breaks
- **Daily Progress**: Tracks total work time per day
- **Default Task**: Auto-creates "Working" task (25min) when no tasks exist

## Development Commands

### Building and Running

```bash
# Build the project
xcodebuild -project PomodoroApp.xcodeproj -scheme PomodoroApp build

# Run on simulator (ALWAYS USE iPhone 16)
xcodebuild -project PomodoroApp.xcodeproj -scheme PomodoroApp -destination 'platform=iOS Simulator,name=iPhone 16' build

# Clean build folder
xcodebuild -project PomodoroApp.xcodeproj clean
```

### Testing

```bash
# Run unit tests (ALWAYS USE iPhone 16)
xcodebuild test -project PomodoroApp.xcodeproj -scheme PomodoroApp -destination 'platform=iOS Simulator,name=iPhone 16'

# Run specific test
xcodebuild test -project PomodoroApp.xcodeproj -scheme PomodoroApp -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:PomodoroAppTests/SpecificTestClass
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
2. **Break System**: Stores paused focus session state when break is initiated, auto-resumes focus timer when break ends
3. **Task Association**: Tasks linked to sessions via UUID references
4. **Progress Tracking**: Calculates daily work time from completed focus sessions
5. **Tape Measure Time Selector**: Horizontal scrolling time picker with automatic selection
   - Ticks arranged 5→120 minutes (left to right) with 5-minute increments
   - Each tick uses individual GeometryReader for position tracking with coordinateSpace
   - Automatic selection based on which tick is closest to screen center (±20pt threshold)
   - No manual tapping required - selection updates during scroll
   - Clean interface without overlay indicators or reference lines

### Live Activity Implementation

6. **iOS Live Activities**: Real-time timer display on Lock Screen and Dynamic Island (iOS 16.1+)
   - **Architecture**: Uses ActivityKit with `PomodoroTimerAttributes` for session data
   - **Live Activity Manager**: `LiveActivityManager` handles activity lifecycle (start/pause/resume/end)
   - **Session Types**: Supports Focus (.focus) and Break (.shortBreak/.longBreak) with distinct colors/icons
   - **Real-time Updates**: Updates every 30 seconds to balance battery life and accuracy
   - **Auto Session Switching**: Automatically updates session type when transitioning between focus/break
   - **UI Design**: Clean modern design with proper padding (24pt), no borders, vertical layout
     - Top: Session type with icon + status badge (Active/Paused)
     - Center: Large prominent timer with task name
     - Bottom: Progress bar with elapsed/remaining time indicators
   - **Dynamic Island**: Compact display with session icon, timer, and status
   - **Break Flow Integration**: Live Activity correctly shows "Break" during breaks and switches back to "Focus Time" with task name when break ends
   - **Auto-Resume**: When breaks end (manually or automatically), focus timer auto-resumes without manual interaction

## Important Notes

- The app currently has two sets of models (Models.swift contains legacy definitions, while current models are defined in PomodoroAppApp.swift schema)
- Timer state persistence allows resuming sessions after app termination
- Break suggestions appear every 25 minutes of completed work time
- All text uses custom "Geist" font with consistent weight hierarchy