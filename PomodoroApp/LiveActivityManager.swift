//
//  LiveActivityManager.swift
//  PomodoroApp
//
//  Created by Mohamed Abdelmagid on 7/27/25.
//

import Foundation
import ActivityKit
import BackgroundTasks
import UserNotifications

// Resolve Task ambiguity with SwiftData
typealias AsyncTask = _Concurrency.Task

@available(iOS 16.1, *)
class LiveActivityManager: ObservableObject {
    @Published var currentActivity: Activity<PomodoroTimerAttributes>?
    
    private let userDefaults = UserDefaults(suiteName: "group.com.pomodoroapp.shared") ?? .standard
    
    init() {
        // Check for existing activities on app launch
        AsyncTask {
            await checkForExistingActivities()
        }
    }
    
    // MARK: - Activity Management
    
    func startActivity(duration: TimeInterval, sessionType: PomodoroTimerAttributes.ContentState.SessionType, taskName: String?) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities are not enabled")
            return
        }
        
        // End any existing activity first
        endCurrentActivity()
        
        let sessionId = UUID().uuidString
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(duration)
        
        let attributes = PomodoroTimerAttributes(
            sessionId: sessionId,
            startTime: startTime
        )
        
        let initialState = PomodoroTimerAttributes.ContentState(
            timerEnd: endTime,
            sessionType: sessionType,
            taskName: taskName,
            isPaused: false,
            totalDuration: duration,
            remainingTime: duration
        )
        
        do {
            let activityContent = ActivityContent(
                state: initialState,
                staleDate: Calendar.current.date(byAdding: .minute, value: 30, to: Date())
            )
            
            let activity = try Activity<PomodoroTimerAttributes>.request(
                attributes: attributes,
                content: activityContent
            )
            
            currentActivity = activity
            saveActivityState(activity: activity, state: initialState)
            
            print("✅ Started Live Activity: \(activity.id)")
            
        } catch {
            print("❌ Error starting Live Activity: \(error.localizedDescription)")
        }
    }
    
    func pauseActivity() {
        guard let activity = currentActivity else { return }
        
        AsyncTask {
            let currentState = activity.content.state
            let now = Date()
            let actualRemainingTime = max(0, currentState.timerEnd.timeIntervalSince(now))
            
            let updatedState = PomodoroTimerAttributes.ContentState(
                timerEnd: Date.distantFuture, // Set to distant future to stop countdown
                sessionType: currentState.sessionType,
                taskName: currentState.taskName,
                isPaused: true,
                totalDuration: currentState.totalDuration,
                remainingTime: actualRemainingTime
            )
            
            let updatedContent = ActivityContent(
                state: updatedState,
                staleDate: Calendar.current.date(byAdding: .minute, value: 30, to: Date())
            )
            
            await activity.update(updatedContent)
            saveActivityState(activity: activity, state: updatedState)
            
            print("⏸️ Paused Live Activity")
        }
    }
    
    func resumeActivity(remainingTime: TimeInterval) {
        guard let activity = currentActivity else { return }
        
        AsyncTask {
            let currentState = activity.content.state
            let newEndTime = Date().addingTimeInterval(remainingTime)
            
            let updatedState = PomodoroTimerAttributes.ContentState(
                timerEnd: newEndTime,
                sessionType: currentState.sessionType,
                taskName: currentState.taskName,
                isPaused: false,
                totalDuration: currentState.totalDuration,
                remainingTime: remainingTime
            )
            
            let updatedContent = ActivityContent(
                state: updatedState,
                staleDate: Calendar.current.date(byAdding: .minute, value: 30, to: Date())
            )
            
            await activity.update(updatedContent)
            saveActivityState(activity: activity, state: updatedState)
            
            print("▶️ Resumed Live Activity")
        }
    }
    
    func resumeActivityWithSessionType(remainingTime: TimeInterval, sessionType: PomodoroTimerAttributes.ContentState.SessionType, taskName: String?) {
        guard let activity = currentActivity else { return }
        
        AsyncTask {
            let currentState = activity.content.state
            let newEndTime = Date().addingTimeInterval(remainingTime)
            
            let updatedState = PomodoroTimerAttributes.ContentState(
                timerEnd: newEndTime,
                sessionType: sessionType,
                taskName: taskName,
                isPaused: false,
                totalDuration: currentState.totalDuration,
                remainingTime: remainingTime
            )
            
            let updatedContent = ActivityContent(
                state: updatedState,
                staleDate: Calendar.current.date(byAdding: .minute, value: 30, to: Date())
            )
            
            await activity.update(updatedContent)
            saveActivityState(activity: activity, state: updatedState)
            
            print("▶️ Resumed Live Activity with session type: \(sessionType.displayName)")
        }
    }
    
    func updateActivity(remainingTime: TimeInterval) {
        guard let activity = currentActivity else { return }
        
        AsyncTask {
            let currentState = activity.content.state
            
            // Only update if not paused and there's a significant change
            guard !currentState.isPaused else { return }
            
            let updatedState = PomodoroTimerAttributes.ContentState(
                timerEnd: currentState.timerEnd,
                sessionType: currentState.sessionType,
                taskName: currentState.taskName,
                isPaused: false,
                totalDuration: currentState.totalDuration,
                remainingTime: remainingTime
            )
            
            let updatedContent = ActivityContent(
                state: updatedState,
                staleDate: Calendar.current.date(byAdding: .minute, value: 30, to: Date())
            )
            
            await activity.update(updatedContent)
            saveActivityState(activity: activity, state: updatedState)
        }
    }
    
    func endCurrentActivity(completed: Bool = false) {
        guard let activity = currentActivity else { return }
        
        AsyncTask {
            let currentState = activity.content.state
            let finalState = PomodoroTimerAttributes.ContentState(
                timerEnd: Date(),
                sessionType: currentState.sessionType,
                taskName: currentState.taskName,
                isPaused: false,
                totalDuration: currentState.totalDuration,
                remainingTime: 0
            )
            
            let finalContent = ActivityContent(
                state: finalState,
                staleDate: nil
            )
            
            await activity.end(
                finalContent,
                dismissalPolicy: .immediate
            )
            
            currentActivity = nil
            clearActivityState()
            
            print("⏹️ Ended Live Activity (completed: \(completed))")
        }
    }
    
    // MARK: - Background Support
    
    func scheduleBackgroundAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.pomodoroapp.timer-refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 10 * 60) // 10 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("📅 Scheduled background app refresh")
        } catch {
            print("❌ Could not schedule background refresh: \(error.localizedDescription)")
        }
    }
    
    func handleBackgroundAppRefresh(task: BGAppRefreshTask) {
        // Schedule the next background refresh
        scheduleBackgroundAppRefresh()
        
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // Update live activity if needed
        AsyncTask {
            await syncActivityWithAppState()
            task.setTaskCompleted(success: true)
        }
    }
    
    // MARK: - State Persistence
    
    private func saveActivityState(activity: Activity<PomodoroTimerAttributes>, state: PomodoroTimerAttributes.ContentState) {
        let activityData = ActivityData(
            id: activity.id,
            sessionId: activity.attributes.sessionId,
            startTime: activity.attributes.startTime,
            state: state
        )
        
        if let encoded = try? JSONEncoder().encode(activityData) {
            userDefaults.set(encoded, forKey: "current_activity")
            userDefaults.set(Date(), forKey: "last_update")
        }
    }
    
    private func clearActivityState() {
        userDefaults.removeObject(forKey: "current_activity")
        userDefaults.removeObject(forKey: "last_update")
    }
    
    private func loadActivityState() -> ActivityData? {
        guard let data = userDefaults.data(forKey: "current_activity"),
              let activityData = try? JSONDecoder().decode(ActivityData.self, from: data) else {
            return nil
        }
        return activityData
    }
    
    // MARK: - Sync with App State
    
    private func checkForExistingActivities() async {
        let activities = Activity<PomodoroTimerAttributes>.activities
        
        if let activity = activities.first {
            currentActivity = activity
            print("🔄 Found existing Live Activity: \(activity.id)")
        }
    }
    
    private func syncActivityWithAppState() async {
        guard let activityData = loadActivityState(),
              let activity = currentActivity else { return }
        
        let now = Date()
        let timeSinceLastUpdate = now.timeIntervalSince(userDefaults.object(forKey: "last_update") as? Date ?? now)
        
        // If more than 1 minute has passed, update the activity
        if timeSinceLastUpdate > 60 {
            let currentState = activity.content.state
            let actualRemainingTime = max(0, currentState.timerEnd.timeIntervalSince(now))
            
            let updatedState = PomodoroTimerAttributes.ContentState(
                timerEnd: currentState.timerEnd,
                sessionType: currentState.sessionType,
                taskName: currentState.taskName,
                isPaused: currentState.isPaused,
                totalDuration: currentState.totalDuration,
                remainingTime: actualRemainingTime
            )
            
            let updatedContent = ActivityContent(
                state: updatedState,
                staleDate: Calendar.current.date(byAdding: .minute, value: 30, to: Date())
            )
            
            await activity.update(updatedContent)
            saveActivityState(activity: activity, state: updatedState)
        }
    }
    
    // MARK: - Utility Methods
    
    func requestActivityPermission() {
        // ActivityKit permissions are handled automatically when requesting an activity
        // But we can check the current status
        let authInfo = ActivityAuthorizationInfo()
        print("📱 Live Activities enabled: \(authInfo.areActivitiesEnabled)")
    }
}

// MARK: - Supporting Types

struct ActivityData: Codable {
    let id: String
    let sessionId: String
    let startTime: Date
    let state: PomodoroTimerAttributes.ContentState
}

