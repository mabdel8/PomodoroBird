//
//  PomodoroLiveActivityLiveActivity.swift
//  PomodoroLiveActivity
//
//  Created by Mohamed Abdelmagid on 7/26/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

// Shared Live Activity Types
struct PomodoroTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var timerEnd: Date
        var sessionType: SessionType
        var taskName: String?
        var isPaused: Bool
        var totalDuration: TimeInterval
        var remainingTime: TimeInterval
        
        enum SessionType: String, Codable, CaseIterable {
            case focus = "focus"
            case shortBreak = "short_break"
            case longBreak = "long_break"
            
            var displayName: String {
                switch self {
                case .focus: return "Focus Time"
                case .shortBreak: return "Short Break"
                case .longBreak: return "Long Break"
                }
            }
            
            var color: Color {
                switch self {
                case .focus: return .blue
                case .shortBreak, .longBreak: return .orange
                }
            }
            
            var icon: String {
                switch self {
                case .focus: return "brain.head.profile"
                case .shortBreak, .longBreak: return "cup.and.saucer"
                }
            }
        }
    }

    // Fixed non-changing properties about your activity go here!
    var sessionId: String
    var startTime: Date
}

struct PomodoroTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroTimerAttributes.self) { context in
            // Lock screen/banner UI goes here
            LockScreenLiveActivityView(context: context)
                .activityBackgroundTint(.black.opacity(0.8))
                .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI - Clean and simple
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 6) {
                        // Session type with icon
                        HStack(spacing: 6) {
                            Image(systemName: context.state.sessionType.icon)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(context.state.sessionType.color)
                                .padding(.top, 6)
                            
                            Text(context.state.sessionType.displayName)
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.top, 6)
                        }
                        
//                        // Task name
                        if let taskName = context.state.taskName {
                            Text(taskName)
                                .font(.system(.caption2, design: .rounded, weight: .medium))
                                .lineLimit(1)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 6) {
                        // Timer
                        Text(context.state.timerEnd, style: .timer)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .monospacedDigit()
                            .foregroundColor(.white)
                        
                        // Status
                        Text(context.state.isPaused ? "Paused" : "Active")
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                            .foregroundColor(context.state.isPaused ? .orange : .green)
                            .padding(.top, 6)
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    // Simple progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.white.opacity(0.2))
                                .frame(height: 4)
                            
                            RoundedRectangle(cornerRadius: 3)
                                .fill(context.state.sessionType.color)
                                .frame(
                                    width: geometry.size.width * progressValue(for: context.state),
                                    height: 4
                                )
                        }
                    }
                    .frame(height: 4)
                }
            } compactLeading: {
                Circle()
                    .fill(context.state.sessionType.color)
                    .frame(width: 16, height: 16)
                    .overlay {
                        Image(systemName: context.state.sessionType.icon)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                    }
            } compactTrailing: {
                VStack(alignment: .trailing, spacing: 2) {
                    if context.state.isPaused {
                        Text("PAUSED")
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                            .foregroundColor(.orange)
                    }
                    Text(context.state.timerEnd, style: .timer)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(.white)
                }
            } minimal: {
                Circle()
                    .fill(context.state.sessionType.color)
                    .frame(width: 16, height: 16)
                    .overlay {
                        Image(systemName: context.state.sessionType.icon)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                    }
            }
            .widgetURL(URL(string: "pomodoroapp://timer"))
            .keylineTint(context.state.sessionType.color)
        }
    }
    
    private func progressValue(for state: PomodoroTimerAttributes.ContentState) -> Double {
        let elapsed = state.totalDuration - state.remainingTime
        return elapsed / state.totalDuration
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<PomodoroTimerAttributes>
    
    var body: some View {
        VStack(spacing: 16) {
            // Top section: Session info and status
            HStack {
                // Left: Session type with icon
                HStack(spacing: 8) {
                    Image(systemName: context.state.sessionType.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(context.state.sessionType.color)
                    
                    Text(context.state.sessionType.displayName)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Right: Status badge
                Text(context.state.isPaused ? "Paused" : "Active")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundColor(context.state.isPaused ? .orange : .green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(context.state.isPaused ? .orange.opacity(0.2) : .green.opacity(0.2))
                    )
            }
            
            // Center section: Large timer display
            HStack {
                Spacer()
                
                VStack(spacing: 4) {
                    Text(context.state.timerEnd, style: .timer)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(.white)
                    
//                    if let taskName = context.state.taskName {
//                        Text(taskName)
//                            .font(.system(.subheadline, design: .rounded, weight: .medium))
//                            .foregroundColor(.white.opacity(0.7))
//                            .lineLimit(1)
//                    }
                }
                
                Spacer()
            }
            
            // Bottom section: Progress bar
            VStack(spacing: 8) {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white.opacity(0.2))
                            .frame(height: 6)
                        
                        // Progress fill
                        RoundedRectangle(cornerRadius: 4)
                            .fill(context.state.sessionType.color)
                            .frame(
                                width: geometry.size.width * progressValue(for: context.state),
                                height: 6
                            )
                    }
                }
                .frame(height: 6)
                
                // Progress info
                HStack {
                    Text(timeString(from: context.state.totalDuration - context.state.remainingTime) + " elapsed")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Spacer()
                    
                    Text(timeString(from: context.state.remainingTime) + " remaining")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.black.opacity(0.85))
        )
    }
    
    private func progressValue(for state: PomodoroTimerAttributes.ContentState) -> Double {
        let elapsed = state.totalDuration - state.remainingTime
        return max(0, min(1, elapsed / state.totalDuration))
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

extension PomodoroTimerAttributes {
    fileprivate static var preview: PomodoroTimerAttributes {
        PomodoroTimerAttributes(
            sessionId: "preview-session",
            startTime: Date()
        )
    }
}

extension PomodoroTimerAttributes.ContentState {
    fileprivate static var focusActive: PomodoroTimerAttributes.ContentState {
        PomodoroTimerAttributes.ContentState(
            timerEnd: Date().addingTimeInterval(15 * 60), // 15 minutes remaining
            sessionType: .focus,
            taskName: "iOS App Development",
            isPaused: false,
            totalDuration: 25 * 60, // 25 minutes total
            remainingTime: 15 * 60 // 15 minutes remaining
        )
    }
    
    fileprivate static var breakPaused: PomodoroTimerAttributes.ContentState {
        PomodoroTimerAttributes.ContentState(
            timerEnd: Date().addingTimeInterval(3 * 60), // 3 minutes remaining
            sessionType: .shortBreak,
            taskName: nil,
            isPaused: true,
            totalDuration: 5 * 60, // 5 minutes total
            remainingTime: 3 * 60 // 3 minutes remaining
        )
    }
}

#Preview("Notification", as: .content, using: PomodoroTimerAttributes.preview) {
   PomodoroTimerLiveActivity()
} contentStates: {
    PomodoroTimerAttributes.ContentState.focusActive
    PomodoroTimerAttributes.ContentState.breakPaused
}
