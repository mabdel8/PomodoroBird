//
//  PomodoroAppApp.swift
//  PomodoroApp
//
//  Created by Mohamed Abdelmagid on 7/23/25.
//

import SwiftUI
import SwiftData
import BackgroundTasks
import ActivityKit

@main
struct PomodoroAppApp: App {
    @StateObject private var cloudKitManager = CloudKitManager.shared
    
    var sharedModelContainer: ModelContainer {
        return CloudKitManager.shared.modelContainer
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(cloudKitManager)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    scheduleBackgroundAppRefresh()
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .onAppear {
                    cloudKitManager.checkCloudKitAvailability()
                }
        }
        .modelContainer(sharedModelContainer)
        .backgroundTask(.appRefresh("com.pomodoroapp.timer-refresh")) {
            await handleBackgroundAppRefresh()
        }
    }
    
    // MARK: - Background Task Handling
    
    private func scheduleBackgroundAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.pomodoroapp.timer-refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 10 * 60) // 10 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("📅 Scheduled background app refresh")
        } catch {
            print("❌ Could not schedule background refresh: \(error.localizedDescription)")
        }
    }
    
    private func handleBackgroundAppRefresh() async {
        // Schedule the next background refresh
        scheduleBackgroundAppRefresh()
        
        // Sync Live Activities if available
        if #available(iOS 16.1, *) {
            await syncLiveActivities()
        }
    }
    
    @available(iOS 16.1, *)
    private func syncLiveActivities() async {
        // Update any active Live Activities
        for activity in Activity<PomodoroTimerAttributes>.activities {
            let currentState = activity.content.state
            let now = Date()
            let actualRemainingTime = max(0, currentState.timerEnd.timeIntervalSince(now))
            
            if actualRemainingTime <= 0 {
                // Timer completed, end the activity
                await activity.end(nil, dismissalPolicy: .immediate)
            } else {
                // Update remaining time
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
            }
        }
    }
    
    // MARK: - Deep Link Handling
    
    private func handleDeepLink(_ url: URL) {
        // Handle deep links from Live Activity taps
        if url.scheme == "pomodoroapp" {
            switch url.host {
            case "timer":
                // Open timer tab
                NotificationCenter.default.post(name: .openTimerTab, object: nil)
            default:
                break
            }
        }
    }
}

extension Notification.Name {
    static let openTimerTab = Notification.Name("openTimerTab")
}
