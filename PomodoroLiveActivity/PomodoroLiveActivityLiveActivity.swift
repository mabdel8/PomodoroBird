//
//  PomodoroLiveActivityLiveActivity.swift
//  PomodoroLiveActivity
//
//  Created by Mohamed Abdelmagid on 7/26/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

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
                .activityBackgroundTint(context.state.sessionType.color.opacity(0.1))
                .activitySystemActionForegroundColor(context.state.sessionType.color)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        Label {
                            Text(context.state.sessionType.displayName)
                                .font(.caption)
                                .fontWeight(.semibold)
                        } icon: {
                            Image(systemName: context.state.sessionType.icon)
                                .foregroundColor(context.state.sessionType.color)
                        }
                        
                        if let taskName = context.state.taskName {
                            Text(taskName)
                                .font(.caption2)
                                .lineLimit(1)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        if context.state.isPaused {
                            HStack(spacing: 4) {
                                Image(systemName: "pause.circle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Paused")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Text(context.state.timerEnd, style: .timer)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundColor(context.state.sessionType.color)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        // Progress bar
                        ProgressView(value: progressValue(for: context.state), total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle(tint: context.state.sessionType.color))
                            .frame(height: 4)
                        
                        Spacer()
                        
                        // Time remaining
                        Text(timeString(from: context.state.remainingTime))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.sessionType.icon)
                    .foregroundColor(context.state.sessionType.color)
                    .font(.caption)
            } compactTrailing: {
                VStack(spacing: 2) {
                    if context.state.isPaused {
                        Image(systemName: "pause.circle.fill")
                            .foregroundColor(.orange)
                            .font(.caption2)
                    }
                    Text(context.state.timerEnd, style: .timer)
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundColor(context.state.sessionType.color)
                }
            } minimal: {
                Image(systemName: context.state.sessionType.icon)
                    .foregroundColor(context.state.sessionType.color)
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
            HStack {
                // Session type and task info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: context.state.sessionType.icon)
                            .foregroundColor(context.state.sessionType.color)
                        
                        Text(context.state.sessionType.displayName)
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    if let taskName = context.state.taskName {
                        Text(taskName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Timer display
                VStack(alignment: .trailing, spacing: 4) {
                    if context.state.isPaused {
                        HStack(spacing: 4) {
                            Image(systemName: "pause.circle.fill")
                                .foregroundColor(.orange)
                            Text("Paused")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text(context.state.timerEnd, style: .timer)
                        .font(.title)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundColor(context.state.sessionType.color)
                }
            }
            
            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(timeString(from: context.state.remainingTime))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: progressValue(for: context.state), total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: context.state.sessionType.color))
                    .frame(height: 6)
            }
        }
        .padding(16)
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
