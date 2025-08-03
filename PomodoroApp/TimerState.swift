//
//  TimerState.swift
//  PomodoroApp
//
//  Created by Claude Code on 7/31/25.
//

import SwiftUI
import SwiftData
import Foundation
import ActivityKit
import BackgroundTasks
import UIKit

// MARK: - Timer State Management
@Observable
class TimerStateManager {
    // MARK: - Core Timer Properties
    var selectedTask: Task?
    var selectedDuration: Double = 25.0 // in minutes
    var timeRemaining: TimeInterval = 1500 // 25 minutes in seconds
    var totalTime: TimeInterval = 1500
    var isTimerRunning = false
    var isPaused = false
    var isBreakSession = false
    var timer: Timer?
    var currentSession: FocusSession?
    var workTimeToday: Int = 0 // in minutes
    var showingTaskSelector = false
    var breakSuggestionTime: TimeInterval?
    
    // Store paused focus session state
    var pausedFocusTimeRemaining: TimeInterval = 0
    var pausedFocusTotalTime: TimeInterval = 0
    var pausedFocusSession: FocusSession?
    var showingCompletionDialog = false
    var sessionToComplete: FocusSession?
    var totalBreakTime: Int = 0 // Track break time in minutes for current session
    var sessionWorkTime: Int = 0 // Track work time for current session in minutes
    var showingSettings = false
    var showingTaskCreation = false
    var newTaskName = ""
    var selectedTagForNewTask: FocusTag?
    var unassignedSession: FocusSession?
    var showingQuickTaskCreation = false
    var quickTaskName = ""
    var selectedTagForQuickTask: FocusTag?
    
    // Bird hatching system
    var showingHatchingAnimation = false
    var hatchedBird: BirdType?
    var showingBirdCollection = false
    var showingNoBirdAnimation = false
    var processedSessionIds = Set<UUID>()
    
    // Post-session egg display
    var lastEarnedBird: BirdType? // Bird earned from last completed session
    var showNoBirdEgg = false // Show "nobird" after short session
    var isSessionActive = false // Track if user is currently in a session
    
    // In-place egg animation states
    var isEggShaking = false
    var showCrackedEgg = false
    var showFinalResult = false // Show final bird or nobird
    var eggScale: CGFloat = 1.0
    var eggRotation: Double = 0.0
    var isHatching = false // Hide UI during hatching animation
    
    // Background timing state
    var sessionStartTime: Date?
    var sessionEndTime: Date?
    var lastUpdateTime: Date = Date()
    
    // Live Activity Manager (iOS 16.1+)
    var liveActivityManager: LiveActivityManager?
    
    // Notification Manager
    let notificationManager = NotificationManager.shared
    
    // Model Context and Data
    private var modelContext: ModelContext
    private var tags: [FocusTag] = []
    private var availableTasks: [Task] = []
    private var timerStates: [AppTimerState] = []
    private var recentSessions: [FocusSession] = []
    private var collectedBirds: [CollectedBird] = []
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        // Initialize Live Activity Manager if available
        if #available(iOS 16.1, *) {
            liveActivityManager = LiveActivityManager()
        }
    }
    
    deinit {
        // Clean up timer and resources to prevent memory leaks
        timer?.invalidate()
        timer = nil
        
        // End Live Activity if available
        if #available(iOS 16.1, *), let liveActivityManager = liveActivityManager {
            liveActivityManager.endCurrentActivity(completed: false)
        }
        
        print("🧹 TimerStateManager deinitialized")
    }
    
    // MARK: - Computed Properties
    
    var timerState: AppTimerState? {
        timerStates.first
    }
    
    var progress: Double {
        guard totalTime > 0 else { return 0 }
        return (totalTime - timeRemaining) / totalTime
    }
    
    var lastUsedTask: Task? {
        // Get the most recent focus session's task
        guard let lastSession = recentSessions.first(where: { $0.sessionType == "focus" && $0.taskId != nil }),
              let taskId = lastSession.taskId else { return nil }
        return availableTasks.first(where: { $0.id == taskId })
    }
    
    var shouldSuggestBreak: Bool {
        false // Remove auto break suggestions
    }
    
    var nextBreakIn: String? {
        // No automatic break suggestions - removed per requirements
        return nil
    }
    
    // MARK: - Data Management
    
    func updateData(tags: [FocusTag], availableTasks: [Task], timerStates: [AppTimerState], recentSessions: [FocusSession], collectedBirds: [CollectedBird]) {
        self.tags = tags
        self.availableTasks = availableTasks
        self.timerStates = timerStates
        self.recentSessions = recentSessions
        self.collectedBirds = collectedBirds
    }
    
    // MARK: - Background Timer Calculation
    
    func updateTimerWithBackgroundCalculation() {
        guard let sessionStartTime = sessionStartTime,
              let sessionEndTime = sessionEndTime,
              isTimerRunning && !isPaused else { return }
        
        let now = Date()
        let actualElapsedTime = now.timeIntervalSince(sessionStartTime)
        let expectedTotalTime = sessionEndTime.timeIntervalSince(sessionStartTime)
        
        // Calculate remaining time based on actual elapsed time
        let calculatedRemainingTime = max(0, expectedTotalTime - actualElapsedTime)
        
        // Update timeRemaining if there's a significant difference (more than 2 seconds)
        // This accounts for background execution and timer drift
        if abs(timeRemaining - calculatedRemainingTime) > 2.0 {
            timeRemaining = calculatedRemainingTime
            print("🔄 Background sync: Adjusted timer to \(timeString(from: timeRemaining))")
        } else {
            // Normal operation - just decrement by 1 second
            timeRemaining = max(0, timeRemaining - 1)
        }
        
        lastUpdateTime = now
    }
    
    func syncTimerFromBackground() {
        guard let sessionStartTime = sessionStartTime,
              let sessionEndTime = sessionEndTime else { return }
        
        let now = Date()
        let actualElapsedTime = now.timeIntervalSince(sessionStartTime)
        let expectedTotalTime = sessionEndTime.timeIntervalSince(sessionStartTime)
        
        // Calculate remaining time based on actual elapsed time
        let calculatedRemainingTime = max(0, expectedTotalTime - actualElapsedTime)
        
        // Always sync when returning from background
        timeRemaining = calculatedRemainingTime
        lastUpdateTime = now
        
        print("🔄 Foreground sync: Timer set to \(timeString(from: timeRemaining))")
        
        // Check if timer should complete (timer ended while in background)
        if timeRemaining <= 0 || now >= sessionEndTime {
            print("⏰ Timer completed while in background - triggering completion")
            completeSession()
            return
        }
        
        // Update Live Activity with accurate timing
        if #available(iOS 16.1, *), let liveActivityManager = liveActivityManager {
            liveActivityManager.updateActivity(remainingTime: timeRemaining)
        }
        
        // Reschedule notification with corrected time (in case of drift)
        let sessionTypeString = isBreakSession ? "break" : "focus"
        notificationManager.scheduleTimerCompletionNotification(
            sessionType: sessionTypeString,
            taskName: selectedTask?.title,
            fireDate: sessionEndTime
        )
    }
    
    // MARK: - Helper Methods
    
    func eggImageForProgress(_ progress: Double) -> String {
        // Show sleeping egg during break sessions
        if isBreakSession {
            return "eggsleeping"
        }
        
        // Handle hatching animation states
        if isHatching {
            if showFinalResult {
                // Show final result after animation - the hatched bird!
                if let earnedBird = hatchedBird {
                    return earnedBird.birdImageName // Show the actual bird that hatched
                } else {
                    return "nobird" // Show nobird ghost
                }
            } else if showCrackedEgg {
                return "almost" // Show cracked egg during animation
            } else {
                // During initial animation phase (shaking), show "almost" egg
                return "almost"
            }
        }
        
        // If session is not active, show post-session result
        if !isSessionActive {
            if showNoBirdEgg {
                return "nobird" // Show nobird for short sessions
            } else if let earnedBird = lastEarnedBird {
                return earnedBird.birdImageName // Show the bird they earned
            }
        }
        
        // Normal egg progression during active focus sessions
        switch progress {
        case 0.0..<0.34:
            return "egg"
        case 0.34..<0.67:
            return "partial"
        case 0.67..<1.0:
            return "almost"
        default:
            return "almost" // At 100%, we'll handle hatching separately
        }
    }
    
    private func generateRandomBird() -> BirdType {
        return BirdType.allCases.randomElement() ?? .doctorbird
    }
    
    // MARK: - In-Place Animation Functions
    
    func handleSessionBirdHatching(session: FocusSession) {
        // Prevent duplicate processing of the same session
        guard !processedSessionIds.contains(session.id) else {
            print("🚫 Prevented duplicate bird hatching for already processed session: \(session.id)")
            return
        }
        
        // Prevent overlapping animations
        guard !showingHatchingAnimation && !showingNoBirdAnimation else {
            print("🚫 Prevented bird hatching due to active animation for session: \(session.id)")
            return
        }
        
        // Mark this session as processed to prevent duplicates
        processedSessionIds.insert(session.id)
        print("✅ Processing bird hatching for session: \(session.id)")
        
        // Clean up old processed session IDs to prevent memory growth
        // Keep only the last 50 session IDs
        if processedSessionIds.count > 50 {
            let oldestIds = Array(processedSessionIds).prefix(processedSessionIds.count - 50)
            for id in oldestIds {
                processedSessionIds.remove(id)
            }
        }
        
        let actualFocusTime = session.actualDuration // Duration in seconds
        
        // Mark session as no longer active
        isSessionActive = false
        
        let requiredDuration = notificationManager.getEffectiveBirdHatchingDuration()
        if Double(actualFocusTime) >= requiredDuration {
            // User earned a real bird
            let newBird = generateRandomBird()
            addBirdToCollection(newBird, fromSession: session)
            
            // Set post-session egg display to show the earned bird egg
            lastEarnedBird = newBird
            showNoBirdEgg = false
            hatchedBird = newBird
            
            // Start the hatching animation
            startInPlaceEggAnimation()
        } else {
            // User gets "nobird" for focusing less than 10 minutes
            // Set post-session egg display to show nobird egg
            lastEarnedBird = nil
            showNoBirdEgg = true
            hatchedBird = nil
            
            // Start the hatching animation
            startInPlaceEggAnimation()
        }

    }
    
    func startInPlaceEggAnimation() {
        // Start hatching - this will hide the UI
        isHatching = true
        
        // Reset animation states
        isEggShaking = false
        showCrackedEgg = false
        showFinalResult = false
        eggScale = 1.0
        eggRotation = 0.0
        
        // Stage 1: Shake the egg with haptic feedback
        withAnimation(.easeInOut(duration: 0.1).repeatCount(6, autoreverses: true)) {
            eggScale = 1.1
        }
        
        // Add slight rotation for more dynamic effect
        withAnimation(.easeInOut(duration: 0.05).repeatCount(12, autoreverses: true)) {
            eggRotation = 3.0
        }
        
        // Haptic feedback during shaking
        if notificationManager.enableHapticFeedback {
            let lightImpact = UIImpactFeedbackGenerator(style: .light)
            lightImpact.impactOccurred()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                lightImpact.impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                lightImpact.impactOccurred()
            }
        }
        
        // Stage 2: Show cracks with medium haptic feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.showCrackedEgg = true
            
            // Medium haptic for crack appearance
            if self.notificationManager.enableHapticFeedback {
                let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
                mediumImpact.impactOccurred()
            }
            
            // Add a small scale pulse when cracks appear
            withAnimation(.easeOut(duration: 0.2)) {
                self.eggScale = 1.05
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeOut(duration: 0.2)) {
                    self.eggScale = 1.0
                }
            }
        }
        
        // Stage 3: Dramatic final hatch with enhanced animation and strong haptic
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // Strong haptic for the big reveal
            if self.notificationManager.enableHapticFeedback {
                let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
                heavyImpact.impactOccurred()
                
                // Add success notification haptic
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.success)
                }
            }
            
            // Enhanced animation with multiple stages
            // First: Quick scale down (anticipation)
            withAnimation(.easeIn(duration: 0.1)) {
                self.eggScale = 0.9
                self.eggRotation = 0.0
            }
            
            // Then: Dramatic scale up with spring (reveal)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.5, blendDuration: 0)) {
                    self.showFinalResult = true
                    self.eggScale = 1.3
                }
            }
            
            // Finally: Settle to normal size
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self.eggScale = 1.0
                }
            }
        }
        
        // Stage 4: Gentle transition to post-session egg with subtle animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.easeInOut(duration: 0.8)) {
                self.showFinalResult = false
                self.showCrackedEgg = false
                self.eggScale = 0.95
            }
            
            // Clean up animation variables after fade
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.4)) {
                    self.eggScale = 1.0
                }
                self.isHatching = false // Show UI again
                // Keep hatchedBird for a moment to ensure proper final display
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.hatchedBird = nil
                }
                // The egg will now show the post-session result based on lastEarnedBird/showNoBirdEgg
            }
        }
    }
    
    private func addBirdToCollection(_ birdType: BirdType, fromSession: FocusSession?) {
        let collectedBird = CollectedBird(birdType: birdType, fromSessionId: fromSession?.id)
        modelContext.insert(collectedBird)
        
        do {
            try modelContext.save()
            print("🐦 Hatched a \(birdType.displayName)!")
        } catch {
            print("Error saving collected bird: \(error)")
        }
    }
    
    // MARK: - Setup and Data Management
    
    func setupInitialData() {
        // Always ensure default tags exist and clean up duplicates
        createDefaultTags()
        
        // Create timer state if none exists
        if timerStates.isEmpty {
            let newTimerState = AppTimerState()
            modelContext.insert(newTimerState)
        }
        
        // Create default "Working" task if no "Working" task exists (completed or incomplete)
        do {
            var descriptor = FetchDescriptor<Task>()
            descriptor.predicate = #Predicate<Task> { $0.title == "Working" }
            let existingWorkingTasks = try modelContext.fetch(descriptor)
            
            if existingWorkingTasks.isEmpty {
                createDefaultWorkingTask()
            }
        } catch {
            print("Error checking for existing Working tasks: \(error)")
            // Fallback to old behavior
            if availableTasks.isEmpty {
                createDefaultWorkingTask()
            }
        }
        
        // Set to last used task or first available task
        if selectedTask == nil {
            selectedTask = lastUsedTask ?? availableTasks.first
        }
        
        // Set initial time based on selected task duration or default
        if let task = selectedTask {
            selectedDuration = Double(task.duration)
        }
        
        if !isPaused {
            timeRemaining = selectedDuration * 60
            totalTime = selectedDuration * 60
        }
    }
    
    private func createDefaultWorkingTask() {
        // Ensure default tags exist first
        createDefaultTags()
        
        // Find the "Work" tag by querying database directly
        do {
            var descriptor = FetchDescriptor<FocusTag>()
            descriptor.predicate = #Predicate<FocusTag> { $0.name == "Work" }
            let workTags = try modelContext.fetch(descriptor)
            
            guard let workTag = workTags.first else {
                print("Error: Work tag not found after creating default tags")
                return
            }
            
            // Create the default "Working" task
            let defaultTask = Task(title: "Working", duration: 25, tag: workTag)
            modelContext.insert(defaultTask)
            
            try modelContext.save()
        } catch {
            print("Error creating default working task: \(error)")
        }
    }
    
    func calculateWorkTimeToday() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let todaySessions = recentSessions.filter { session in
            guard let startTime = session.startTime else { return false }
            return calendar.isDate(startTime, inSameDayAs: today) && 
                   session.sessionType == "focus" && 
                   session.isCompleted
        }
        
        workTimeToday = todaySessions.reduce(0) { total, session in
            total + Int(ceil(Double(session.actualDuration) / 60.0)) // Convert to minutes, rounding up
        }
    }
    
    private func createDefaultTags() {
        // First, clean up any existing duplicates
        cleanupDuplicateTags()
        
        let defaultTags = [
            ("Work", "blue"),
            ("Personal", "green"),
            ("Study", "purple"),
            ("Exercise", "orange"),
            ("Reading", "red")
        ]
        
        for (name, color) in defaultTags {
            // Check if tag with this name already exists by querying database directly
            do {
                var descriptor = FetchDescriptor<FocusTag>()
                descriptor.predicate = #Predicate<FocusTag> { $0.name == name }
                let existingTags = try modelContext.fetch(descriptor)
                
                if existingTags.isEmpty {
                    let tag = FocusTag(name: name, color: color)
                    modelContext.insert(tag)
                }
            } catch {
                print("Error checking for existing tag '\(name)': \(error)")
                // If query fails, try to create the tag anyway (SwiftData will handle duplicates)
                let tag = FocusTag(name: name, color: color)
                modelContext.insert(tag)
            }
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving default tags: \(error)")
        }
    }
    
    private func cleanupDuplicateTags() {
        do {
            // Fetch all tags
            let descriptor = FetchDescriptor<FocusTag>()
            let allTags = try modelContext.fetch(descriptor)
            
            // Group tags by name
            let tagGroups = Dictionary(grouping: allTags) { $0.name }
            
            // For each group with duplicates, keep the first one and delete the rest
            for (name, tags) in tagGroups where tags.count > 1 {
                print("Found \(tags.count) duplicate tags for '\(name)', removing \(tags.count - 1) duplicates")
                
                // Keep the first tag, delete the rest
                for i in 1..<tags.count {
                    modelContext.delete(tags[i])
                }
            }
            
            try modelContext.save()
        } catch {
            print("Error cleaning up duplicate tags: \(error)")
        }
    }
    
    // MARK: - Timer Control Methods
    
    func startTimer() {
        // Reset post-session egg display when starting a new session
        isSessionActive = true
        lastEarnedBird = nil
        showNoBirdEgg = false
        
        // Reset animation states
        isEggShaking = false
        showCrackedEgg = false
        showFinalResult = false
        eggScale = 1.0
        eggRotation = 0.0
        showingHatchingAnimation = false
        showingNoBirdAnimation = false
        hatchedBird = nil
        
        let sessionDuration: Int
        if isBreakSession {
            sessionDuration = Int(notificationManager.getEffectiveBreakDuration())
        } else {
            sessionDuration = Int(notificationManager.isTestModeEnabled ? notificationManager.getEffectiveFocusDuration() : selectedDuration * 60)
        }
        
        // Reset session work time when starting a new focus session (not break)
        if !isBreakSession && currentSession == nil {
            sessionWorkTime = 0
        }
        
        // Set session timing for background calculation
        sessionStartTime = Date()
        sessionEndTime = Date().addingTimeInterval(TimeInterval(sessionDuration))
        lastUpdateTime = Date()
        
        // For focus sessions, ensure we have a task (use default "Working" if none selected)
        let taskForSession: Task?
        
        if isBreakSession {
            taskForSession = nil
        } else if let selectedTask = selectedTask {
            taskForSession = selectedTask
        } else {
            // Find existing "Working" task (including completed ones) or create new one
            do {
                var descriptor = FetchDescriptor<Task>()
                descriptor.predicate = #Predicate<Task> { $0.title == "Working" }
                let existingTasks = try modelContext.fetch(descriptor)
                
                if let existingTask = existingTasks.first {
                    taskForSession = existingTask
                } else {
                    // Create new Working task
                    createDefaultTags() // Ensure default tags exist
                    
                    // Query database directly for Work tag
                    var tagDescriptor = FetchDescriptor<FocusTag>()
                    tagDescriptor.predicate = #Predicate<FocusTag> { $0.name == "Work" }
                    guard let workTag = try? modelContext.fetch(tagDescriptor).first else {
                        print("Error: Work tag not found after creating default tags")
                        return
                    }
                    
                    let defaultTask = Task(title: "Working", duration: 25, tag: workTag)
                    modelContext.insert(defaultTask)
                    try? modelContext.save()
                    taskForSession = defaultTask
                }
            } catch {
                // Fallback: create new task
                createDefaultTags() // Ensure default tags exist
                
                // Query database directly for Work tag
                var tagDescriptor = FetchDescriptor<FocusTag>()
                tagDescriptor.predicate = #Predicate<FocusTag> { $0.name == "Work" }
                guard let workTag = try? modelContext.fetch(tagDescriptor).first else {
                    print("Error: Work tag not found after creating default tags")
                    return
                }
                
                let defaultTask = Task(title: "Working", duration: 25, tag: workTag)
                modelContext.insert(defaultTask)
                try? modelContext.save()
                taskForSession = defaultTask
            }
        }
        
        let session = FocusSession(
            duration: sessionDuration,
            task: taskForSession,
            sessionType: isBreakSession ? "break" : "focus"
        )
        session.startTime = Date()
        currentSession = session
        modelContext.insert(session)
        
        let expectedBreakDuration = notificationManager.getEffectiveBreakDuration()
        let expectedFocusDuration = notificationManager.isTestModeEnabled ? notificationManager.getEffectiveFocusDuration() : selectedDuration * 60
        
        if isBreakSession && timeRemaining != expectedBreakDuration {
            timeRemaining = expectedBreakDuration
            totalTime = expectedBreakDuration
        } else if !isBreakSession && timeRemaining != expectedFocusDuration {
            timeRemaining = expectedFocusDuration
            totalTime = expectedFocusDuration
        }
        
        // Start timer
        isTimerRunning = true
        isPaused = false
        
        // Schedule background notification for timer completion
        let completionDate = sessionEndTime ?? Date().addingTimeInterval(timeRemaining)
        let sessionTypeString = isBreakSession ? "break" : "focus"
        notificationManager.scheduleTimerCompletionNotification(
            sessionType: sessionTypeString,
            taskName: taskForSession?.title,
            fireDate: completionDate
        )
        
        // Start or Update Live Activity if available
        if #available(iOS 16.1, *), let liveActivityManager = liveActivityManager {
            let sessionType: PomodoroTimerAttributes.ContentState.SessionType = isBreakSession ? .shortBreak : .focus
            
            // Check if Live Activity already exists, update instead of creating new one
            if liveActivityManager.currentActivity != nil {
                // Update existing activity with new session type and task
                liveActivityManager.resumeActivityWithSessionType(
                    remainingTime: timeRemaining,
                    sessionType: sessionType,
                    taskName: taskForSession?.title
                )
            } else {
                // Create new activity only if none exists
                liveActivityManager.startActivity(
                    duration: timeRemaining,
                    sessionType: sessionType,
                    taskName: taskForSession?.title
                )
            }
        }
        
        // Ensure any existing timer is invalidated before creating new one
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // Update timer using background-aware calculation
            self.updateTimerWithBackgroundCalculation()
            
            if self.timeRemaining > 0 {
                // Update Live Activity every 30 seconds to reduce battery impact
                if Int(self.timeRemaining) % 30 == 0 {
                    if #available(iOS 16.1, *), let liveActivityManager = self.liveActivityManager {
                        liveActivityManager.updateActivity(remainingTime: self.timeRemaining)
                    }
                }
            } else {
                self.completeSession()
            }
        }
    }
    
    func resumeTimer() {
        // Resume from paused state
        isTimerRunning = true
        isPaused = false
        
        // Update session timing for background calculation
        sessionStartTime = Date()
        sessionEndTime = Date().addingTimeInterval(timeRemaining)
        lastUpdateTime = Date()
        
        // Reschedule background notification for timer completion
        let completionDate = sessionEndTime ?? Date().addingTimeInterval(timeRemaining)
        let sessionTypeString = isBreakSession ? "break" : "focus"
        notificationManager.scheduleTimerCompletionNotification(
            sessionType: sessionTypeString,
            taskName: selectedTask?.title,
            fireDate: completionDate
        )
        
        // Resume Live Activity if available
        if #available(iOS 16.1, *), let liveActivityManager = liveActivityManager {
            liveActivityManager.resumeActivity(remainingTime: timeRemaining)
        }
        
        // Ensure any existing timer is invalidated before creating new one
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // Update timer using background-aware calculation
            self.updateTimerWithBackgroundCalculation()
            
            if self.timeRemaining > 0 {
                // Update Live Activity every 30 seconds to reduce battery impact
                if Int(self.timeRemaining) % 30 == 0 {
                    if #available(iOS 16.1, *), let liveActivityManager = self.liveActivityManager {
                        liveActivityManager.updateActivity(remainingTime: self.timeRemaining)
                    }
                }
            } else {
                self.completeSession()
            }
        }
    }
    
    func startBreak() {
        // Store current focus session state
        pausedFocusTimeRemaining = timeRemaining
        pausedFocusTotalTime = totalTime
        pausedFocusSession = currentSession
        
        // Mark that the focus session had a break taken
        if let focusSession = currentSession {
            focusSession.wasBreakTaken = true
        }
        
        // Pause the current focus session
        pauseTimer()
        
        // Start break session automatically
        isBreakSession = true
        let breakDuration = notificationManager.getEffectiveBreakDuration()
        timeRemaining = breakDuration
        totalTime = breakDuration
        startTimer() // Automatically start the break timer
    }
    
    func startSuggestedBreak() {
        // Start a suggested break
        isBreakSession = true
        let breakDuration = notificationManager.getEffectiveBreakDuration()
        timeRemaining = breakDuration
        totalTime = breakDuration
        startTimer()
    }
    
    func pauseTimer() {
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
        isPaused = true
        
        // Cancel background notification since timer is paused
        notificationManager.cancelTimerNotifications()
        
        // Pause Live Activity if available
        if #available(iOS 16.1, *), let liveActivityManager = liveActivityManager {
            liveActivityManager.pauseActivity()
        }
        
        // Update current session with actual time worked (in seconds)
        if let session = currentSession {
            session.actualDuration = Int(totalTime - timeRemaining)
            
            do {
                try modelContext.save()
            } catch {
                print("Error saving session: \(error)")
            }
        }
    }
    
    func stopTimer() {
        // For focus sessions, pause the timer and show completion dialog
        if let session = currentSession, !isBreakSession {
            // Pause the timer instead of stopping it
            pauseTimer()
            
            // Update session with current progress
            session.endTime = Date()
            session.actualDuration = Int(totalTime - timeRemaining)
            sessionToComplete = session
            showingCompletionDialog = true
            return // Wait for user confirmation
        }
        
        // For break sessions, actually stop the timer
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
        isPaused = false
        
        // Cancel background notification since timer is stopped
        notificationManager.cancelTimerNotifications()
        
        // End Live Activity if available
        if #available(iOS 16.1, *), let liveActivityManager = liveActivityManager {
            liveActivityManager.endCurrentActivity(completed: false)
        }
        
        // Reset break session state
        if isBreakSession {
            isBreakSession = false
            timeRemaining = selectedDuration * 60
            totalTime = selectedDuration * 60
            currentSession = nil
        }
        
        calculateWorkTimeToday() // Recalculate work time
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving session: \(error)")
        }
    }
    
    // MARK: - Session Completion Methods
    
    func confirmSessionCompletion() {
        guard let session = sessionToComplete else { return }
        
        // Stop the timer completely
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
        isPaused = false
        
        // Cancel background notification since timer is stopped
        notificationManager.cancelTimerNotifications()
        
        // End Live Activity if available
        if #available(iOS 16.1, *), let liveActivityManager = liveActivityManager {
            liveActivityManager.endCurrentActivity(completed: true)
        }
        
        // Mark session as completed
        session.isCompleted = true
        
        // Update session work time for break tracking (convert seconds to minutes, keeping fractional minutes)
        sessionWorkTime += Int(ceil(Double(session.actualDuration) / 60.0)) // Add minutes to session work time, rounding up
        
        // 🐦 Handle bird hatching for manual completion (guard prevents duplicates)
        handleSessionBirdHatching(session: session)
        
        // Check if session has an associated task
        if let taskId = session.taskId {
            // Find the task using a query
            do {
                var descriptor = FetchDescriptor<Task>()
                descriptor.predicate = #Predicate<Task> { $0.id == taskId }
                let tasks = try modelContext.fetch(descriptor)
                if let task = tasks.first {
                    if task.isCompleted {
                        // Task already completed, add time to existing duration (convert seconds to minutes, rounding up)
                        task.duration += Int(ceil(Double(session.actualDuration) / 60.0)) // Add minutes
                    } else {
                        // Mark as completed for first time
                        task.isCompleted = true
                        task.completedAt = Date()
                    }
                }
            } catch {
                print("Error fetching task: \(error)")
            }
            
            // Reset timer and close dialog normally
            finishSessionCompletion()
        } else {
            // No task assigned - prompt user to create one
            unassignedSession = session
            showingCompletionDialog = false // Close completion dialog
            sessionToComplete = nil
            showingTaskCreation = true // Show task creation dialog
        }
        
        calculateWorkTimeToday() // Recalculate work time
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving completed session: \(error)")
        }
    }
    
    func finishSessionCompletion() {
        // Reset timer
        timeRemaining = selectedDuration * 60
        totalTime = selectedDuration * 60
        currentSession = nil
        totalBreakTime = 0 // Reset break time for next session
        
        // Close dialog
        showingCompletionDialog = false
        sessionToComplete = nil
    }
    
    func cancelSessionCompletion() {
        // Resume the timer instead of resetting
        resumeTimer()
        
        // Close dialog but keep the session active
        showingCompletionDialog = false
        sessionToComplete = nil
    }
    
    func completeSession() {
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
        isPaused = false
        
        // Cancel scheduled notification since timer completed
        notificationManager.cancelTimerNotifications()
        
        // Check if we're completing in foreground (app active) vs background
        let isAppActive = UIApplication.shared.applicationState == .active
        
        // Only trigger immediate alert if app is active (avoid duplicate with scheduled notification)
        if isAppActive {
            let sessionTypeString = isBreakSession ? "break" : "focus"
            let taskName = isBreakSession ? nil : selectedTask?.title
            notificationManager.triggerTimerCompletionAlert(sessionType: sessionTypeString, taskName: taskName)
        }
        
        // Handle break session completion - transition back to focus
        if isBreakSession {
            print("🔄 Break session completed - transitioning back to focus")
            
            // Mark break session as completed first AND SAVE IT IMMEDIATELY
            if let session = currentSession {
                session.isCompleted = true
                session.endTime = Date()
                session.actualDuration = Int(totalTime - timeRemaining)
                
                // Add break time to the paused focus session
                if let focusSession = pausedFocusSession {
                    focusSession.breakDuration += session.actualDuration
                    totalBreakTime += session.actualDuration / 60 // track in minutes for display
                    print("🔄 Break recorded: \(session.actualDuration) seconds added to focus session")
                }
                
                // CRITICAL: Save the break session immediately like endBreakEarly() does
                do {
                    try modelContext.save()
                    print("✅ Break session saved successfully (natural completion)")
                } catch {
                    print("❌ Error saving break session (natural completion): \(error)")
                }
            }
            
            // Transition back to focus session if it exists
            if let focusSession = pausedFocusSession {
                isBreakSession = false
                timeRemaining = pausedFocusTimeRemaining
                totalTime = pausedFocusTotalTime
                currentSession = focusSession
                
                // Auto-resume the focus timer
                isTimerRunning = true
                isPaused = false
                
                // Update session timing for background calculation
                sessionStartTime = Date()
                sessionEndTime = Date().addingTimeInterval(timeRemaining)
                lastUpdateTime = Date()
                
                // Reschedule background notification for focus timer completion
                let completionDate = sessionEndTime ?? Date().addingTimeInterval(timeRemaining)
                notificationManager.scheduleTimerCompletionNotification(
                    sessionType: "focus",
                    taskName: selectedTask?.title,
                    fireDate: completionDate
                )
                
                // Update Live Activity to show focus session and resume
                if #available(iOS 16.1, *), let liveActivityManager = liveActivityManager {
                    liveActivityManager.resumeActivityWithSessionType(
                        remainingTime: timeRemaining,
                        sessionType: .focus,
                        taskName: selectedTask?.title
                    )
                }
                
                // Start the focus timer
                timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    self.updateTimerWithBackgroundCalculation()
                    
                    if self.timeRemaining > 0 {
                        // Update Live Activity every 30 seconds
                        if Int(self.timeRemaining) % 30 == 0 {
                            if #available(iOS 16.1, *), let liveActivityManager = self.liveActivityManager {
                                liveActivityManager.updateActivity(remainingTime: self.timeRemaining)
                            }
                        }
                    } else {
                        self.completeFocusSession()
                    }
                }
                
                // Clear stored state
                pausedFocusSession = nil
                pausedFocusTimeRemaining = 0
                pausedFocusTotalTime = 0
                
                print("✅ Successfully transitioned from break back to focus timer")
                return // Don't continue with normal completion flow
            } else {
                // No focus session to return to - just end the break
                print("🔚 No focus session to return to - ending break Live Activity")
                if #available(iOS 16.1, *), let liveActivityManager = liveActivityManager {
                    liveActivityManager.endCurrentActivity(completed: true)
                }
            }
        } else {
            // Focus session completion - End Live Activity
            print("🔚 Focus session completed - ending Live Activity")
            if #available(iOS 16.1, *), let liveActivityManager = liveActivityManager {
                liveActivityManager.endCurrentActivity(completed: true)
            }
        }
        
        // Mark session as completed (for focus sessions or break sessions without transition)
        if let session = currentSession {
            session.isCompleted = true
            session.endTime = Date()
            session.actualDuration = Int(totalTime - timeRemaining)
            
            // Update session work time for break tracking (focus sessions only)
            if !isBreakSession {
                sessionWorkTime += Int(ceil(Double(session.actualDuration) / 60.0)) // Add minutes to session work time, rounding up
            }
            
            // Mark associated task as completed if this was a focus session
            if !isBreakSession, let taskId = session.taskId {
                // Find the task using a query
                do {
                    var descriptor = FetchDescriptor<Task>()
                    descriptor.predicate = #Predicate<Task> { $0.id == taskId }
                    let tasks = try modelContext.fetch(descriptor)
                    if let task = tasks.first {
                        if task.isCompleted {
                            // Task already completed, add time to existing duration
                            task.duration += Int(ceil(Double(session.actualDuration) / 60.0)) // Add minutes
                        } else {
                            // Mark as completed for first time
                            task.isCompleted = true
                            task.completedAt = Date()
                        }
                    }
                } catch {
                    print("Error fetching task: \(error)")
                }
            }
            
            // 🐦 Bird hatching mechanism - only for completed focus sessions
            if !isBreakSession {
                handleSessionBirdHatching(session: session)
            }
        }
        
        if isBreakSession {
            // Break completed, return to focus session if it exists and auto-resume
            if let focusSession = pausedFocusSession {
                isBreakSession = false
                timeRemaining = pausedFocusTimeRemaining
                totalTime = pausedFocusTotalTime
                currentSession = focusSession
                
                // Mark session as active when resuming focus after break
                isSessionActive = true
                
                // Auto-resume the focus timer instead of requiring manual resume
                isTimerRunning = true
                isPaused = false
                
                // Update session timing for background calculation
                sessionStartTime = Date()
                sessionEndTime = Date().addingTimeInterval(timeRemaining)
                lastUpdateTime = Date()
                
                // Update Live Activity to show focus session and resume
                if #available(iOS 16.1, *), let liveActivityManager = liveActivityManager {
                    liveActivityManager.resumeActivityWithSessionType(
                        remainingTime: timeRemaining,
                        sessionType: .focus,
                        taskName: selectedTask?.title
                    )
                }
                
                // Start the focus timer
                // Ensure any existing timer is invalidated before creating new one
                timer?.invalidate()
                timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    // Update timer using background-aware calculation
                    self.updateTimerWithBackgroundCalculation()
                    
                    if self.timeRemaining > 0 {
                        // Update Live Activity every 30 seconds to reduce battery impact
                        if Int(self.timeRemaining) % 30 == 0 {
                            if #available(iOS 16.1, *), let liveActivityManager = self.liveActivityManager {
                                liveActivityManager.updateActivity(remainingTime: self.timeRemaining)
                            }
                        }
                    } else {
                        self.completeFocusSession()
                    }
                }
                
                // Clear stored state
                pausedFocusSession = nil
                pausedFocusTimeRemaining = 0
                pausedFocusTotalTime = 0
            } else {
                // No previous focus session, reset normally
                isBreakSession = false
                timeRemaining = selectedDuration * 60
                totalTime = selectedDuration * 60
                currentSession = nil
            }
        } else {
            // Focus session completed - reset
            timeRemaining = selectedDuration * 60
            totalTime = selectedDuration * 60
            currentSession = nil
        }
        
        calculateWorkTimeToday() // Recalculate work time
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving completed session: \(error)")
        }
    }
    
    // Separate function for completing focus sessions to avoid recursion
    func completeFocusSession() {
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
        isPaused = false
        
        // Cancel scheduled notification since timer completed
        notificationManager.cancelTimerNotifications()
        
        // Check if we're completing in foreground (app active) vs background
        let isAppActive = UIApplication.shared.applicationState == .active
        
        // Only trigger immediate alert if app is active (avoid duplicate with scheduled notification)
        if isAppActive {
            notificationManager.triggerTimerCompletionAlert(sessionType: "focus", taskName: selectedTask?.title)
        }
        
        // End Live Activity if available (marked as completed)
        if #available(iOS 16.1, *), let liveActivityManager = liveActivityManager {
            liveActivityManager.endCurrentActivity(completed: true)
        }
        
        // Mark session as completed
        if let session = currentSession {
            session.isCompleted = true
            session.endTime = Date()
            session.actualDuration = Int(totalTime - timeRemaining)
            
            // Update session work time for break tracking (focus sessions only)
            sessionWorkTime += Int(ceil(Double(session.actualDuration) / 60.0)) // Add minutes to session work time, rounding up
            
            // Mark associated task as completed if this was a focus session
            if let taskId = session.taskId {
                // Find the task using a query
                do {
                    var descriptor = FetchDescriptor<Task>()
                    descriptor.predicate = #Predicate<Task> { $0.id == taskId }
                    let tasks = try modelContext.fetch(descriptor)
                    if let task = tasks.first {
                        if task.isCompleted {
                            // Task already completed, add time to existing duration
                            task.duration += Int(ceil(Double(session.actualDuration) / 60.0)) // Add minutes
                        } else {
                            // Mark as completed for first time
                            task.isCompleted = true
                            task.completedAt = Date()
                        }
                    }
                } catch {
                    print("Error fetching task: \(error)")
                }
            }
            
            // 🐦 Handle bird hatching for focus session completion
            handleSessionBirdHatching(session: session)
        }
        
        // Focus session completed - reset
        timeRemaining = selectedDuration * 60
        totalTime = selectedDuration * 60
        currentSession = nil
        
        calculateWorkTimeToday() // Recalculate work time
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving completed focus session: \(error)")
        }
    }
    
    // MARK: - Task Management Methods
    
    func createTaskForSession() {
        guard let session = unassignedSession, !newTaskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Create new task
        let task = Task(
            title: newTaskName.trimmingCharacters(in: .whitespacesAndNewlines),
            duration: Int(ceil(Double(session.actualDuration) / 60.0)), // Convert seconds to minutes, rounding up
            tag: selectedTagForNewTask,
            plannedDate: Date()
        )
        task.isCompleted = true
        task.completedAt = Date()
        modelContext.insert(task)
        
        // Link session to the new task
        session.taskId = task.id
        session.taskTitle = task.title
        session.tagId = task.tagId
        session.tagName = task.tagName
        session.tagColor = task.tagColor
        
        // Reset state
        newTaskName = ""
        selectedTagForNewTask = nil
        unassignedSession = nil
        showingTaskCreation = false
        
        // Finish session completion
        finishSessionCompletion()
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving new task: \(error)")
        }
    }
    
    func skipTaskCreation() {
        // Reset state without creating task
        newTaskName = ""
        selectedTagForNewTask = nil
        unassignedSession = nil
        showingTaskCreation = false
        
        // Finish session completion
        finishSessionCompletion()
    }
    
    func handleStartTimer() {
        // Check if we have a selected task or if it's a break session
        if selectedTask != nil || isBreakSession {
            startTimer()
        } else {
            // No task selected - show quick task creation popup
            showingQuickTaskCreation = true
        }
    }
    
    func createQuickTaskAndStartTimer() {
        guard !quickTaskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Create new task
        let task = Task(
            title: quickTaskName.trimmingCharacters(in: .whitespacesAndNewlines),
            duration: Int(selectedDuration), // Use current timer duration
            tag: selectedTagForQuickTask,
            plannedDate: Date()
        )
        modelContext.insert(task)
        
        // Set as selected task
        selectedTask = task
        
        // Reset quick task creation state
        quickTaskName = ""
        selectedTagForQuickTask = nil
        showingQuickTaskCreation = false
        
        // Start timer with the new task
        startTimer()
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving quick task: \(error)")
        }
    }
    
    func cancelQuickTaskCreation() {
        quickTaskName = ""
        selectedTagForQuickTask = nil
        showingQuickTaskCreation = false
    }
    
    func endBreakEarly() {
        // End break session and return to focus
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
        isPaused = false
        
        // Mark break session as completed and save it properly
        if let session = currentSession {
            session.isCompleted = true
            session.endTime = Date()
            session.actualDuration = Int(totalTime - timeRemaining)
            
            // Add break time to the paused focus session
            if let focusSession = pausedFocusSession {
                focusSession.breakDuration += session.actualDuration
                print("🔄 Break recorded: \(session.actualDuration) seconds added to focus session")
            }
            
            // Save the break session
            do {
                try modelContext.save()
                print("✅ Break session saved successfully")
            } catch {
                print("❌ Error saving break session: \(error)")
            }
        }
        
        // Return to focus session if it exists and auto-resume
        if let focusSession = pausedFocusSession {
            isBreakSession = false
            timeRemaining = pausedFocusTimeRemaining
            totalTime = pausedFocusTotalTime
            currentSession = focusSession
            
            // Auto-resume the focus timer instead of requiring manual resume
            isTimerRunning = true
            isPaused = false
            
            // Update session timing for background calculation
            sessionStartTime = Date()
            sessionEndTime = Date().addingTimeInterval(timeRemaining)
            lastUpdateTime = Date()
            
            // Reschedule background notification for focus timer completion
            let completionDate = sessionEndTime ?? Date().addingTimeInterval(timeRemaining)
            notificationManager.scheduleTimerCompletionNotification(
                sessionType: "focus",
                taskName: selectedTask?.title,
                fireDate: completionDate
            )
            
            // Update Live Activity to show focus session and resume
            if #available(iOS 16.1, *), let liveActivityManager = liveActivityManager {
                liveActivityManager.resumeActivityWithSessionType(
                    remainingTime: timeRemaining,
                    sessionType: .focus,
                    taskName: selectedTask?.title
                )
            }
            
            // Start the focus timer with proper background calculation
            // Ensure any existing timer is invalidated before creating new one
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                // Update timer using background-aware calculation
                self.updateTimerWithBackgroundCalculation()
                
                if self.timeRemaining > 0 {
                    // Update Live Activity every 30 seconds to reduce battery impact
                    if Int(self.timeRemaining) % 30 == 0 {
                        if #available(iOS 16.1, *), let liveActivityManager = self.liveActivityManager {
                            liveActivityManager.updateActivity(remainingTime: self.timeRemaining)
                        }
                    }
                } else {
                    self.completeFocusSession()
                }
            }
        } else {
            // No previous focus session, reset normally
            isBreakSession = false
            timeRemaining = selectedDuration * 60
            totalTime = selectedDuration * 60
            currentSession = nil
            
            // End Live Activity since no focus session to return to
            if #available(iOS 16.1, *), let liveActivityManager = liveActivityManager {
                liveActivityManager.endCurrentActivity(completed: false)
            }
        }
        
        // Clear stored focus session state (already cleared above for successful transition)
        if pausedFocusSession != nil {
            pausedFocusSession = nil
            pausedFocusTimeRemaining = 0
            pausedFocusTotalTime = 0
        }
        
        calculateWorkTimeToday()
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving endBreakEarly completion: \(error)")
        }
    }
    
    // MARK: - Utility Methods
    
    func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func colorFromString(_ colorString: String) -> Color {
        switch colorString {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "red": return .red
        default: return .blue
        }
    }
}