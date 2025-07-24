//
//  Models.swift
//  PomodoroApp
//
//  Created by Mohamed Abdelmagid on 7/23/25.
//

import Foundation
import SwiftData

@Model
final class PomodoroTag {
    var id: UUID = UUID()
    var name: String = ""
    var color: String = "blue" // Store as string for CloudKit compatibility
    var createdAt: Date = Date()
    
    // Optional relationship for CloudKit
    var sessions: [PomodoroSession]? = []
    
    init(name: String = "", color: String = "blue") {
        self.id = UUID()
        self.name = name
        self.color = color
        self.createdAt = Date()
        self.sessions = []
    }
}

@Model
final class PomodoroSession {
    var id: UUID = UUID()
    var duration: Int = 1500 // Default 25 minutes in seconds
    var actualDuration: Int = 0
    var isCompleted: Bool = false
    var wasBreakTaken: Bool = false
    var startTime: Date? = nil
    var endTime: Date? = nil
    var createdAt: Date = Date()
    
    // Optional relationship for CloudKit
    var tag: PomodoroTag? = nil
    
    init(duration: Int = 1500, tag: PomodoroTag? = nil) {
        self.id = UUID()
        self.duration = duration
        self.actualDuration = 0
        self.isCompleted = false
        self.wasBreakTaken = false
        self.startTime = nil
        self.endTime = nil
        self.createdAt = Date()
        self.tag = tag
    }
}

@Model
final class TimerState {
    var id: UUID = UUID()
    var isRunning: Bool = false
    var isPaused: Bool = false
    var currentSessionId: UUID? = nil
    var timeRemaining: Int = 1500 // Default 25 minutes
    var selectedDuration: Int = 1500
    
    // Optional relationship for CloudKit
    var currentSession: PomodoroSession? = nil
    
    init() {
        self.id = UUID()
        self.isRunning = false
        self.isPaused = false
        self.currentSessionId = nil
        self.timeRemaining = 1500
        self.selectedDuration = 1500
        self.currentSession = nil
    }
}
