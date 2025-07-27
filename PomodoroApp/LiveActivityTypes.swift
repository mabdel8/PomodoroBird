//
//  LiveActivityTypes.swift
//  PomodoroApp
//
//  Created by Mohamed Abdelmagid on 7/27/25.
//

import Foundation
import ActivityKit
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

// MARK: - Session Type Extension

extension PomodoroTimerAttributes.ContentState.SessionType {
    init(fromString sessionType: String) {
        switch sessionType {
        case "focus": self = .focus
        case "break": self = .shortBreak
        case "short_break": self = .shortBreak
        case "long_break": self = .longBreak
        default: self = .focus
        }
    }
}