//
//  NotificationManager.swift
//  PomodoroApp
//
//  Created by Mohamed Abdelmagid on 7/27/25.
//

import Foundation
import UserNotifications
import AudioToolbox
import UIKit

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isNotificationPermissionGranted = false
    @Published var selectedAlarmSound: AlarmSound = .defaultSound
    @Published var enableHapticFeedback = true
    @Published var enableSoundAlert = true
    @Published var enableNotifications = true
    
    // Testing settings
    @Published var testFocusDuration: Int = 25 // minutes
    @Published var testBreakDuration: Int = 5 // minutes
    @Published var isTestModeEnabled = false
    @Published var enableBirdHatchingTestMode = false // Test bird hatching at 15 seconds instead of 10 minutes
    
    enum AlarmSound: String, CaseIterable {
        case defaultSound = "default"
        case bell = "bell"
        case chime = "chime"
        case ding = "ding"
        case gentle = "gentle"
        case vibrationOnly = "vibration"
        
        var displayName: String {
            switch self {
            case .defaultSound: return "Default"
            case .bell: return "Bell"
            case .chime: return "Chime"
            case .ding: return "Ding"
            case .gentle: return "Gentle"
            case .vibrationOnly: return "Vibration Only"
            }
        }
        
        var systemSoundID: SystemSoundID? {
            switch self {
            case .defaultSound: return 1005 // SMS received
            case .bell: return 1013 // SMS received 4
            case .chime: return 1016 // SMS received 5
            case .ding: return 1003 // SMS received 2
            case .gentle: return 1004 // SMS received 3
            case .vibrationOnly: return nil
            }
        }
    }
    
    private init() {
        loadSettings()
        requestNotificationPermission()
    }
    
    // MARK: - Permission Management
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.isNotificationPermissionGranted = granted
                if let error = error {
                    print("❌ Notification permission error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isNotificationPermissionGranted = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Timer Completion Alerts
    
    func triggerTimerCompletionAlert(sessionType: String, taskName: String?) {
        print("🔔 Triggering timer completion alert for \(sessionType)")
        
        // Play sound
        if enableSoundAlert {
            playAlarmSound()
        }
        
        // Trigger haptics
        if enableHapticFeedback {
            triggerHapticFeedback()
        }
        
        // Send local notification (if app is backgrounded)
        if enableNotifications {
            sendCompletionNotification(sessionType: sessionType, taskName: taskName)
        }
    }
    
    private func playAlarmSound() {
        guard let soundID = selectedAlarmSound.systemSoundID else {
            // Vibration only
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            return
        }
        
        AudioServicesPlaySystemSound(soundID)
    }
    
    private func triggerHapticFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        // Add a second vibration after a short delay for emphasis
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            impactFeedback.impactOccurred()
        }
    }
    
    private func sendCompletionNotification(sessionType: String, taskName: String?) {
        let content = UNMutableNotificationContent()
        
        if sessionType == "focus" {
            content.title = "Focus Session Complete! 🎯"
            if let taskName = taskName {
                content.body = "Great work on \(taskName)! Time for a break?"
            } else {
                content.body = "Great focus session! Time for a break?"
            }
        } else {
            content.title = "Break Time Over! ⏰"
            content.body = "Ready to get back to work?"
        }
        
        content.sound = UNNotificationSound.default
        content.badge = 1
        
        let request = UNNotificationRequest(
            identifier: "timer-completion-\(UUID().uuidString)",
            content: content,
            trigger: nil // Immediate delivery
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send notification: \(error.localizedDescription)")
            } else {
                print("✅ Timer completion notification sent")
            }
        }
    }
    
    // MARK: - Background Timer Notifications
    
    func scheduleTimerCompletionNotification(sessionType: String, taskName: String?, fireDate: Date) {
        // Cancel any existing timer notifications
        cancelTimerNotifications()
        
        let content = UNMutableNotificationContent()
        
        if sessionType == "focus" {
            content.title = "Focus Session Complete! 🎯"
            if let taskName = taskName {
                content.body = "Great work on \(taskName)! Time for a break?"
            } else {
                content.body = "Great focus session! Time for a break?"
            }
        } else {
            content.title = "Break Time Over! ⏰"
            content.body = "Ready to get back to work?"
        }
        
        content.sound = UNNotificationSound.default
        content.badge = 1
        content.userInfo = ["sessionType": sessionType, "fireDate": fireDate.timeIntervalSince1970]
        
        // Add deep link to open timer tab
        content.categoryIdentifier = "TIMER_COMPLETE"
        content.userInfo["deeplink"] = "pomodoroapp://timer"
        
        // Use time interval trigger instead of calendar trigger for better reliability
        let timeInterval = fireDate.timeIntervalSinceNow
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, timeInterval), // Ensure minimum 1 second
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "timer-completion-scheduled",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule timer notification: \(error.localizedDescription)")
            } else {
                print("✅ Timer completion notification scheduled for \(fireDate)")
            }
        }
    }
    
    func cancelTimerNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["timer-completion-scheduled"])
        print("🗑️ Cancelled timer notifications")
    }
    
    // MARK: - Settings Persistence
    
    private func loadSettings() {
        let defaults = UserDefaults.standard
        
        // Load alarm settings
        if let soundRawValue = defaults.object(forKey: "selectedAlarmSound") as? String,
           let sound = AlarmSound(rawValue: soundRawValue) {
            selectedAlarmSound = sound
        }
        
        enableHapticFeedback = defaults.object(forKey: "enableHapticFeedback") as? Bool ?? true
        enableSoundAlert = defaults.object(forKey: "enableSoundAlert") as? Bool ?? true
        enableNotifications = defaults.object(forKey: "enableNotifications") as? Bool ?? true
        
        // Load test settings
        testFocusDuration = defaults.object(forKey: "testFocusDuration") as? Int ?? 25
        testBreakDuration = defaults.object(forKey: "testBreakDuration") as? Int ?? 5
        isTestModeEnabled = defaults.object(forKey: "isTestModeEnabled") as? Bool ?? false
        enableBirdHatchingTestMode = defaults.object(forKey: "enableBirdHatchingTestMode") as? Bool ?? false
    }
    
    func saveSettings() {
        let defaults = UserDefaults.standard
        
        // Save alarm settings
        defaults.set(selectedAlarmSound.rawValue, forKey: "selectedAlarmSound")
        defaults.set(enableHapticFeedback, forKey: "enableHapticFeedback")
        defaults.set(enableSoundAlert, forKey: "enableSoundAlert")
        defaults.set(enableNotifications, forKey: "enableNotifications")
        
        // Save test settings
        defaults.set(testFocusDuration, forKey: "testFocusDuration")
        defaults.set(testBreakDuration, forKey: "testBreakDuration")
        defaults.set(isTestModeEnabled, forKey: "isTestModeEnabled")
        defaults.set(enableBirdHatchingTestMode, forKey: "enableBirdHatchingTestMode")
        
        print("💾 Notification settings saved")
    }
    
    // MARK: - Test Duration Helpers
    
    func getEffectiveFocusDuration() -> TimeInterval {
        if isTestModeEnabled {
            return TimeInterval(testFocusDuration) // Use seconds for test mode
        } else {
            return TimeInterval(testFocusDuration * 60) // Convert minutes to seconds for normal mode
        }
    }
    
    func getEffectiveBreakDuration() -> TimeInterval {
        if isTestModeEnabled {
            return TimeInterval(testBreakDuration) // Use seconds for test mode
        } else {
            return TimeInterval(testBreakDuration * 60) // Convert minutes to seconds for normal mode
        }
    }
    
    func getEffectiveBirdHatchingDuration() -> TimeInterval {
        if enableBirdHatchingTestMode {
            return 15.0 // 15 seconds for testing
        } else {
            return 600.0 // 10 minutes (600 seconds) for normal mode
        }
    }
    
    // MARK: - Utility Methods
    
    func testAlarmSound() {
        playAlarmSound()
        if enableHapticFeedback {
            triggerHapticFeedback()
        }
    }
}