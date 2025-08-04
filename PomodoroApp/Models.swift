//
//  Models.swift
//  PomodoroApp
//
//  Created by Mohamed Abdelmagid on 7/23/25.
//

import Foundation
import SwiftData

enum BirdType: String, CaseIterable, Codable {
    case scientistbird = "scientistbird"
    case artistbird = "artistbird"
    case chefbird = "chefbird"
    case magicianbird = "magicianbird"
    case mexicanbird = "MexBird"
    case businessbird = "businessbird"
    case detectivebird = "detectivebird"
    case doctorbird = "doctorbird"
    case firefighterbird = "firefighterbird"
    case kingbird = "kingbird"
    case ninjabird = "ninjabird"
    case piratebird = "piratebird"
    case punkbird = "punkbird"
    case swimmingbird = "swimmingbird"
    case wizardbird = "wizardbird"
    case astronautbird = "Astrobird"
    case farmerbird = "farmerbird"
    case musicianbird = "musicianbird"
    
    var displayName: String {
        switch self {
        case .scientistbird: return "Scientist Bird"
        case .artistbird: return "Artist Bird"
        case .chefbird: return "Chef Bird"
        case .magicianbird: return "Magician Bird"
        case .mexicanbird: return "Mexican Bird"
        case .businessbird: return "Business Bird"
        case .detectivebird: return "Detective Bird"
        case .doctorbird: return "Doctor Bird"
        case .firefighterbird: return "Firefighter Bird"
        case .kingbird: return "King Bird"
        case .ninjabird: return "Ninja Bird"
        case .piratebird: return "Pirate Bird"
        case .punkbird: return "Punk Bird"
        case .swimmingbird: return "Swimming Bird"
        case .wizardbird: return "Wizard Bird"
        case .astronautbird: return "Astronaut Bird"
        case .farmerbird: return "Farmer Bird"
        case .musicianbird: return "Musician Bird"
        }
    }
    
    var eggImageName: String {
        // For now, use the generic egg image since bird-specific eggs may not exist yet
        return "egg"
    }
    
    var birdImageName: String {
        return rawValue
    }
}

@Model
final class FocusTag {
    var id: UUID = UUID()
    var name: String = ""
    var color: String = "blue"
    var createdAt: Date = Date()
    
    init(name: String = "", color: String = "blue") {
        self.id = UUID()
        self.name = name
        self.color = color
        self.createdAt = Date()
    }
}

@Model
final class Task {
    var id: UUID = UUID()
    var title: String = ""
    var isCompleted: Bool = false
    var createdAt: Date = Date()
    var completedAt: Date?
    var plannedDate: Date = Date() // Date when task is planned to be done
    var duration: Int = 25 // duration in minutes
    
    // Tag relationship stored as values for CloudKit compatibility
    var tagId: UUID?
    var tagName: String?
    var tagColor: String?
    
    init(title: String = "", duration: Int = 25, tag: FocusTag? = nil, plannedDate: Date = Date()) {
        self.id = UUID()
        self.title = title
        self.duration = duration
        self.isCompleted = false
        self.createdAt = Date()
        self.completedAt = nil
        self.plannedDate = plannedDate
        
        if let tag = tag {
            self.tagId = tag.id
            self.tagName = tag.name
            self.tagColor = tag.color
        } else {
            self.tagId = nil
            self.tagName = nil
            self.tagColor = nil
        }
    }
}

@Model
final class FocusSession {
    var id: UUID = UUID()
    var duration: Int = 1500
    var actualDuration: Int = 0
    var isCompleted: Bool = false
    var wasBreakTaken: Bool = false
    var breakDuration: Int = 0 // Total break time in seconds
    var startTime: Date?
    var endTime: Date?
    var createdAt: Date = Date()
    var sessionType: String = "focus" // "focus" or "break"
    
    // Task reference for CloudKit compatibility
    var taskId: UUID?
    var taskTitle: String?
    var tagId: UUID?
    var tagName: String?
    var tagColor: String?
    
    init(duration: Int = 1500, task: Task? = nil, sessionType: String = "focus") {
        self.id = UUID()
        self.duration = duration
        self.actualDuration = 0
        self.isCompleted = false
        self.wasBreakTaken = false
        self.breakDuration = 0
        self.startTime = nil
        self.endTime = nil
        self.createdAt = Date()
        self.sessionType = sessionType
        
        if let task = task {
            self.taskId = task.id
            self.taskTitle = task.title
            self.tagId = task.tagId
            self.tagName = task.tagName
            self.tagColor = task.tagColor
        } else {
            self.taskId = nil
            self.taskTitle = nil
            self.tagId = nil
            self.tagName = nil
            self.tagColor = nil
        }
    }
}

@Model
final class AppTimerState {
    var id: UUID = UUID()
    var isRunning: Bool = false
    var isPaused: Bool = false
    var currentSessionId: UUID?
    var timeRemaining: Int = 1500
    var selectedDuration: Int = 1500
    var isBreakSession: Bool = false // Track if current session is a break
    
    init() {
        self.id = UUID()
        self.isRunning = false
        self.isPaused = false
        self.currentSessionId = nil
        self.timeRemaining = 1500
        self.selectedDuration = 1500
        self.isBreakSession = false
    }
}

@Model
final class CollectedBird {
    var id: UUID = UUID()
    var birdTypeRawValue: String = "" // Store the raw value of BirdType enum
    var collectedAt: Date = Date()
    var fromSessionId: UUID? // Reference to the focus session that earned this bird
    
    var birdType: BirdType? {
        return BirdType(rawValue: birdTypeRawValue)
    }
    
    init(birdType: BirdType, fromSessionId: UUID? = nil) {
        self.id = UUID()
        self.birdTypeRawValue = birdType.rawValue
        self.collectedAt = Date()
        self.fromSessionId = fromSessionId
    }
}
