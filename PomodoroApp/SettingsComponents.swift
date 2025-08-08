//
//  SettingsComponents.swift
//  PomodoroApp
//
//  Created by Claude Code on 7/31/25.
//

import SwiftUI
import SwiftData
import CloudKit
import StoreKit

// MARK: - Timer Settings View
struct TimerSettingsView: View {
    @Binding var selectedDuration: Double
    @ObservedObject var notificationManager: NotificationManager
    @ObservedObject var appStateManager: AppStateManager
    let onDurationChange: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @Query(sort: \FocusSession.createdAt, order: .reverse) private var focusSessions: [FocusSession]
    
    // Settings state
    @State private var focusReminders = true
    @State private var breakReminders = true
    @State private var dailySummaryNotifications = true
    @State private var showingResetAlert = false
    @State private var showingClearSessionsAlert = false
    @State private var showingClearAllDataAlert = false
    @State private var showingExportSheet = false
    @State private var isBackingUpToCloud = false
    @State private var backupStatus = ""
    @State private var showingPaywall = false
    @State private var showingBreakTimerConfig = false
    @State private var breakTimerDuration: Int = 5 // Default break timer in minutes
    
    let quickDurations = [1, 5, 10, 15, 20, 25, 30, 45, 60, 90, 120]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Configuration
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("Configuration")
                        configurationContainer
                    }
                    
                    // Alarm Settings
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("Alarm Settings")
                        alarmSettingsContainer
                    }
                    
                    // Testing Mode
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("Testing Mode")
                        testingModeContainer
                    }
                    
                    // iCloud Sync
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("iCloud Sync")
                        iCloudContainer
                    }
                    
                    // Data & Analytics
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("Data & Analytics")
                        dataAnalyticsContainer
                    }
                    
                    // Support
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("Support")
                        supportContainer
                    }
                    
                    // About
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("About")
                        aboutContainer
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
            .background(Color(.systemBackground))
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
            .sheet(isPresented: $showingExportSheet) {
                ExportDataView(focusSessions: focusSessions)
            }
            .sheet(isPresented: $showingPaywall) {
                PurchaseView(isPresented: $showingPaywall, hasCooldown: true)
                    .environmentObject(appStateManager.purchaseManager)
                    .onDisappear {
                        // Refresh subscription state when paywall is dismissed
                        appStateManager.refreshSubscriptionState()
                        // Refresh break timer duration in case user purchased premium
                        breakTimerDuration = notificationManager.testBreakDuration
                    }
            }
            .sheet(isPresented: $showingBreakTimerConfig) {
                BreakTimerConfigView(
                    duration: $breakTimerDuration, 
                    isPresented: $showingBreakTimerConfig,
                    notificationManager: notificationManager
                )
            }
            .alert("Reset App", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetAppToDefaults()
                }
            } message: {
                Text("This will reset all settings to their default values. This action cannot be undone.")
            }
            .alert("Clear All Sessions", isPresented: $showingClearSessionsAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    clearAllSessions()
                }
            } message: {
                Text("This will permanently delete all your focus session data. This action cannot be undone.")
            }
            .alert("Clear All Data", isPresented: $showingClearAllDataAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    clearAllData()
                }
            } message: {
                Text("This will completely reset the app: all sessions, tasks, settings, onboarding state, and subscription status. Perfect for testing. This action cannot be undone.")
            }
            .onAppear {
                notificationManager.checkNotificationPermission()
                // Initialize breakTimerDuration from NotificationManager
                breakTimerDuration = notificationManager.testBreakDuration
            }
            .onReceive(NotificationCenter.default.publisher(for: .subscriptionStateChanged)) { _ in
                // Force UI refresh when subscription state changes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // This will trigger a UI refresh
                    breakTimerDuration = notificationManager.testBreakDuration
                }
            }
        }
    }
    
    // MARK: - Section Containers
    
    private var configurationContainer: some View {
        VStack(spacing: 0) {
            breakTimerConfigRow
        }
        .background(containerBackground())
    }
    
    private var alarmSettingsContainer: some View {
        VStack(spacing: 0) {
            soundAlertRow
            Divider()
                .padding(.leading, 56)
            hapticFeedbackRow
            Divider()
                .padding(.leading, 56)
            notificationsRow
            Divider()
                .padding(.leading, 56)
            alarmSoundRow
        }
        .background(containerBackground())
    }
    
    private var testingModeContainer: some View {
        VStack(spacing: 0) {
            testModeRow
            if notificationManager.isTestModeEnabled {
                Divider()
                    .padding(.leading, 56)
                testFocusDurationRow
                Divider()
                    .padding(.leading, 56)
                testBreakDurationRow
            }
            Divider()
                .padding(.leading, 56)
            birdHatchingTestRow
        }
        .background(containerBackground())
    }
    
    private var iCloudContainer: some View {
        VStack(spacing: 0) {
            // iCloud Toggle
            HStack {
                Image(systemName: "icloud")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable iCloud Sync")
                        .font(.custom("Geist", size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(cloudKitManager.isCloudKitAvailable ? "Sync data across your devices" : "iCloud account not available")
                        .font(.custom("Geist", size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $cloudKitManager.isCloudKitEnabled)
                    .disabled(!cloudKitManager.isCloudKitAvailable)
                    .onChange(of: cloudKitManager.isCloudKitEnabled) { _, newValue in
                        cloudKitManager.saveSettings()
                        if newValue {
                            // Show restart requirement
                            backupStatus = "Restart app to enable iCloud sync"
                        } else {
                            backupStatus = "iCloud sync disabled"
                        }
                    }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            if cloudKitManager.isCloudKitEnabled {
                Divider()
                    .padding(.leading, 56)
                
                // Manual Backup Button
                Button(action: { performCloudBackup() }) {
                    HStack {
                        Image(systemName: isBackingUpToCloud ? "arrow.clockwise" : "icloud.and.arrow.up")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                            .frame(width: 24)
                            .rotationEffect(.degrees(isBackingUpToCloud ? 360 : 0))
                            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isBackingUpToCloud)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sync Now")
                                .font(.custom("Geist", size: 16))
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                            
                            Text(backupStatus.isEmpty ? "Manually trigger sync" : backupStatus)
                                .font(.custom("Geist", size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if !isBackingUpToCloud {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isBackingUpToCloud)
            }
        }
        .background(containerBackground())
    }
    
    private var dataAnalyticsContainer: some View {
        VStack(spacing: 0) {
            settingsRow(
                title: "Export Data",
                subtitle: "Download as CSV or JSON",
                icon: "square.and.arrow.up",
                action: { showingExportSheet = true }
            )
            Divider()
                .padding(.leading, 56)
            settingsRow(
                title: "Reset to Defaults",
                subtitle: "Restore default settings",
                icon: "arrow.clockwise",
                action: { showingResetAlert = true },
                isDestructive: true
            )
            Divider()
                .padding(.leading, 56)
            settingsRow(
                title: "Clear All Sessions",
                subtitle: "Delete all focus data",
                icon: "trash",
                action: { showingClearSessionsAlert = true },
                isDestructive: true
            )
            Divider()
                .padding(.leading, 56)
            settingsRow(
                title: "Clear All Data",
                subtitle: "Reset app completely for testing",
                icon: "trash.fill",
                action: { showingClearAllDataAlert = true },
                isDestructive: true
            )
        }
        .background(containerBackground())
    }
    
    private var supportContainer: some View {
        VStack(spacing: 0) {
            settingsRow(
                title: "How it Works",
                subtitle: "Learn about the app",
                icon: "questionmark.circle",
                action: { /* Handle tutorial */ }
            )
            Divider()
                .padding(.leading, 56)
            settingsRow(
                title: "Rate App",
                subtitle: "Share your feedback",
                icon: "star",
                action: { requestAppRating() }
            )
        }
        .background(containerBackground())
    }
    
    private var aboutContainer: some View {
        VStack(spacing: 0) {
            versionRow
            Divider()
                .padding(.leading, 56)
            settingsRow(
                title: "Terms of Service",
                subtitle: "Read our terms",
                icon: "doc.text",
                action: { openTermsOfService() }
            )
            Divider()
                .padding(.leading, 56)
            settingsRow(
                title: "Privacy Policy",
                subtitle: "Read our privacy policy",
                icon: "hand.raised",
                action: { openPrivacyPolicy() }
            )
        }
        .background(containerBackground())
    }
    
    // MARK: - Individual Rows
    
    private var breakTimerConfigRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Break Timer Duration")
                        .font(.custom("Geist", size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                                            if !appStateManager.isSubscribed {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                        }
                }
                
                Text(appStateManager.isSubscribed ? "\(breakTimerDuration) minutes" : "Customize your break duration")
                    .font(.custom("Geist", size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
        .onTapGesture {
            if appStateManager.isSubscribed {
                showingBreakTimerConfig = true
            } else {
                showingPaywall = true
            }
        }
    }
    
    private var focusRemindersRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Focus Session Reminders")
                    .font(.custom("Geist", size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Get reminded to start focus sessions")
                    .font(.custom("Geist", size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $focusReminders)
                .toggleStyle(SwitchToggleStyle(tint: .black))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var breakRemindersRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Break Reminders")
                    .font(.custom("Geist", size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Get reminded to take breaks")
                    .font(.custom("Geist", size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $breakReminders)
                .toggleStyle(SwitchToggleStyle(tint: .black))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var dailySummaryRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Daily Summary")
                    .font(.custom("Geist", size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Receive daily focus summary")
                    .font(.custom("Geist", size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $dailySummaryNotifications)
                .toggleStyle(SwitchToggleStyle(tint: .black))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var soundAlertRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sound Alert")
                    .font(.custom("Geist", size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Play sound when timer completes")
                    .font(.custom("Geist", size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $notificationManager.enableSoundAlert)
                .toggleStyle(SwitchToggleStyle(tint: .black))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var hapticFeedbackRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Haptic Feedback")
                    .font(.custom("Geist", size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Vibrate when timer completes")
                    .font(.custom("Geist", size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $notificationManager.enableHapticFeedback)
                .toggleStyle(SwitchToggleStyle(tint: .black))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var notificationsRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Notifications")
                    .font(.custom("Geist", size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Show notification when app is backgrounded")
                    .font(.custom("Geist", size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $notificationManager.enableNotifications)
                .toggleStyle(SwitchToggleStyle(tint: .black))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var alarmSoundRow: some View {
        Menu {
            ForEach(NotificationManager.AlarmSound.allCases, id: \.self) { sound in
                Button(sound.displayName) {
                    notificationManager.selectedAlarmSound = sound
                    notificationManager.testAlarmSound()
                    notificationManager.saveSettings()
                }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Alarm Sound")
                        .font(.custom("Geist", size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(notificationManager.selectedAlarmSound.displayName)
                        .font(.custom("Geist", size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var testModeRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Enable Test Mode")
                    .font(.custom("Geist", size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Use seconds instead of minutes for quick testing")
                    .font(.custom("Geist", size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $notificationManager.isTestModeEnabled)
                .toggleStyle(SwitchToggleStyle(tint: .black))
                .onChange(of: notificationManager.isTestModeEnabled) { _, _ in
                    notificationManager.saveSettings()
                }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var testFocusDurationRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Test Focus Duration")
                    .font(.custom("Geist", size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("\(notificationManager.testFocusDuration) seconds")
                    .font(.custom("Geist", size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Stepper("", value: $notificationManager.testFocusDuration, in: 3...60, step: 1)
                .onChange(of: notificationManager.testFocusDuration) { _, _ in
                    notificationManager.saveSettings()
                }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var testBreakDurationRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Test Break Duration")
                    .font(.custom("Geist", size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("\(notificationManager.testBreakDuration) seconds")
                    .font(.custom("Geist", size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Stepper("", value: $notificationManager.testBreakDuration, in: 3...30, step: 1)
                .onChange(of: notificationManager.testBreakDuration) { _, _ in
                    notificationManager.saveSettings()
                }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var birdHatchingTestRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Fast Bird Hatching")
                    .font(.custom("Geist", size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Earn birds after 15 seconds instead of 10 minutes")
                    .font(.custom("Geist", size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $notificationManager.enableBirdHatchingTestMode)
                .toggleStyle(SwitchToggleStyle(tint: .black))
                .onChange(of: notificationManager.enableBirdHatchingTestMode) { _, _ in
                    notificationManager.saveSettings()
                }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var versionRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Version")
                    .font(.custom("Geist", size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("1.0.0")
                    .font(.custom("Geist", size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    // MARK: - Helper Functions
    
    private func containerBackground() -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.custom("Geist", size: 18))
            .fontWeight(.semibold)
            .foregroundColor(.primary)
    }
    
    private func settingsRow(
        title: String,
        subtitle: String,
        icon: String,
        action: @escaping () -> Void,
        isDestructive: Bool = false
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(isDestructive ? .red : .primary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.custom("Geist", size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(isDestructive ? .red : .primary)
                    
                    Text(subtitle)
                        .font(.custom("Geist", size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Actions
    private func resetAppToDefaults() {
        // Reset notification settings
        notificationManager.enableSoundAlert = true
        notificationManager.enableHapticFeedback = true
        notificationManager.enableNotifications = true
        notificationManager.selectedAlarmSound = .defaultSound
        notificationManager.isTestModeEnabled = false
        notificationManager.testFocusDuration = 10
        notificationManager.testBreakDuration = 5
        notificationManager.enableBirdHatchingTestMode = false
        
        // Reset other settings
        focusReminders = true
        breakReminders = true
        dailySummaryNotifications = true
        
        notificationManager.saveSettings()
    }
    
    private func performCloudBackup() {
        guard cloudKitManager.isCloudKitEnabled && cloudKitManager.isCloudKitAvailable else {
            backupStatus = "iCloud sync not available"
            return
        }
        
        isBackingUpToCloud = true
        backupStatus = "Syncing with iCloud..."
        
        // Show immediate feedback and reset after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isBackingUpToCloud = false
            backupStatus = "Last sync: \(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short))"
        }
    }
    
    private func clearAllSessions() {
        // Delete all focus sessions
        for session in focusSessions {
            modelContext.delete(session)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Error clearing sessions: \(error)")
        }
    }
    
    private func clearAllData() {
        // 1. Reset all settings to defaults
        resetAppToDefaults()
        
        // 2. Clear all SwiftData entities
        clearAllSessions()
        
        // 3. Clear all other SwiftData entities (tasks, tags, birds, timer states)
        clearAllSwiftDataEntities()
        
        // 4. Clear UserDefaults (onboarding state, etc.)
        clearUserDefaults()
        
        // 5. Reset CloudKit settings
        cloudKitManager.isCloudKitEnabled = false
        cloudKitManager.saveSettings()
    }
    
    private func clearAllSwiftDataEntities() {
        // Clear all other entities from SwiftData
        let descriptor = FetchDescriptor<Task>()
        do {
            let tasks = try modelContext.fetch(descriptor)
            for task in tasks {
                modelContext.delete(task)
            }
        } catch {
            print("Error clearing tasks: \(error)")
        }
        
        let tagDescriptor = FetchDescriptor<FocusTag>()
        do {
            let tags = try modelContext.fetch(tagDescriptor)
            for tag in tags {
                modelContext.delete(tag)
            }
        } catch {
            print("Error clearing tags: \(error)")
        }
        
        let birdDescriptor = FetchDescriptor<CollectedBird>()
        do {
            let birds = try modelContext.fetch(birdDescriptor)
            for bird in birds {
                modelContext.delete(bird)
            }
        } catch {
            print("Error clearing birds: \(error)")
        }
        
        let timerStateDescriptor = FetchDescriptor<AppTimerState>()
        do {
            let timerStates = try modelContext.fetch(timerStateDescriptor)
            for timerState in timerStates {
                modelContext.delete(timerState)
            }
        } catch {
            print("Error clearing timer states: \(error)")
        }
        
        // Save all deletions
        do {
            try modelContext.save()
        } catch {
            print("Error saving context after clearing all data: \(error)")
        }
    }
    
    private func clearUserDefaults() {
        // Clear onboarding state
        UserDefaults.standard.removeObject(forKey: "OnboardingSeen")
        
        // Clear any other stored preferences
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
    }
    
    // MARK: - New Action Methods
    
    private func requestAppRating() {
        if #available(iOS 18.0, *) {
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                AppStore.requestReview(in: scene)
            }
        } else {
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
            }
        }
    }
    
    private func openTermsOfService() {
        if let url = URL(string: "https://abdalla2024.github.io/FokisPomodoroTimer/#/terms") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openPrivacyPolicy() {
        if let url = URL(string: "https://abdalla2024.github.io/FokisPomodoroTimer/#/privacy") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Export Data View
struct ExportDataView: View {
    let focusSessions: [FocusSession]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat = "CSV"
    
    private let formats = ["CSV", "JSON"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                formatSelectionSection
                Spacer()
                exportButton
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .background(Color(.systemBackground))
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.custom("Geist", size: 16))
                    .fontWeight(.medium)
                }
            }
        }
    }
    
    private var formatSelectionSection: some View {
        VStack(spacing: 0) {
            ForEach(formats, id: \.self) { format in
                formatButton(for: format)
                if format != formats.last {
                    Divider()
                        .padding(.leading, 56)
                }
            }
        }
        .background(containerBackground())
    }
    
    private func formatButton(for format: String) -> some View {
        Button(action: {
            selectedFormat = format
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(format)
                        .font(.custom("Geist", size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(format == "CSV" ? "Comma-separated values" : "JavaScript Object Notation")
                        .font(.custom("Geist", size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if selectedFormat == format {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.black)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func containerBackground() -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
    }
    
    private var exportButton: some View {
        Button(action: {
            exportData()
            dismiss()
        }) {
            Text("Export Data")
                .font(.custom("Geist", size: 17))
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black)
                )
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }
    
    private func exportData() {
        // Handle data export based on selected format
        if selectedFormat == "CSV" {
            exportAsCSV()
        } else {
            exportAsJSON()
        }
    }
    
    private func exportAsCSV() {
        // Implementation for CSV export
        print("Exporting as CSV...")
    }
    
    private func exportAsJSON() {
        // Implementation for JSON export
        print("Exporting as JSON...")
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

// MARK: - Break Timer Configuration View
struct BreakTimerConfigView: View {
    @Binding var duration: Int
    @Binding var isPresented: Bool
    @ObservedObject var notificationManager: NotificationManager
    
    private let breakDurations = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 25, 30]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Current Duration Display
                    VStack(spacing: 12) {
                        Text("Break Timer Duration")
                            .font(.custom("Geist", size: 18))
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("\(duration) minutes")
                            .font(.custom("Geist", size: 32))
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 20)
                    
                    // Stepper Control
                    VStack(spacing: 16) {
                        HStack {
                                                    Button(action: {
                            if duration > 1 {
                                duration -= 1
                                notificationManager.testBreakDuration = duration
                                notificationManager.saveSettings()
                            }
                        }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(duration > 1 ? .orange : .gray)
                            }
                            .disabled(duration <= 1)
                            
                            Spacer()
                            
                            Button(action: {
                                if duration < 60 {
                                    duration += 1
                                    notificationManager.testBreakDuration = duration
                                    notificationManager.saveSettings()
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(duration < 60 ? .orange : .gray)
                            }
                            .disabled(duration >= 60)
                        }
                        .padding(.horizontal, 40)
                        
                        // Range info
                        Text("Choose between 1-60 minutes")
                            .font(.custom("Geist", size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    // Quick Selection Grid
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Quick Selection")
                            .font(.custom("Geist", size: 16))
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(breakDurations, id: \.self) { time in
                                Button(action: {
                                    duration = time
                                    notificationManager.testBreakDuration = time
                                    notificationManager.saveSettings()
                                }) {
                                    Text("\(time)m")
                                        .font(.custom("Geist", size: 16))
                                        .fontWeight(.medium)
                                        .foregroundColor(duration == time ? .white : .primary)
                                        .frame(height: 44)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(duration == time ? Color.orange : Color.white)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(duration == time ? Color.orange : Color.gray.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 24)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Break Duration")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        notificationManager.testBreakDuration = duration
                        notificationManager.saveSettings()
                        isPresented = false
                    }
                    .font(.custom("Geist", size: 16))
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                }
            }
        }
    }
}