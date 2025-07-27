//
//  ContentView.swift
//  PomodoroApp
//
//  Created by Mohamed Abdelmagid on 7/23/25.
//

import SwiftUI
import SwiftData
import Foundation
import ActivityKit
import BackgroundTasks

// Custom SVG-inspired icons
struct CustomPlayIcon: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 5.25, y: 5.653))
            path.addCurve(
                to: CGPoint(x: 6.917, y: 4.667),
                control1: CGPoint(x: 5.25, y: 4.797),
                control2: CGPoint(x: 6.167, y: 4.255)
            )
            path.addLine(to: CGPoint(x: 18.457, y: 11.014))
            path.addCurve(
                to: CGPoint(x: 18.457, y: 12.986),
                control1: CGPoint(x: 19.082, y: 11.389),
                control2: CGPoint(x: 19.082, y: 12.611)
            )
            path.addLine(to: CGPoint(x: 6.917, y: 19.333))
            path.addCurve(
                to: CGPoint(x: 5.25, y: 18.347),
                control1: CGPoint(x: 6.167, y: 19.745),
                control2: CGPoint(x: 5.25, y: 19.203)
            )
            path.addLine(to: CGPoint(x: 5.25, y: 5.653))
            path.closeSubpath()
        }
        .stroke(Color.primary, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        .frame(width: 24, height: 24)
    }
}

struct CustomTimerIcon: View {
    var body: some View {
        Path { path in
            // Clock face (circle)
            path.addEllipse(in: CGRect(x: 3, y: 3, width: 18, height: 18))
            
            // Hour hand (12 to 6)
            path.move(to: CGPoint(x: 12, y: 6))
            path.addLine(to: CGPoint(x: 12, y: 12))
            
            // Minute hand (12 to 4.5)
            path.move(to: CGPoint(x: 12, y: 12))
            path.addLine(to: CGPoint(x: 16.5, y: 12))
        }
        .stroke(Color.primary, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        .frame(width: 24, height: 24)
    }
}

struct CustomTaskIcon: View {
    var body: some View {
        Path { path in
            // Clipboard outline
            path.move(to: CGPoint(x: 6, y: 6.878))
            path.addLine(to: CGPoint(x: 6, y: 6))
            path.addCurve(
                to: CGPoint(x: 8.25, y: 3.75),
                control1: CGPoint(x: 6, y: 4.756),
                control2: CGPoint(x: 7.006, y: 3.75)
            )
            path.addLine(to: CGPoint(x: 15.75, y: 3.75))
            path.addCurve(
                to: CGPoint(x: 18, y: 6),
                control1: CGPoint(x: 16.994, y: 3.75),
                control2: CGPoint(x: 18, y: 4.756)
            )
            path.addLine(to: CGPoint(x: 18, y: 6.878))
            
            // Inner rectangle
            path.move(to: CGPoint(x: 4.5, y: 9))
            path.addLine(to: CGPoint(x: 4.5, y: 18))
            path.addCurve(
                to: CGPoint(x: 6.75, y: 20.25),
                control1: CGPoint(x: 4.5, y: 19.244),
                control2: CGPoint(x: 5.506, y: 20.25)
            )
            path.addLine(to: CGPoint(x: 17.25, y: 20.25))
            path.addCurve(
                to: CGPoint(x: 19.5, y: 18),
                control1: CGPoint(x: 18.494, y: 20.25),
                control2: CGPoint(x: 19.5, y: 19.244)
            )
            path.addLine(to: CGPoint(x: 19.5, y: 9))
            path.addCurve(
                to: CGPoint(x: 18, y: 6.878),
                control1: CGPoint(x: 19.5, y: 8.02),
                control2: CGPoint(x: 18.874, y: 7.191)
            )
        }
        .stroke(Color.primary, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        .frame(width: 24, height: 24)
    }
}

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TimerView(selectedTab: $selectedTab)
                .tabItem {
                    Image(selectedTab == 0 ? "timerfilled" : "timer")
                        .renderingMode(.template)
                    Text("Timer")
                }
                .tag(0)
            
            TaskManagerView()
                .tabItem {
                    Image(selectedTab == 1 ? "stackfilled" : "stack")
                        .renderingMode(.template)
                    Text("Tasks")
                }
               .tag(1)
            
            AnalyticsView()
                .tabItem {
                    Image(selectedTab == 2 ? "chartsfilled" : "charts")
                        .renderingMode(.template)
                    Text("Analytics")
                }
                .tag(2)

        }
        .accentColor(.blue)
    }
}

struct TimerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FocusTag.name) private var tags: [FocusTag]
    @Query(filter: #Predicate<Task> { !$0.isCompleted }, sort: \Task.createdAt, order: .reverse) private var availableTasks: [Task]
    @Query private var timerStates: [AppTimerState]
    @Query(sort: \FocusSession.createdAt, order: .reverse) private var recentSessions: [FocusSession]
    @Binding var selectedTab: Int
    
    // Live Activity Manager (iOS 16.1+)
    @State private var liveActivityManager: LiveActivityManager?
    
    // Notification Manager
    @StateObject private var notificationManager = NotificationManager.shared
    
    @State private var selectedTask: Task?
    @State private var selectedDuration: Double = 25.0 // in minutes
    @State private var timeRemaining: TimeInterval = 1500 // 25 minutes in seconds
    @State private var totalTime: TimeInterval = 1500
    @State private var isTimerRunning = false
    @State private var isPaused = false
    @State private var isBreakSession = false
    @State private var timer: Timer?
    @State private var currentSession: FocusSession?
    @State private var workTimeToday: Int = 0 // in minutes
    @State private var showingTaskSelector = false
    @State private var breakSuggestionTime: TimeInterval?
    
    // Store paused focus session state
    @State private var pausedFocusTimeRemaining: TimeInterval = 0
    @State private var pausedFocusTotalTime: TimeInterval = 0
    @State private var pausedFocusSession: FocusSession?
    @State private var showingCompletionDialog = false
    @State private var sessionToComplete: FocusSession?
    @State private var totalBreakTime: Int = 0 // Track break time in minutes for current session
    @State private var sessionWorkTime: Int = 0 // Track work time for current session in minutes
    @State private var showingSettings = false
    @State private var showingTaskCreation = false
    @State private var newTaskName = ""
    @State private var selectedTagForNewTask: FocusTag?
    @State private var unassignedSession: FocusSession?
    @State private var showingQuickTaskCreation = false
    @State private var quickTaskName = ""
    @State private var selectedTagForQuickTask: FocusTag?
    
    var timerState: AppTimerState? {
        timerStates.first
    }
    
    var progress: Double {
        guard totalTime > 0 else { return 0 }
        return (totalTime - timeRemaining) / totalTime
    }
    
    var lastUsedTask: Task? {
        // Get the most recent focus session's task
        guard let lastSession = recentSessions.first(where: { $0.sessionType == "focus" && $0.taskId != nil }),
              let taskId = lastSession.taskId else { return nil }
        return availableTasks.first(where: { $0.id == taskId })
    }
    
    var shouldSuggestBreak: Bool {
        false // Remove auto break suggestions
    }
    
    var nextBreakIn: String? {
        // No automatic break suggestions - removed per requirements
        return nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top navigation area
            HStack {
                Spacer()
                
                Button(action: { showingSettings = true }) {
                    Image("setting")
                        .renderingMode(.template)
                        .foregroundColor(.primary)
                        .font(.system(size: 20))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            // Top notification area (compact)
            if shouldSuggestBreak || nextBreakIn != nil {
                VStack(spacing: 12) {
                    if shouldSuggestBreak {
                        breakSuggestionBanner
                    }
                    
                    if let nextBreak = nextBreakIn {
                        Text(nextBreak)
                            .font(.custom("Geist", size: 12))
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.orange.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(.orange.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 8)
            }
            
            Spacer() // Push content to center
            
            // Main content - centered vertically
            VStack(spacing: 24) {
                // Current Task section (compact)
                currentTaskSection
                
                // Timer Display (main focus)
                timerDisplayWithProgress
                
                // Time Selector (horizontal scrolling - only when inactive)
                if !isTimerRunning && !isBreakSession && !isPaused {
                    tapeMeasureTimeSelector
                        .padding(.horizontal, 24)
                }
                
                // Control Buttons (right under timer/slider)
                controlButtons
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
            }
            .padding(.horizontal, 24)
            
            Spacer() // Push content to center (bottom spacer)
        }
        .padding(.bottom, 20) // Small space from tab bar
        .sheet(isPresented: $showingTaskSelector) {
            TaskSelectorSheet(
                availableTasks: availableTasks,
                selectedTask: selectedTask,
                onTaskSelected: { task in
                    selectedTask = task
                    if let task = task {
                        selectedDuration = Double(task.duration)
                        timeRemaining = selectedDuration * 60
                        totalTime = selectedDuration * 60
                    }
                    showingTaskSelector = false
                }
            )
        }
        .sheet(isPresented: $showingSettings) {
            TimerSettingsView(
                selectedDuration: $selectedDuration,
                notificationManager: notificationManager,
                onDurationChange: { newDuration in
                    selectedDuration = newDuration
                    if !isTimerRunning {
                        timeRemaining = newDuration * 60
                        totalTime = newDuration * 60
                    }
                }
            )
        }
        .sheet(isPresented: $showingTaskCreation) {
            TaskCreationSheet(
                taskName: $newTaskName,
                selectedTag: $selectedTagForNewTask,
                tags: tags,
                sessionDuration: unassignedSession?.actualDuration ?? 0,
                onSave: createTaskForSession,
                onSkip: skipTaskCreation
            )
        }
        .sheet(isPresented: $showingQuickTaskCreation) {
            QuickTaskCreationSheet(
                taskName: $quickTaskName,
                selectedTag: $selectedTagForQuickTask,
                tags: tags,
                onSave: createQuickTaskAndStartTimer,
                onCancel: cancelQuickTaskCreation
            )
        }
        .overlay {
            if showingCompletionDialog {
                CompletionPopupView(
                    session: sessionToComplete,
                    onComplete: confirmSessionCompletion,
                    onCancel: cancelSessionCompletion
                )
            }
        }
        .onAppear {
            setupInitialData()
            calculateWorkTimeToday()
            
            // Initialize Live Activity Manager if available
            if #available(iOS 16.1, *) {
                liveActivityManager = LiveActivityManager()
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // If user switches to timer tab while on break, return to focus timer and continue
            if newValue == 0 && isBreakSession {
                endBreakEarly()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openTimerTab)) { _ in
            selectedTab = 0 // Switch to timer tab
        }
    }
    
    private var breakSuggestionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "cup.and.heat.waves")
                .font(.system(size: 14))
                .foregroundColor(.orange)
            
            Text("Break time! \(workTimeToday)min done")
                .font(.custom("Geist", size: 12))
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            Button("Take Break") {
                startSuggestedBreak()
            }
            .font(.custom("Geist", size: 12))
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.orange)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.orange, lineWidth: 1)
                )
        )
    }
    
    private var currentTaskSection: some View {
        VStack(spacing: 12) {
            if isTimerRunning || isPaused {
                // Show current task when timer is active
                if let task = selectedTask {
                    VStack(spacing: 6) {
                        Text(isBreakSession ? "Break Time" : task.title)
                            .font(.custom("Geist", size: 18))
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                        
                        if !isBreakSession, let tagName = task.tagName, let tagColor = task.tagColor {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(colorFromString(tagColor))
                                    .frame(width: 8, height: 8)
                                
                                Text(tagName)
                                    .font(.custom("Geist", size: 12))
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(colorFromString(tagColor).opacity(0.1))
                            )
                        }
                    }
                } else if isBreakSession {
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "cup.and.heat.waves")
                                .font(.system(size: 16))
                                .foregroundColor(.orange)
                            
                            Text("Break Time")
                                .font(.custom("Geist", size: 18))
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        
                        Text("Take a moment to recharge")
                            .font(.custom("Geist", size: 12))
                            .fontWeight(.light)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                // Show task selector when timer is not active - compact tag style
                HStack {
                    Spacer()
                    Button(action: { showingTaskSelector = true }) {
                        HStack(spacing: 6) {
                            if let task = selectedTask {
                                if let tagColor = task.tagColor {
                                    Circle()
                                        .fill(colorFromString(tagColor))
                                        .frame(width: 6, height: 6)
                                }
                                
                                Text(task.title)
                                    .font(.custom("Geist", size: 12))
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            } else {
                                Text("Choose task")
                                    .font(.custom("Geist", size: 12))
                                    .fontWeight(.light)
                                    .foregroundColor(.secondary)
                            }
                            
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.secondary.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(.secondary.opacity(0.15), lineWidth: 0.5)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var timerDisplayWithProgress: some View {
        ZStack {
            // Main background circle - clean and minimal
            Circle()
                .stroke(Color.gray.opacity(0.1), lineWidth: 6)
                .frame(width: 280, height: 280)
            
            // Progress ring - cleaner design
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    isBreakSession ? Color.orange : Color.black,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 280, height: 280)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: progress)
            
            // Timer content
            VStack(spacing: 12) {
                Text(timeString(from: timeRemaining))
                    .font(.custom("Geist", size: 52))
                    .fontWeight(.thin)
                    .monospacedDigit()
                    .foregroundColor(.primary.opacity(0.6))
                    .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 0.5)
                    .scaleEffect(isTimerRunning ? 1.02 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: isTimerRunning)
                    .onChange(of: timeRemaining) { _ in
                        if isTimerRunning {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                // Small pulse animation on each second
                            }
                        }
                    }
                
                if isPaused {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.secondary)
                            .frame(width: 6, height: 6)
                            .opacity(0.6)
                        
                        Text("Paused")
                            .font(.custom("Geist", size: 16))
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Circle()
                            .fill(.secondary)
                            .frame(width: 6, height: 6)
                            .opacity(0.6)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.secondary.opacity(0.1))
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Time Selector Components
    
    private var durationDisplay: some View {
        Text("\(Int(selectedDuration)) min")
            .font(.custom("Geist", size: 20))
            .fontWeight(.medium)
            .foregroundColor(.primary)
            .animation(.easeInOut(duration: 0.2), value: selectedDuration)
    }
    
    
    private func tickMarkView(for minute: Int) -> some View {
        let isMajorTick = minute % 15 == 0
        let tickColor: Color = isMajorTick ? .primary : Color.secondary.opacity(0.5)
        
        return VStack(spacing: 4) {
            Rectangle()
                .fill(tickColor)
                .frame(
                    width: isMajorTick ? 2 : 1,
                    height: isMajorTick ? 20 : 12
                )
            
            if isMajorTick {
                Text("\(minute)")
                    .font(.custom("Geist", size: 11))
                    .fontWeight(.light)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 40)
        .contentShape(Rectangle())
        .id(minute)
    }
    
    private var timeScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    Spacer()
                        .frame(width: UIScreen.main.bounds.width / 2 - 20)
                    
                    ForEach(Array(stride(from: 5, through: 120, by: 5)), id: \.self) { minute in
                        tickMarkView(for: minute)
                            .background(
                                GeometryReader { tickGeometry in
                                    Color.clear
                                        .onAppear {
                                            checkIfTickIsCentered(minute: minute, geometry: tickGeometry)
                                        }
                                        .onChange(of: tickGeometry.frame(in: .named("scrollView"))) { oldValue, newValue in
                                            checkIfTickIsCentered(minute: minute, geometry: tickGeometry)
                                        }
                                }
                            )
                    }
                    
                    Spacer()
                        .frame(width: UIScreen.main.bounds.width / 2 - 20)
                }
            }
            .coordinateSpace(name: "scrollView")
            .onAppear {
                proxy.scrollTo(Int(selectedDuration), anchor: UnitPoint.center)
            }
        }
        .frame(height: 60)
    }
    
    private func checkIfTickIsCentered(minute: Int, geometry: GeometryProxy) {
        let tickFrame = geometry.frame(in: .named("scrollView"))
        let tickCenter = tickFrame.midX
        let screenCenter = UIScreen.main.bounds.width / 2
        
        // Check if this tick is closest to center (within 20 points)
        let distanceFromCenter = abs(tickCenter - screenCenter)
        
        if distanceFromCenter < 20 && abs(selectedDuration - Double(minute)) > 0.1 {
            selectedDuration = Double(minute)
            if !isTimerRunning && !isPaused {
                timeRemaining = selectedDuration * 60
                totalTime = selectedDuration * 60
            }
        }
    }
    
    private var tapeMeasureTimeSelector: some View {
        VStack(spacing: 16) {
            durationDisplay
            timeScrollView
        }
    }
    
    private var controlButtons: some View {
        HStack(spacing: 24) {
            if !isTimerRunning && !isPaused {
                // Smaller circular start button with black and white design
                Button(action: handleStartTimer) {
                    ZStack {
                        // Outer circle with black border
                        Circle()
                            .stroke(Color.black, lineWidth: 2)
                            .frame(width: 80, height: 80)
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        
                        // Inner filled circle with white background
                        Circle()
                            .fill(Color.white)
                            .frame(width: 76, height: 76)
                        
                        // Play icon from assets
                        Image("play")
                            .renderingMode(.template)
                            .foregroundColor(.black)
                            .scaleEffect(1.2)
                    }
                }
                .scaleEffect(isBreakSession ? 0.9 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isBreakSession)
                
            } else if isPaused {
                // Break Button (only if not in break session)
                if !isBreakSession {
                    Button(action: startBreak) {
                        ZStack {
                            Circle()
                                .stroke(Color.black, lineWidth: 2)
                                .frame(width: 60, height: 60)
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            
                            Circle()
                                .fill(Color.white)
                                .frame(width: 56, height: 56)
                            
                            Image(systemName: "cup.and.heat.waves")
                                .renderingMode(.template)
                                .foregroundColor(.black)
                                .scaleEffect(0.9)
                        }
                    }
                }
                
                // Resume Button with circular styling
                Button(action: resumeTimer) {
                    ZStack {
                        Circle()
                            .stroke(Color.black, lineWidth: 2)
                            .frame(width: 80, height: 80)
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 76, height: 76)
                        
                        Image("play")
                            .renderingMode(.template)
                            .foregroundColor(.black)
                            .scaleEffect(1.2)
                    }
                }
                
                // Stop Button (only if not in break)
                if !isBreakSession {
                    Button(action: stopTimer) {
                        ZStack {
                            Circle()
                                .stroke(Color.black, lineWidth: 2)
                                .frame(width: 60, height: 60)
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            
                            Circle()
                                .fill(Color.white)
                                .frame(width: 56, height: 56)
                            
                            Image("stop")
                                .renderingMode(.template)
                                .foregroundColor(.black)
                                .scaleEffect(0.9)
                        }
                    }
                }
            } else {
                // During active timer - different layouts for break vs focus
                if isBreakSession {
                    // Break Session: 3 buttons [Timer] [Pause] [Stop]
                    
                    // Return to Timer Button (left)
                    Button(action: endBreakEarly) {
                        ZStack {
                            Circle()
                                .stroke(Color.black, lineWidth: 2)
                                .frame(width: 60, height: 60)
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            
                            Circle()
                                .fill(Color.white)
                                .frame(width: 56, height: 56)
                            
                            Image("timer")
                                .renderingMode(.template)
                                .foregroundColor(.black)
                                .scaleEffect(0.9)
                        }
                    }
                    
                    // Pause Button (center)
                    Button(action: pauseTimer) {
                        ZStack {
                            Circle()
                                .stroke(Color.black, lineWidth: 2)
                                .frame(width: 80, height: 80)
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            
                            Circle()
                                .fill(Color.white)
                                .frame(width: 76, height: 76)
                            
                            Image("pause")
                                .renderingMode(.template)
                                .foregroundColor(.black)
                                .scaleEffect(1.2)
                        }
                    }
                    
                    // End Break Session Button (right)
                    Button(action: stopTimer) {
                        ZStack {
                            Circle()
                                .stroke(Color.black, lineWidth: 2)
                                .frame(width: 60, height: 60)
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            
                            Circle()
                                .fill(Color.white)
                                .frame(width: 56, height: 56)
                            
                            Image("stop")
                                .renderingMode(.template)
                                .foregroundColor(.black)
                                .scaleEffect(0.9)
                        }
                    }
                } else {
                    // Focus Session: [Break] [Pause] [Stop]
                    
                    // Coffee/Break Button (left)
                    Button(action: startBreak) {
                        ZStack {
                            Circle()
                                .stroke(Color.black, lineWidth: 2)
                                .frame(width: 60, height: 60)
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            
                            Circle()
                                .fill(Color.white)
                                .frame(width: 56, height: 56)
                            
                            Image(systemName: "cup.and.heat.waves")
                                .renderingMode(.template)
                                .foregroundColor(.black)
                                .scaleEffect(0.9)
                        }
                    }
                    
                    // Pause Button (center)
                    Button(action: pauseTimer) {
                        ZStack {
                            Circle()
                                .stroke(Color.black, lineWidth: 2)
                                .frame(width: 80, height: 80)
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            
                            Circle()
                                .fill(Color.white)
                                .frame(width: 76, height: 76)
                            
                            Image("pause")
                                .renderingMode(.template)
                                .foregroundColor(.black)
                                .scaleEffect(1.2)
                        }
                    }
                    
                    // Stop Button (right)
                    Button(action: stopTimer) {
                        ZStack {
                            Circle()
                                .stroke(Color.black, lineWidth: 2)
                                .frame(width: 60, height: 60)
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            
                            Circle()
                                .fill(Color.white)
                                .frame(width: 56, height: 56)
                            
                            Image("stop")
                                .renderingMode(.template)
                                .foregroundColor(.black)
                                .scaleEffect(0.9)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Helper Methods
    
    private func setupInitialData() {
        // Create default tags if none exist
        if tags.isEmpty {
            createDefaultTags()
        }
        
        // Create timer state if none exists
        if timerStates.isEmpty {
            let newTimerState = AppTimerState()
            modelContext.insert(newTimerState)
        }
        
        // Create default "Working" task if no "Working" task exists (completed or incomplete)
        do {
            var descriptor = FetchDescriptor<Task>()
            descriptor.predicate = #Predicate<Task> { $0.title == "Working" }
            let existingWorkingTasks = try modelContext.fetch(descriptor)
            
            if existingWorkingTasks.isEmpty {
                createDefaultWorkingTask()
            }
        } catch {
            print("Error checking for existing Working tasks: \(error)")
            // Fallback to old behavior
            if availableTasks.isEmpty {
                createDefaultWorkingTask()
            }
        }
        
        // Set to last used task or first available task
        if selectedTask == nil {
            selectedTask = lastUsedTask ?? availableTasks.first
        }
        
        // Set initial time based on selected task duration or default
        if let task = selectedTask {
            selectedDuration = Double(task.duration)
        }
        
        if !isPaused {
            timeRemaining = selectedDuration * 60
            totalTime = selectedDuration * 60
        }
    }
    
    private func createDefaultWorkingTask() {
        // Find the "Work" tag or create it if it doesn't exist
        let workTag = tags.first(where: { $0.name == "Work" }) ?? {
            let tag = FocusTag(name: "Work", color: "blue")
            modelContext.insert(tag)
            return tag
        }()
        
        // Create the default "Working" task
        let defaultTask = Task(title: "Working", duration: 25, tag: workTag)
        modelContext.insert(defaultTask)
        
        do {
            try modelContext.save()
        } catch {
            print("Error creating default working task: \(error)")
        }
    }
    
    private func calculateWorkTimeToday() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let todaySessions = recentSessions.filter { session in
            guard let startTime = session.startTime else { return false }
            return calendar.isDate(startTime, inSameDayAs: today) && 
                   session.sessionType == "focus" && 
                   session.isCompleted
        }
        
        workTimeToday = todaySessions.reduce(0) { total, session in
            total + (session.actualDuration / 60) // Convert to minutes
        }
    }
    
    private func createDefaultTags() {
        let defaultTags = [
            ("Work", "blue"),
            ("Personal", "green"),
            ("Study", "purple"),
            ("Exercise", "orange"),
            ("Reading", "red")
        ]
        
        for (name, color) in defaultTags {
            let tag = FocusTag(name: name, color: color)
            modelContext.insert(tag)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving default tags: \(error)")
        }
    }
    
    private func startTimer() {
        let sessionDuration: Int
        if isBreakSession {
            sessionDuration = Int(notificationManager.getEffectiveBreakDuration())
        } else {
            sessionDuration = Int(notificationManager.isTestModeEnabled ? notificationManager.getEffectiveFocusDuration() : selectedDuration * 60)
        }
        
        // Reset session work time when starting a new focus session (not break)
        if !isBreakSession && currentSession == nil {
            sessionWorkTime = 0
        }
        
        // For focus sessions, ensure we have a task (use default "Working" if none selected)
        let taskForSession: Task?
        
        if isBreakSession {
            taskForSession = nil
        } else if let selectedTask = selectedTask {
            taskForSession = selectedTask
        } else {
            // Find existing "Working" task (including completed ones) or create new one
            do {
                var descriptor = FetchDescriptor<Task>()
                descriptor.predicate = #Predicate<Task> { $0.title == "Working" }
                let existingTasks = try modelContext.fetch(descriptor)
                
                if let existingTask = existingTasks.first {
                    taskForSession = existingTask
                } else {
                    // Create new Working task
                    let workTag = tags.first(where: { $0.name == "Work" }) ?? {
                        let tag = FocusTag(name: "Work", color: "blue")
                        modelContext.insert(tag)
                        return tag
                    }()
                    let defaultTask = Task(title: "Working", duration: 25, tag: workTag)
                    modelContext.insert(defaultTask)
                    try? modelContext.save()
                    taskForSession = defaultTask
                }
            } catch {
                // Fallback: create new task
                let workTag = tags.first(where: { $0.name == "Work" }) ?? {
                    let tag = FocusTag(name: "Work", color: "blue")
                    modelContext.insert(tag)
                    return tag
                }()
                let defaultTask = Task(title: "Working", duration: 25, tag: workTag)
                modelContext.insert(defaultTask)
                try? modelContext.save()
                taskForSession = defaultTask
            }
        }
        
        let session = FocusSession(
            duration: sessionDuration,
            task: taskForSession,
            sessionType: isBreakSession ? "break" : "focus"
        )
        session.startTime = Date()
        currentSession = session
        modelContext.insert(session)
        
        let expectedBreakDuration = notificationManager.getEffectiveBreakDuration()
        let expectedFocusDuration = notificationManager.isTestModeEnabled ? notificationManager.getEffectiveFocusDuration() : selectedDuration * 60
        
        if isBreakSession && timeRemaining != expectedBreakDuration {
            timeRemaining = expectedBreakDuration
            totalTime = expectedBreakDuration
        } else if !isBreakSession && timeRemaining != expectedFocusDuration {
            timeRemaining = expectedFocusDuration
            totalTime = expectedFocusDuration
        }
        
        // Start timer
        isTimerRunning = true
        isPaused = false
        
        // Start Live Activity if available
        if #available(iOS 16.1, *), let liveActivityManager = liveActivityManager {
            let sessionType: PomodoroTimerAttributes.ContentState.SessionType = isBreakSession ? .shortBreak : .focus
            liveActivityManager.startActivity(
                duration: timeRemaining,
                sessionType: sessionType,
                taskName: taskForSession?.title
            )
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
                
                // Update Live Activity every 30 seconds to reduce battery impact
                if Int(timeRemaining) % 30 == 0 {
                    if #available(iOS 16.1, *), let liveActivityManager = liveActivityManager {
                        liveActivityManager.updateActivity(remainingTime: timeRemaining)
                    }
                }
            } else {
                completeSession()
            }
        }
    }
    
    private func resumeTimer() {
        // Resume from paused state
        isTimerRunning = true
        isPaused = false
        
        // Resume Live Activity if available
        if #available(iOS 16.1, *), let liveActivityManager = liveActivityManager {
            liveActivityManager.resumeActivity(remainingTime: timeRemaining)
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
                
                // Update Live Activity every 30 seconds to reduce battery impact
                if Int(timeRemaining) % 30 == 0 {
                    if #available(iOS 16.1, *), let liveActivityManager = liveActivityManager {
                        liveActivityManager.updateActivity(remainingTime: timeRemaining)
                    }
                }
            } else {
                completeSession()
            }
        }
    }
    
    private func startBreak() {
        // Store current focus session state
        pausedFocusTimeRemaining = timeRemaining
        pausedFocusTotalTime = totalTime
        pausedFocusSession = currentSession
        
        // Mark that the focus session had a break taken
        if let focusSession = currentSession {
            focusSession.wasBreakTaken = true
        }
        
        // Pause the current focus session
        pauseTimer()
        
        // Start break session automatically
        isBreakSession = true
        let breakDuration = notificationManager.getEffectiveBreakDuration()
        timeRemaining = breakDuration
        totalTime = breakDuration
        startTimer() // Automatically start the break timer
    }
    
    private func startSuggestedBreak() {
        // Start a suggested break
        isBreakSession = true
        let breakDuration = notificationManager.getEffectiveBreakDuration()
        timeRemaining = breakDuration
        totalTime = breakDuration
        startTimer()
    }
    
    private func pauseTimer() {
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
        isPaused = true
        
        // Pause Live Activity if available
        if #available(iOS 16.1, *), let liveActivityManager = liveActivityManager {
            liveActivityManager.pauseActivity()
        }
        
        // Update current session with actual time worked
        if let session = currentSession {
            session.actualDuration = Int(totalTime - timeRemaining)
            
            do {
                try modelContext.save()
            } catch {
                print("Error saving session: \(error)")
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
        isPaused = false
        
        // End Live Activity if available
        if #available(iOS 16.1, *), let liveActivityManager = liveActivityManager {
            liveActivityManager.endCurrentActivity(completed: false)
        }
        
        // Show completion dialog for focus sessions
        if let session = currentSession, !isBreakSession {
            session.endTime = Date()
            session.actualDuration = Int(totalTime - timeRemaining)
            sessionToComplete = session
            showingCompletionDialog = true
            return // Don't reset yet, wait for user confirmation
        }
        
        // For break sessions, handle differently
        if isBreakSession {
            // Track break time in the paused focus session
            if let focusSession = pausedFocusSession {
                let breakTimeSpent = Int(totalTime - timeRemaining) // in seconds
                focusSession.breakDuration += breakTimeSpent
                totalBreakTime += breakTimeSpent / 60 // track in minutes for display
            }
            
            // Mark break session as completed
            if let session = currentSession {
                session.endTime = Date()
                session.actualDuration = Int(totalTime - timeRemaining)
                session.isCompleted = true
            }
            
            // Break completed, return to focus session if it exists and auto-resume
            if let focusSession = pausedFocusSession {
                isBreakSession = false
                timeRemaining = pausedFocusTimeRemaining
                totalTime = pausedFocusTotalTime
                currentSession = focusSession
                
                // Auto-resume the focus timer instead of requiring manual resume
                isTimerRunning = true
                isPaused = false
                
                // Update Live Activity to show focus session and resume
                if #available(iOS 16.1, *), let liveActivityManager = liveActivityManager {
                    liveActivityManager.resumeActivityWithSessionType(
                        remainingTime: timeRemaining,
                        sessionType: .focus,
                        taskName: selectedTask?.title
                    )
                }
                
                // Start the focus timer
                timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    if timeRemaining > 0 {
                        timeRemaining -= 1
                        
                        // Update Live Activity every 30 seconds to reduce battery impact
                        if Int(timeRemaining) % 30 == 0 {
                            if #available(iOS 16.1, *), let liveActivityManager = liveActivityManager {
                                liveActivityManager.updateActivity(remainingTime: timeRemaining)
                            }
                        }
                    } else {
                        completeSession()
                    }
                }
                
                // Clear stored state
                pausedFocusSession = nil
                pausedFocusTimeRemaining = 0
                pausedFocusTotalTime = 0
            } else {
                // No previous focus session, reset normally
                isBreakSession = false
                timeRemaining = selectedDuration * 60
                totalTime = selectedDuration * 60
                currentSession = nil
                totalBreakTime = 0 // Reset break time
            }
        }
        
        calculateWorkTimeToday() // Recalculate work time
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving session: \(error)")
        }
    }
    
    private func confirmSessionCompletion() {
        guard let session = sessionToComplete else { return }
        
        // Mark session as completed
        session.isCompleted = true
        
        // Update session work time for break tracking
        sessionWorkTime += session.actualDuration / 60 // Add minutes to session work time
        
        // Check if session has an associated task
        if let taskId = session.taskId {
            // Find the task using a query
            do {
                var descriptor = FetchDescriptor<Task>()
                descriptor.predicate = #Predicate<Task> { $0.id == taskId }
                let tasks = try modelContext.fetch(descriptor)
                if let task = tasks.first {
                    if task.isCompleted {
                        // Task already completed, add time to existing duration
                        task.duration += session.actualDuration / 60 // Add minutes
                    } else {
                        // Mark as completed for first time
                        task.isCompleted = true
                        task.completedAt = Date()
                    }
                }
            } catch {
                print("Error fetching task: \(error)")
            }
            
            // Reset timer and close dialog normally
            finishSessionCompletion()
        } else {
            // No task assigned - prompt user to create one
            unassignedSession = session
            showingCompletionDialog = false // Close completion dialog
            sessionToComplete = nil
            showingTaskCreation = true // Show task creation dialog
        }
        
        calculateWorkTimeToday() // Recalculate work time
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving completed session: \(error)")
        }
    }
    
    private func finishSessionCompletion() {
        // Reset timer
        timeRemaining = selectedDuration * 60
        totalTime = selectedDuration * 60
        currentSession = nil
        totalBreakTime = 0 // Reset break time for next session
        
        // Close dialog
        showingCompletionDialog = false
        sessionToComplete = nil
    }
    
    private func cancelSessionCompletion() {
        // Don't mark as completed, just reset
        timeRemaining = selectedDuration * 60
        totalTime = selectedDuration * 60
        currentSession = nil
        totalBreakTime = 0 // Reset break time for next session
        
        // Close dialog
        showingCompletionDialog = false
        sessionToComplete = nil
    }
    
    private func createTaskForSession() {
        guard let session = unassignedSession, !newTaskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Create new task
        let task = Task(
            title: newTaskName.trimmingCharacters(in: .whitespacesAndNewlines),
            duration: session.actualDuration / 60, // Convert seconds to minutes
            tag: selectedTagForNewTask,
            plannedDate: Date()
        )
        task.isCompleted = true
        task.completedAt = Date()
        modelContext.insert(task)
        
        // Link session to the new task
        session.taskId = task.id
        session.taskTitle = task.title
        session.tagId = task.tagId
        session.tagName = task.tagName
        session.tagColor = task.tagColor
        
        // Reset state
        newTaskName = ""
        selectedTagForNewTask = nil
        unassignedSession = nil
        showingTaskCreation = false
        
        // Finish session completion
        finishSessionCompletion()
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving new task: \(error)")
        }
    }
    
    private func skipTaskCreation() {
        // Reset state without creating task
        newTaskName = ""
        selectedTagForNewTask = nil
        unassignedSession = nil
        showingTaskCreation = false
        
        // Finish session completion
        finishSessionCompletion()
    }
    
    private func handleStartTimer() {
        // Check if we have a selected task or if it's a break session
        if selectedTask != nil || isBreakSession {
            startTimer()
        } else {
            // No task selected - show quick task creation popup
            showingQuickTaskCreation = true
        }
    }
    
    private func createQuickTaskAndStartTimer() {
        guard !quickTaskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Create new task
        let task = Task(
            title: quickTaskName.trimmingCharacters(in: .whitespacesAndNewlines),
            duration: Int(selectedDuration), // Use current timer duration
            tag: selectedTagForQuickTask,
            plannedDate: Date()
        )
        modelContext.insert(task)
        
        // Set as selected task
        selectedTask = task
        
        // Reset quick task creation state
        quickTaskName = ""
        selectedTagForQuickTask = nil
        showingQuickTaskCreation = false
        
        // Start timer with the new task
        startTimer()
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving quick task: \(error)")
        }
    }
    
    private func cancelQuickTaskCreation() {
        quickTaskName = ""
        selectedTagForQuickTask = nil
        showingQuickTaskCreation = false
    }
    
    private func endBreakEarly() {
        // End break session and return to focus
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
        isPaused = false
        
        // Mark break session as completed
        if let session = currentSession {
            session.isCompleted = true
            session.endTime = Date()
            session.actualDuration = Int(totalTime - timeRemaining)
        }
        
        // Return to focus session if it exists and auto-resume
        if let focusSession = pausedFocusSession {
            isBreakSession = false
            timeRemaining = pausedFocusTimeRemaining
            totalTime = pausedFocusTotalTime
            currentSession = focusSession
            
            // Auto-resume the focus timer instead of requiring manual resume
            isTimerRunning = true
            isPaused = false
            
            // Update Live Activity to show focus session and resume
            if #available(iOS 16.1, *), let liveActivityManager = liveActivityManager {
                liveActivityManager.resumeActivityWithSessionType(
                    remainingTime: timeRemaining,
                    sessionType: .focus,
                    taskName: selectedTask?.title
                )
            }
            
            // Start the focus timer
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                    
                    // Update Live Activity every 30 seconds to reduce battery impact
                    if Int(timeRemaining) % 30 == 0 {
                        if #available(iOS 16.1, *), let liveActivityManager = liveActivityManager {
                            liveActivityManager.updateActivity(remainingTime: timeRemaining)
                        }
                    }
                } else {
                    completeSession()
                }
            }
        } else {
            // No previous focus session, reset normally
            isBreakSession = false
            timeRemaining = selectedDuration * 60
            totalTime = selectedDuration * 60
            currentSession = nil
            
            // End Live Activity since no focus session to return to
            if #available(iOS 16.1, *), let liveActivityManager = liveActivityManager {
                liveActivityManager.endCurrentActivity(completed: false)
            }
        }
        
        // Clear stored focus session state
        pausedFocusSession = nil
        pausedFocusTimeRemaining = 0
        pausedFocusTotalTime = 0
        
        calculateWorkTimeToday()
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving completed session: \(error)")
        }
    }
    
    private func completeSession() {
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
        isPaused = false
        
        // Trigger alarm notification
        let sessionTypeString = isBreakSession ? "break" : "focus"
        let taskName = isBreakSession ? nil : selectedTask?.title
        notificationManager.triggerTimerCompletionAlert(sessionType: sessionTypeString, taskName: taskName)
        
        // End Live Activity if available (marked as completed)
        if #available(iOS 16.1, *), let liveActivityManager = liveActivityManager {
            liveActivityManager.endCurrentActivity(completed: true)
        }
        
        // Mark session as completed
        if let session = currentSession {
            session.isCompleted = true
            session.endTime = Date()
            session.actualDuration = Int(totalTime - timeRemaining)
            
            // Update session work time for break tracking (focus sessions only)
            if !isBreakSession {
                sessionWorkTime += session.actualDuration / 60 // Add minutes to session work time
            }
            
            // Mark associated task as completed if this was a focus session
            if !isBreakSession, let taskId = session.taskId {
                // Find the task using a query
                do {
                    var descriptor = FetchDescriptor<Task>()
                    descriptor.predicate = #Predicate<Task> { $0.id == taskId }
                    let tasks = try modelContext.fetch(descriptor)
                    if let task = tasks.first {
                        if task.isCompleted {
                            // Task already completed, add time to existing duration
                            task.duration += session.actualDuration / 60 // Add minutes
                        } else {
                            // Mark as completed for first time
                            task.isCompleted = true
                            task.completedAt = Date()
                        }
                    }
                } catch {
                    print("Error fetching task: \(error)")
                }
            }
        }
        
        if isBreakSession {
            // Break completed, return to focus session if it exists and auto-resume
            if let focusSession = pausedFocusSession {
                isBreakSession = false
                timeRemaining = pausedFocusTimeRemaining
                totalTime = pausedFocusTotalTime
                currentSession = focusSession
                
                // Auto-resume the focus timer instead of requiring manual resume
                isTimerRunning = true
                isPaused = false
                
                // Update Live Activity to show focus session and resume
                if #available(iOS 16.1, *), let liveActivityManager = liveActivityManager {
                    liveActivityManager.resumeActivityWithSessionType(
                        remainingTime: timeRemaining,
                        sessionType: .focus,
                        taskName: selectedTask?.title
                    )
                }
                
                // Start the focus timer
                timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    if timeRemaining > 0 {
                        timeRemaining -= 1
                        
                        // Update Live Activity every 30 seconds to reduce battery impact
                        if Int(timeRemaining) % 30 == 0 {
                            if #available(iOS 16.1, *), let liveActivityManager = liveActivityManager {
                                liveActivityManager.updateActivity(remainingTime: timeRemaining)
                            }
                        }
                    } else {
                        completeSession()
                    }
                }
                
                // Clear stored state
                pausedFocusSession = nil
                pausedFocusTimeRemaining = 0
                pausedFocusTotalTime = 0
            } else {
                // No previous focus session, reset normally
                isBreakSession = false
                timeRemaining = selectedDuration * 60
                totalTime = selectedDuration * 60
                currentSession = nil
            }
        } else {
            // Focus session completed - reset
            timeRemaining = selectedDuration * 60
            totalTime = selectedDuration * 60
            currentSession = nil
        }
        
        calculateWorkTimeToday() // Recalculate work time
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving completed session: \(error)")
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func colorFromString(_ colorString: String) -> Color {
        switch colorString {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "red": return .red
        default: return .blue
        }
    }
}

struct TaskSelectorSheet: View {
    let availableTasks: [Task]
    let selectedTask: Task?
    let onTaskSelected: (Task?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // No task option
                Button(action: { onTaskSelected(nil) }) {
                    HStack {
                        Text("No specific task")
                            .font(.custom("Geist", size: 16))
                            .fontWeight(.light)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if selectedTask == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                
                // Available tasks
                List {
                    ForEach(availableTasks, id: \.id) { task in
                        Button(action: { onTaskSelected(task) }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(task.title)
                                        .font(.custom("Geist", size: 16))
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    if let tagName = task.tagName, let tagColor = task.tagColor {
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(colorFromString(tagColor))
                                                .frame(width: 6, height: 6)
                                            Text(tagName)
                                                .font(.custom("Geist", size: 12))
                                                .fontWeight(.light)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                if selectedTask?.id == task.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Select Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.custom("Geist", size: 16))
                    .fontWeight(.medium)
                }
            }
        }
    }
    
    private func colorFromString(_ colorString: String) -> Color {
        switch colorString {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "red": return .red
        default: return .blue
        }
    }
}

struct CompletionPopupView: View {
    let session: FocusSession?
    let onComplete: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
            
            // Popup card
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    
                    Text("Session Complete")
                        .font(.custom("Geist", size: 24))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                // Session details
                if let session = session {
                    VStack(spacing: 16) {
                        // Focus time
                        HStack {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.green)
                            
                            Text("Focus time:")
                                .font(.custom("Geist", size: 16))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(session.actualDuration / 60) minutes")
                                .font(.custom("Geist", size: 16))
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        
                        // Break time (if any)
                        if session.breakDuration > 0 {
                            HStack {
                                Image(systemName: "cup.and.heat.waves")
                                    .font(.system(size: 16))
                                    .foregroundColor(.orange)
                                
                                Text("Break time:")
                                    .font(.custom("Geist", size: 16))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("\(session.breakDuration / 60) minutes")
                                    .font(.custom("Geist", size: 16))
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        // Task info
                        if let taskTitle = session.taskTitle {
                            HStack {
                                Image(systemName: "target")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                                
                                Text("Task:")
                                    .font(.custom("Geist", size: 16))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text(taskTitle)
                                    .font(.custom("Geist", size: 16))
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
                
                Text("Mark this session as completed?")
                    .font(.custom("Geist", size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                // Action buttons
                HStack(spacing: 12) {
                    // Cancel button
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.custom("Geist", size: 16))
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.1))
                            )
                    }
                    
                    // Complete button
                    Button(action: onComplete) {
                        Text("Complete")
                            .font(.custom("Geist", size: 16))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.green)
                            )
                    }
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 24)
        }
        .animation(.easeInOut(duration: 0.3), value: session)
    }
}

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

struct TaskCreationSheet: View {
    @Binding var taskName: String
    @Binding var selectedTag: FocusTag?
    let tags: [FocusTag]
    let sessionDuration: Int // in seconds
    let onSave: () -> Void
    let onSkip: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var sessionDurationText: String {
        let minutes = sessionDuration / 60
        let seconds = sessionDuration % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Text("Name Your Focus Session")
                        .font(.custom("Geist", size: 24))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("You focused for \(sessionDurationText). What were you working on?")
                        .font(.custom("Geist", size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 24) {
                    // Task Name Input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Task Name")
                            .font(.custom("Geist", size: 18))
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        TextField("What did you work on?", text: $taskName)
                            .font(.custom("Geist", size: 16))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.gray.opacity(0.08))
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }
                    
                    // Tag Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Category (Optional)")
                            .font(.custom("Geist", size: 18))
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                            ForEach(tags, id: \.id) { tag in
                                TaskCreationTagChip(
                                    tag: tag,
                                    isSelected: selectedTag?.id == tag.id
                                ) {
                                    selectedTag = selectedTag?.id == tag.id ? nil : tag
                                }
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .navigationTitle("Focus Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Skip") {
                        onSkip()
                        dismiss()
                    }
                    .font(.custom("Geist", size: 17))
                    .foregroundColor(.secondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .font(.custom("Geist", size: 17))
                    .fontWeight(.semibold)
                    .foregroundColor(taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                    .disabled(taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct TaskCreationTagChip: View {
    let tag: FocusTag
    let isSelected: Bool
    let action: () -> Void
    
    var chipColor: Color {
        switch tag.color {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "red": return .red
        default: return .blue
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle()
                    .fill(chipColor)
                    .frame(width: 12, height: 12)
                
                Text(tag.name)
                    .font(.custom("Geist", size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? chipColor : Color.gray.opacity(0.08))
                    .stroke(isSelected ? chipColor : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .buttonStyle(PlainButtonStyle())
    }
}

struct QuickTaskCreationSheet: View {
    @Binding var taskName: String
    @Binding var selectedTag: FocusTag?
    let tags: [FocusTag]
    let onSave: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Text("Create Task to Start")
                        .font(.custom("Geist", size: 24))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("What would you like to focus on?")
                        .font(.custom("Geist", size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 24) {
                    // Task Name Input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Task Name")
                            .font(.custom("Geist", size: 18))
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        TextField("Enter task name", text: $taskName)
                            .font(.custom("Geist", size: 16))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.gray.opacity(0.08))
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }
                    
                    // Tag Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Category (Optional)")
                            .font(.custom("Geist", size: 18))
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                            ForEach(tags, id: \.id) { tag in
                                TaskCreationTagChip(
                                    tag: tag,
                                    isSelected: selectedTag?.id == tag.id
                                ) {
                                    selectedTag = selectedTag?.id == tag.id ? nil : tag
                                }
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .navigationTitle("Quick Start")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .font(.custom("Geist", size: 17))
                    .foregroundColor(.secondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Start Timer") {
                        onSave()
                        dismiss()
                    }
                    .font(.custom("Geist", size: 17))
                    .fontWeight(.semibold)
                    .foregroundColor(taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                    .disabled(taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [FocusTag.self, Task.self, FocusSession.self, AppTimerState.self], inMemory: true)
}

#Preview("TimerView") {
    TimerView(selectedTab: .constant(0))
        .modelContainer(for: [FocusTag.self, Task.self, FocusSession.self, AppTimerState.self], inMemory: true)
}

