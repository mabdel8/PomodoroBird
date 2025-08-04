//
//  SettingsComponents.swift
//  PomodoroApp
//
//  Created by Claude Code on 7/31/25.
//

import SwiftUI

// MARK: - Timer Settings View
struct TimerSettingsView: View {
    @Binding var selectedDuration: Double
    @ObservedObject var notificationManager: NotificationManager
    let onDurationChange: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    
    let quickDurations = [1, 5, 10, 15, 20, 25, 30, 45, 60, 90, 120]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Timer Duration Section
                    VStack(spacing: 20) {
                        VStack(spacing: 8) {
                            Text("Timer Duration")
                                .font(.custom("Geist", size: 20))
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text("Select a duration for focus sessions")
                                .font(.custom("Geist", size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        // Quick duration buttons
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 16) {
                            ForEach(quickDurations, id: \.self) { duration in
                                Button(action: {
                                    selectedDuration = Double(duration)
                                    onDurationChange(Double(duration))
                                }) {
                                    VStack(spacing: 4) {
                                        Text("\(duration)")
                                            .font(.custom("Geist", size: 18))
                                            .fontWeight(.semibold)
                                            .foregroundColor(selectedDuration == Double(duration) ? .white : .primary)
                                        
                                        Text("min")
                                            .font(.custom("Geist", size: 12))
                                            .fontWeight(.medium)
                                            .foregroundColor(selectedDuration == Double(duration) ? .white.opacity(0.8) : .secondary)
                                    }
                                    .frame(height: 60)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(selectedDuration == Double(duration) ? Color.blue : Color.gray.opacity(0.1))
                                            .stroke(selectedDuration == Double(duration) ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                .scaleEffect(selectedDuration == Double(duration) ? 1.05 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: selectedDuration)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Alarm Settings Section
                    VStack(spacing: 20) {
                        VStack(spacing: 8) {
                            Text("Alarm Settings")
                                .font(.custom("Geist", size: 20))
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text("Customize how you're notified when timers complete")
                                .font(.custom("Geist", size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        VStack(spacing: 16) {
                            // Sound Alert Toggle
                            SettingsToggleRow(
                                title: "Sound Alert",
                                description: "Play sound when timer completes",
                                isOn: $notificationManager.enableSoundAlert
                            )
                            
                            // Haptic Feedback Toggle
                            SettingsToggleRow(
                                title: "Haptic Feedback",
                                description: "Vibrate when timer completes",
                                isOn: $notificationManager.enableHapticFeedback
                            )
                            
                            // Notifications Toggle
                            SettingsToggleRow(
                                title: "Notifications",
                                description: "Show notification when app is backgrounded",
                                isOn: $notificationManager.enableNotifications
                            )
                            
                            // Alarm Sound Selection
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Alarm Sound")
                                    .font(.custom("Geist", size: 16))
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 12) {
                                    ForEach(NotificationManager.AlarmSound.allCases, id: \.self) { sound in
                                        Button(action: {
                                            notificationManager.selectedAlarmSound = sound
                                            notificationManager.testAlarmSound()
                                            notificationManager.saveSettings()
                                        }) {
                                            Text(sound.displayName)
                                                .font(.custom("Geist", size: 14))
                                                .fontWeight(.medium)
                                                .foregroundColor(notificationManager.selectedAlarmSound == sound ? .white : .primary)
                                                .frame(height: 44)
                                                .frame(maxWidth: .infinity)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(notificationManager.selectedAlarmSound == sound ? Color.blue : Color.gray.opacity(0.1))
                                                        .stroke(notificationManager.selectedAlarmSound == sound ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                                                )
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Testing Section
                    VStack(spacing: 20) {
                        VStack(spacing: 8) {
                            Text("Testing Mode")
                                .font(.custom("Geist", size: 20))
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text("Enable short durations for testing timer functionality")
                                .font(.custom("Geist", size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        VStack(spacing: 16) {
                            // Test Mode Toggle
                            SettingsToggleRow(
                                title: "Enable Test Mode",
                                description: "Use seconds instead of minutes for quick testing",
                                isOn: $notificationManager.isTestModeEnabled
                            ) {
                                notificationManager.saveSettings()
                            }
                            
                            if notificationManager.isTestModeEnabled {
                                VStack(spacing: 16) {
                                    // Test Focus Duration
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Test Focus Duration")
                                            .font(.custom("Geist", size: 16))
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        
                                        HStack(spacing: 12) {
                                            Stepper(value: $notificationManager.testFocusDuration, in: 3...60, step: 1) {
                                                Text("\(notificationManager.testFocusDuration) seconds")
                                                    .font(.custom("Geist", size: 14))
                                                    .foregroundColor(.secondary)
                                            }
                                            .onChange(of: notificationManager.testFocusDuration) { _, _ in
                                                notificationManager.saveSettings()
                                            }
                                        }
                                    }
                                    
                                    // Test Break Duration
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Test Break Duration")
                                            .font(.custom("Geist", size: 16))
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        
                                        HStack(spacing: 12) {
                                            Stepper(value: $notificationManager.testBreakDuration, in: 3...30, step: 1) {
                                                Text("\(notificationManager.testBreakDuration) seconds")
                                                    .font(.custom("Geist", size: 14))
                                                    .foregroundColor(.secondary)
                                            }
                                            .onChange(of: notificationManager.testBreakDuration) { _, _ in
                                                notificationManager.saveSettings()
                                            }
                                        }
                                    }
                                }
                                .padding(.leading, 16)
                            }
                            
                            // Bird Hatching Test Mode
                            SettingsToggleRow(
                                title: "Fast Bird Hatching",
                                description: "Earn birds after 15 seconds instead of 10 minutes",
                                isOn: $notificationManager.enableBirdHatchingTestMode
                            ) {
                                notificationManager.saveSettings()
                            }
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        notificationManager.saveSettings()
                        dismiss()
                    }
                    .font(.custom("Geist", size: 16))
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                }
            }
            .onAppear {
                notificationManager.checkNotificationPermission()
            }
        }
    }
}

// MARK: - Settings Toggle Row
struct SettingsToggleRow: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    let onToggle: (() -> Void)?
    
    init(title: String, description: String, isOn: Binding<Bool>, onToggle: (() -> Void)? = nil) {
        self.title = title
        self.description = description
        self._isOn = isOn
        self.onToggle = onToggle
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("Geist", size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.custom("Geist", size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .onChange(of: isOn) { _, _ in
                    onToggle?()
                }
        }
        .padding(.vertical, 8)
    }
}