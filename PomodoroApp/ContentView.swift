//
//  ContentView.swift
//  PomodoroApp
//
//  Created by Mohamed Abdelmagid on 7/23/25.
//

import SwiftUI
import SwiftData

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
            TimerView()
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
        workTimeToday > 0 && workTimeToday % 25 == 0 && !isBreakSession && !isTimerRunning
    }
    
    var nextBreakIn: String? {
        guard !isBreakSession && workTimeToday > 0 else { return nil }
        let minutesUntilBreak = 25 - (workTimeToday % 25)
        if minutesUntilBreak == 25 { return nil }
        return "Break in \(minutesUntilBreak) min"
    }
    
    var body: some View {
        VStack(spacing: 0) {
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
        .onAppear {
            setupInitialData()
            calculateWorkTimeToday()
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
                Button(action: startTimer) {
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
                .disabled(!isBreakSession && selectedTask == nil && !availableTasks.isEmpty)
                .opacity((!isBreakSession && selectedTask == nil && !availableTasks.isEmpty) ? 0.5 : 1.0)
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
        
        // Create default "Working" task if no tasks exist
        if availableTasks.isEmpty {
            createDefaultWorkingTask()
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
        let sessionDuration = Int(isBreakSession ? 300 : selectedDuration * 60) // 5 min break or custom focus
        let session = FocusSession(
            duration: sessionDuration,
            task: isBreakSession ? nil : selectedTask,
            sessionType: isBreakSession ? "break" : "focus"
        )
        session.startTime = Date()
        currentSession = session
        modelContext.insert(session)
        
        if isBreakSession && timeRemaining != 300 {
            timeRemaining = 300 // 5 minutes
            totalTime = 300
        } else if !isBreakSession && timeRemaining != selectedDuration * 60 {
            timeRemaining = selectedDuration * 60
            totalTime = selectedDuration * 60
        }
        
        // Start timer
        isTimerRunning = true
        isPaused = false
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                completeSession()
            }
        }
    }
    
    private func resumeTimer() {
        // Resume from paused state
        isTimerRunning = true
        isPaused = false
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
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
        
        // Pause the current focus session
        pauseTimer()
        
        // Start break session automatically
        isBreakSession = true
        timeRemaining = 300 // 5 minutes
        totalTime = 300
        startTimer() // Automatically start the break timer
    }
    
    private func startSuggestedBreak() {
        // Start a suggested break
        isBreakSession = true
        timeRemaining = 300 // 5 minutes
        totalTime = 300
        startTimer()
    }
    
    private func pauseTimer() {
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
        isPaused = true
        
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
        
        // Complete current session
        if let session = currentSession {
            session.endTime = Date()
            session.actualDuration = Int(totalTime - timeRemaining)
        }
        
        if isBreakSession {
            // Break completed, return to focus session if it exists
            if let focusSession = pausedFocusSession {
                isBreakSession = false
                timeRemaining = pausedFocusTimeRemaining
                totalTime = pausedFocusTotalTime
                currentSession = focusSession
                isPaused = true // Set to paused so user can resume
                
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
            print("Error saving session: \(error)")
        }
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
        
        // Return to paused focus session if it exists
        if let focusSession = pausedFocusSession {
            isBreakSession = false
            timeRemaining = pausedFocusTimeRemaining
            totalTime = pausedFocusTotalTime
            currentSession = focusSession
            isPaused = true // Set to paused so user can resume
        } else {
            // No previous focus session, reset normally
            isBreakSession = false
            timeRemaining = selectedDuration * 60
            totalTime = selectedDuration * 60
            currentSession = nil
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
        
        // Mark session as completed
        if let session = currentSession {
            session.isCompleted = true
            session.endTime = Date()
            session.actualDuration = Int(totalTime - timeRemaining)
        }
        
        if isBreakSession {
            // Break completed, return to focus session if it exists
            if let focusSession = pausedFocusSession {
                isBreakSession = false
                timeRemaining = pausedFocusTimeRemaining
                totalTime = pausedFocusTotalTime
                currentSession = focusSession
                isPaused = true // Set to paused so user can resume
                
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

#Preview {
    ContentView()
        .modelContainer(for: [FocusTag.self, Task.self, FocusSession.self, AppTimerState.self], inMemory: true)
}

