//
//  TimerView.swift  
//  PomodoroApp
//
//  Created by Claude Code on 7/31/25.
//

import SwiftUI
import SwiftData

struct TimerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FocusTag.name) private var tags: [FocusTag]
    @Query(filter: #Predicate<Task> { !$0.isCompleted }, sort: \Task.createdAt, order: .reverse) private var availableTasks: [Task]
    @Query private var timerStates: [AppTimerState]
    @Query(sort: \FocusSession.createdAt, order: .reverse) private var recentSessions: [FocusSession]
    @Query(sort: \CollectedBird.collectedAt, order: .reverse) private var collectedBirds: [CollectedBird]
    @Binding var selectedTab: Int
    
    @State private var stateManager: TimerStateManager?
    
    var body: some View {
        Group {
            if let stateManager = stateManager {
                contentWithSheets(stateManager: stateManager)
            } else {
                // Loading state
                VStack {
                    ProgressView()
                    Text("Loading...")
                        .font(.custom("Geist", size: 16))
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            initializeStateManager()
        }
    }
    
    private func initializeStateManager() {
        guard stateManager == nil else { return }
        
        let manager = TimerStateManager(modelContext: modelContext)
        manager.updateData(
            tags: tags,
            availableTasks: availableTasks,
            timerStates: timerStates,
            recentSessions: recentSessions,
            collectedBirds: collectedBirds
        )
        manager.setupInitialData()
        manager.calculateWorkTimeToday()
        
        stateManager = manager
    }
    
    private func mainContent(stateManager: TimerStateManager) -> some View {
        ZStack {
            VStack(spacing: 0) {
                // Top navigation area
                HStack {
                    Spacer()
                    
                    Button(action: { stateManager.showingSettings = true }) {
                        Image("setting")
                            .renderingMode(.template)
                            .foregroundColor(.black)
                            .font(.system(size: 20))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .opacity(stateManager.isHatching ? 0 : 1)
                .animation(.easeInOut(duration: 0.3), value: stateManager.isHatching)
                
                Spacer() // Push content to center
                
                // Main timer content - centered vertically
                VStack(spacing: 24) {
                    mainTimerSection(stateManager: stateManager)
                }
                .padding(.horizontal, 24)
                
                Spacer() // Push content to center (bottom spacer)
            }
            .padding(.bottom, 20) // Small space from tab bar
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(UIColor.systemBackground))
            

        }
    }
    
    private func mainTimerSection(stateManager: TimerStateManager) -> some View {
        VStack(spacing: 24) {
            // Break suggestion banner
            if stateManager.shouldSuggestBreak {
                breakSuggestionBanner(stateManager: stateManager)
            }
            
            // Current task section
            currentTaskSection(stateManager: stateManager)
            
            // Timer display
            if !stateManager.isHatching {
                timerDisplayWithProgress(stateManager: stateManager)
            }
            
            // Time selector (only when timer is not running)
            if !stateManager.isTimerRunning && !stateManager.isPaused && !stateManager.isHatching {
                tapeMeasureTimeSelector(stateManager: stateManager)
                    .padding(.horizontal, 24)
            }
            
            // Control buttons
            if !stateManager.isHatching {
                controlButtons(stateManager: stateManager)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
            }
        }
        .opacity(stateManager.isHatching ? 0 : 1)
        .animation(.easeInOut(duration: 0.3), value: stateManager.isHatching)
    }
    

    
    private func contentWithSheets(stateManager: TimerStateManager) -> some View {
        ZStack {
            mainContent(stateManager: stateManager)
                .modifier(TimerSheetsModifier(stateManager: stateManager, tags: tags, availableTasks: availableTasks))
                .modifier(TimerOverlaysModifier(stateManager: stateManager))
            
            // Overlay to hide tab bar during hatching
            if stateManager.isHatching {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea(.all)
                    .overlay {
                        VStack {
                            Spacer()
                            
                            // Centered egg animation
                            Image(stateManager.eggImageForProgress(stateManager.progress))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 320, height: 320)
                                .scaleEffect(stateManager.eggScale)
                                .rotationEffect(.degrees(stateManager.eggRotation))
                                .shadow(
                                    color: stateManager.showFinalResult ? 
                                        (stateManager.hatchedBird != nil ? Color.yellow.opacity(0.6) : Color.purple.opacity(0.4)) : 
                                        Color.clear,
                                    radius: stateManager.showFinalResult ? 20 : 0,
                                    x: 0,
                                    y: 0
                                )
                                .animation(.easeInOut(duration: 0.3), value: stateManager.eggImageForProgress(stateManager.progress))
                                .animation(.easeInOut(duration: 0.1), value: stateManager.eggScale)
                                .animation(.easeInOut(duration: 0.1), value: stateManager.eggRotation)
                                .animation(.easeInOut(duration: 0.5), value: stateManager.showFinalResult)
                            
                            Spacer()
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1000) // Ensure it's above everything
            }
        }
            .onReceive(NotificationCenter.default.publisher(for: .openTimerTab)) { _ in
                selectedTab = 0 // Switch to timer tab (from Live Activity tap - don't end break)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Sync timer when app returns from background
                if stateManager.isTimerRunning && !stateManager.isPaused {
                    stateManager.syncTimerFromBackground()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                // Save timer state when entering background
                if stateManager.isTimerRunning {
                    print("📱 App entering background - timer state saved")
                    // Timer state is automatically maintained by sessionStartTime/sessionEndTime
                }
            }
            .onChange(of: tags) { _, newTags in
                stateManager.updateData(
                    tags: newTags,
                    availableTasks: availableTasks,
                    timerStates: timerStates,
                    recentSessions: recentSessions,
                    collectedBirds: collectedBirds
                )
            }
            .onChange(of: availableTasks) { _, newTasks in
                stateManager.updateData(
                    tags: tags,
                    availableTasks: newTasks,
                    timerStates: timerStates,
                    recentSessions: recentSessions,
                    collectedBirds: collectedBirds
                )
            }
            .onChange(of: timerStates) { _, newStates in
                stateManager.updateData(
                    tags: tags,
                    availableTasks: availableTasks,
                    timerStates: newStates,
                    recentSessions: recentSessions,
                    collectedBirds: collectedBirds
                )
            }
            .onChange(of: recentSessions) { _, newSessions in
                stateManager.updateData(
                    tags: tags,
                    availableTasks: availableTasks,
                    timerStates: timerStates,
                    recentSessions: newSessions,
                    collectedBirds: collectedBirds
                )
            }
            .onChange(of: collectedBirds) { _, newBirds in
                stateManager.updateData(
                    tags: tags,
                    availableTasks: availableTasks,
                    timerStates: timerStates,
                    recentSessions: recentSessions,
                    collectedBirds: newBirds
                )
            }
    }
    
    private func breakSuggestionBanner(stateManager: TimerStateManager) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "cup.and.heat.waves")
                .font(.system(size: 14))
                .foregroundColor(.orange)
            
            Text("Break time! \(stateManager.workTimeToday)min done")
                .font(.custom("Geist", size: 12))
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            Button("Take Break") {
                stateManager.startSuggestedBreak()
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
    
    private func currentTaskSection(stateManager: TimerStateManager) -> some View {
        VStack(spacing: 12) {
            if stateManager.isTimerRunning || stateManager.isPaused {
                // Show current task when timer is active
                if let task = stateManager.selectedTask {
                    VStack(spacing: 6) {
                        Text(stateManager.isBreakSession ? "Break Time" : task.title)
                            .font(.custom("Geist", size: 18))
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                        
                        if !stateManager.isBreakSession, let tagName = task.tagName, let tagColor = task.tagColor {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(stateManager.colorFromString(tagColor))
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
                                    .fill(stateManager.colorFromString(tagColor).opacity(0.1))
                            )
                        }
                    }
                } else if stateManager.isBreakSession {
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
                    Button(action: { stateManager.showingTaskSelector = true }) {
                        HStack(spacing: 6) {
                            if let task = stateManager.selectedTask {
                                if let tagColor = task.tagColor {
                                    Circle()
                                        .fill(stateManager.colorFromString(tagColor))
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
    
    private func timerDisplayWithProgress(stateManager: TimerStateManager) -> some View {
        VStack(spacing: 24) {
            // Egg progress display with in-place animations
            Image(stateManager.eggImageForProgress(stateManager.progress))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 280, height: 280)
                .scaleEffect(stateManager.eggScale)
                .rotationEffect(.degrees(stateManager.eggRotation))
                .shadow(
                    color: stateManager.showFinalResult ? 
                        (stateManager.hatchedBird != nil ? Color.yellow.opacity(0.6) : Color.purple.opacity(0.4)) : 
                        Color.clear,
                    radius: stateManager.showFinalResult ? 20 : 0,
                    x: 0,
                    y: 0
                )
                .animation(.easeInOut(duration: 0.3), value: stateManager.eggImageForProgress(stateManager.progress))
                .animation(.easeInOut(duration: 0.3), value: stateManager.isBreakSession)
                .animation(.easeInOut(duration: 0.1), value: stateManager.eggScale)
                .animation(.easeInOut(duration: 0.1), value: stateManager.eggRotation)
                .animation(.easeInOut(duration: 0.5), value: stateManager.showFinalResult)
            
            // Timer content below the egg
            VStack(spacing: 16) {
                Text(stateManager.timeString(from: stateManager.timeRemaining))
                    .font(.custom("Geist", size: 52))
                    .fontWeight(.thin)
                    .monospacedDigit()
                    .foregroundColor(.primary)
                    .scaleEffect(stateManager.isTimerRunning ? 1.02 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: stateManager.isTimerRunning)
                    .onChange(of: stateManager.timeRemaining) { oldValue, newValue in
                        if stateManager.isTimerRunning {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                // Small pulse animation on each second
                            }
                        }
                    }
                
                if stateManager.isPaused {
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
                    .padding(.vertical, 8)
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
    
    private func tickMarkView(for minute: Int) -> some View {
        let isMajorTick = minute % 15 == 0
        let tickColor: Color = isMajorTick ? .primary : Color.secondary.opacity(0.5)
        
        return VStack(spacing: 4) {
            Rectangle()
                .fill(tickColor)
                .frame(
                    width: isMajorTick ? 2 : 1,
                    height: isMajorTick ? 28 : 12
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
    
    private func timeScrollView(stateManager: TimerStateManager) -> some View {
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
                                            checkIfTickIsCentered(minute: minute, geometry: tickGeometry, stateManager: stateManager)
                                        }
                                        .onChange(of: tickGeometry.frame(in: .named("scrollView"))) { oldValue, newValue in
                                            checkIfTickIsCentered(minute: minute, geometry: tickGeometry, stateManager: stateManager)
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
                proxy.scrollTo(Int(stateManager.selectedDuration), anchor: UnitPoint.center)
            }
        }
        .frame(height: 60)
    }
    
    private func checkIfTickIsCentered(minute: Int, geometry: GeometryProxy, stateManager: TimerStateManager) {
        let tickFrame = geometry.frame(in: .named("scrollView"))
        let tickCenter = tickFrame.midX
        let screenCenter = UIScreen.main.bounds.width / 2
        
        // Check if this tick is closest to center (within 20 points)
        let distanceFromCenter = abs(tickCenter - screenCenter)
        
        if distanceFromCenter < 20 && abs(stateManager.selectedDuration - Double(minute)) > 0.1 {
            stateManager.selectedDuration = Double(minute)
            if !stateManager.isTimerRunning && !stateManager.isPaused {
                stateManager.timeRemaining = stateManager.selectedDuration * 60
                stateManager.totalTime = stateManager.selectedDuration * 60
            }
            
            // Add haptic feedback for time selection
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    private func tapeMeasureTimeSelector(stateManager: TimerStateManager) -> some View {
        timeScrollView(stateManager: stateManager)
    }
    
    private func controlButtons(stateManager: TimerStateManager) -> some View {
        HStack(spacing: 24) {
            if !stateManager.isTimerRunning && !stateManager.isPaused {
                // Play start button with dark background
                Button(action: stateManager.handleStartTimer) {
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 80, height: 80)
                            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                        
                        Image("playfilled")
                            .renderingMode(.template)
                            .foregroundColor(.white)
                            .scaleEffect(1.2)
                    }
                }
                .scaleEffect(stateManager.isBreakSession ? 0.9 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: stateManager.isBreakSession)
                
            } else if stateManager.isPaused {
                // Break Button (only if not in break session)
                if !stateManager.isBreakSession {
                    Button(action: stateManager.startBreak) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 60, height: 60)
                                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                            
                            Image(systemName: "cup.and.heat.waves.fill")
                                .renderingMode(.template)
                                .foregroundColor(.black)
                                .scaleEffect(0.9)
                        }
                    }
                }
                
                // Resume Button with circular styling
                Button(action: stateManager.resumeTimer) {
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 80, height: 80)
                            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                        
                        Image("playfilled")
                            .renderingMode(.template)
                            .foregroundColor(.white)
                            .scaleEffect(1.2)
                    }
                }
                
                // Stop Button (only if not in break)
                if !stateManager.isBreakSession {
                    Button(action: stateManager.stopTimer) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 60, height: 60)
                                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                            
                            Image("stopfilled")
                                .renderingMode(.template)
                                .foregroundColor(.black)
                                .scaleEffect(0.9)
                        }
                    }
                }
            } else {
                // During active timer - different layouts for break vs focus
                if stateManager.isBreakSession {
                    // Break Session: Only one button - Return to Timer (center)
                    Button(action: stateManager.endBreakEarly) {
                        ZStack {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 80, height: 80)
                                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                            
                            Image("timer")
                                .renderingMode(.template)
                                .foregroundColor(.white)
                                .scaleEffect(1.2)
                        }
                    }
                } else {
                    // Focus Session: [Break] [Pause] [Stop]
                    
                    // Coffee/Break Button (left)
                    Button(action: stateManager.startBreak) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 60, height: 60)
                                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                            
                            Image(systemName: "cup.and.heat.waves.fill")
                                .renderingMode(.template)
                                .foregroundColor(.black)
                                .scaleEffect(0.9)
                        }
                    }
                    
                    // Pause Button (center)
                    Button(action: stateManager.pauseTimer) {
                        ZStack {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 80, height: 80)
                                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                            
                            Image("pause")
                                .renderingMode(.template)
                                .foregroundColor(.white)
                                .scaleEffect(1.2)
                        }
                    }
                    
                    // Stop Button (right)
                    Button(action: stateManager.stopTimer) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 60, height: 60)
                                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                            
                            Image("stopfilled")
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
}

// MARK: - ViewModifiers

struct TimerSheetsModifier: ViewModifier {
    let stateManager: TimerStateManager
    let tags: [FocusTag]
    let availableTasks: [Task]
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: Binding(
                get: { stateManager.showingTaskSelector },
                set: { stateManager.showingTaskSelector = $0 }
            )) {
                TaskSelectorSheet(
                    availableTasks: availableTasks,
                    selectedTask: stateManager.selectedTask,
                    onTaskSelected: { task in
                        stateManager.selectedTask = task
                        if let task = task {
                            stateManager.selectedDuration = Double(task.duration)
                            stateManager.timeRemaining = stateManager.selectedDuration * 60
                            stateManager.totalTime = stateManager.selectedDuration * 60
                        }
                        stateManager.showingTaskSelector = false
                    }
                )
            }
            .sheet(isPresented: Binding(
                get: { stateManager.showingSettings },
                set: { stateManager.showingSettings = $0 }
            )) {
                TimerSettingsView(
                    selectedDuration: Binding(
                        get: { stateManager.selectedDuration },
                        set: { stateManager.selectedDuration = $0 }
                    ),
                    notificationManager: stateManager.notificationManager,
                    onDurationChange: { newDuration in
                        stateManager.selectedDuration = newDuration
                        if !stateManager.isTimerRunning {
                            stateManager.timeRemaining = newDuration * 60
                            stateManager.totalTime = newDuration * 60
                        }
                    }
                )
            }
            .sheet(isPresented: Binding(
                get: { stateManager.showingTaskCreation },
                set: { stateManager.showingTaskCreation = $0 }
            )) {
                TaskCreationSheet(
                    taskName: Binding(
                        get: { stateManager.newTaskName },
                        set: { stateManager.newTaskName = $0 }
                    ),
                    selectedTag: Binding(
                        get: { stateManager.selectedTagForNewTask },
                        set: { stateManager.selectedTagForNewTask = $0 }
                    ),
                    tags: tags,
                    sessionDuration: stateManager.unassignedSession?.actualDuration ?? 0,
                    onSave: stateManager.createTaskForSession,
                    onSkip: stateManager.skipTaskCreation
                )
            }
            .sheet(isPresented: Binding(
                get: { stateManager.showingQuickTaskCreation },
                set: { stateManager.showingQuickTaskCreation = $0 }
            )) {
                QuickTaskCreationSheet(
                    taskName: Binding(
                        get: { stateManager.quickTaskName },
                        set: { stateManager.quickTaskName = $0 }
                    ),
                    selectedTag: Binding(
                        get: { stateManager.selectedTagForQuickTask },
                        set: { stateManager.selectedTagForQuickTask = $0 }
                    ),
                    tags: tags,
                    onSave: stateManager.createQuickTaskAndStartTimer,
                    onCancel: stateManager.cancelQuickTaskCreation
                )
            }
    }
}

struct TimerOverlaysModifier: ViewModifier {
    let stateManager: TimerStateManager
    
    func body(content: Content) -> some View {
        content
            .overlay {
                if stateManager.showingCompletionDialog {
                    CompletionPopupView(
                        session: stateManager.sessionToComplete,
                        onComplete: stateManager.confirmSessionCompletion,
                        onCancel: stateManager.cancelSessionCompletion
                    )
                }
            }

    }
}