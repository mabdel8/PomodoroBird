//
//  SettingsView.swift
//  PomodoroApp
//
//  Created by Abdalla Abdelmagid on 7/23/25.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FocusSession.createdAt, order: .reverse) private var focusSessions: [FocusSession]
    
    @State private var pomodoroDuration = 25
    @State private var breakDuration = 5
    @State private var selectedAlarmSound = "Default"
    @State private var focusReminders = true
    @State private var breakReminders = true
    @State private var dailySummaryNotifications = true
    @State private var showingResetAlert = false
    @State private var showingClearSessionsAlert = false
    @State private var showingExportSheet = false
    
    private let alarmSounds = ["Default", "Bell", "Chime", "Gentle", "None"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Timer Preferences
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("Timer Preferences")
                        timerPreferencesContainer
                    }
                    
                    // Notifications
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("Notifications")
                        notificationsContainer
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
            .sheet(isPresented: $showingExportSheet) {
                ExportDataView(focusSessions: focusSessions)
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
        }
    }
    
    // MARK: - Timer Preferences Section
    private var timerPreferencesContainer: some View {
        VStack(spacing: 0) {
            pomodoroDurationRow
            Divider()
                .padding(.leading, 56)
            breakDurationRow
            Divider()
                .padding(.leading, 56)
            alarmSoundRow
        }
        .background(containerBackground())
    }
    
    private var pomodoroDurationRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Pomodoro Duration")
                    .font(.custom("Geist", size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("\(pomodoroDuration) minutes")
                    .font(.custom("Geist", size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Menu {
                ForEach([15, 20, 25, 30, 35, 40, 45, 50, 55, 60], id: \.self) { duration in
                    Button("\(duration) min") {
                        pomodoroDuration = duration
                    }
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var breakDurationRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Break Duration")
                    .font(.custom("Geist", size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("\(breakDuration) minutes")
                    .font(.custom("Geist", size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Menu {
                ForEach([3, 5, 7, 10, 15, 20], id: \.self) { duration in
                    Button("\(duration) min") {
                        breakDuration = duration
                    }
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var alarmSoundRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Alarm Sound")
                    .font(.custom("Geist", size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(selectedAlarmSound)
                    .font(.custom("Geist", size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Menu {
                ForEach(alarmSounds, id: \.self) { sound in
                    Button(sound) {
                        selectedAlarmSound = sound
                    }
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    // MARK: - Notifications Section
    private var notificationsContainer: some View {
        VStack(spacing: 0) {
            focusRemindersRow
            Divider()
                .padding(.leading, 56)
            breakRemindersRow
            Divider()
                .padding(.leading, 56)
            dailySummaryRow
        }
        .background(containerBackground())
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
    
    // MARK: - Data & Analytics Section
    private var dataAnalyticsContainer: some View {
        VStack(spacing: 0) {
            settingsRow(
                title: "iCloud Backup",
                subtitle: "Sync data across devices",
                icon: "icloud",
                action: { /* Handle iCloud backup */ }
            )
            Divider()
                .padding(.leading, 56)
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
        }
        .background(containerBackground())
    }
    
    // MARK: - Support Section
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
                action: { /* Handle app store rating */ }
            )
            Divider()
                .padding(.leading, 56)
            settingsRow(
                title: "Contact Support",
                subtitle: "Get help and support",
                icon: "envelope",
                action: { /* Handle support contact */ }
            )
        }
        .background(containerBackground())
    }
    
    // MARK: - About Section
    private var aboutContainer: some View {
        VStack(spacing: 0) {
            versionRow
            Divider()
                .padding(.leading, 56)
            settingsRow(
                title: "Terms of Service",
                subtitle: "Read our terms",
                icon: "doc.text",
                action: { /* Handle terms */ }
            )
            Divider()
                .padding(.leading, 56)
            settingsRow(
                title: "Privacy Policy",
                subtitle: "Read our privacy policy",
                icon: "hand.raised",
                action: { /* Handle privacy policy */ }
            )
        }
        .background(containerBackground())
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
        // Reset all settings to defaults
        pomodoroDuration = 25
        breakDuration = 5
        selectedAlarmSound = "Default"
        focusReminders = true
        breakReminders = true
        dailySummaryNotifications = true
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

#Preview {
    SettingsView()
        .modelContainer(for: [FocusTag.self, Task.self, FocusSession.self, AppTimerState.self], inMemory: true)
} 