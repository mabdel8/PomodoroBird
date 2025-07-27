//
//  TaskManagerView.swift
//  PomodoroApp
//
//  Created by Abdalla Abdelmagid on 7/23/25.
//

import SwiftUI
import SwiftData

struct TaskManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Task.createdAt, order: .reverse) private var allTasks: [Task]
    @Query(sort: \FocusTag.name) private var tags: [FocusTag]
    @Query(sort: \FocusSession.createdAt, order: .reverse) private var focusSessions: [FocusSession]
    
    @State private var selectedDate = Date()
    @State private var currentWeekOffset = 0
    @State private var showingNewTaskSheet = false
    @State private var newTaskTitle = ""
    @State private var selectedTagForNewTask: FocusTag?
    @State private var newTaskDuration = 25
    @State private var newTaskPlannedDate = Date()
    @State private var isAnimating = false
    @State private var animationDirection: Int = 0 // -1 for left, 1 for right
    @State private var showTodoSection = true
    @State private var showCompletedSection = true
    
    private var calendar = Calendar.current
    
    // Get the current week's dates
    private var weekDates: [Date] {
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: calendar.date(byAdding: .weekOfYear, value: currentWeekOffset, to: Date()) ?? Date())?.start ?? Date()
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }
    
    // Filter tasks for the selected date (only incomplete tasks)
    private var tasksForSelectedDate: [Task] {
        return allTasks.filter { task in
            calendar.isDate(task.plannedDate, inSameDayAs: selectedDate) && !task.isCompleted
        }
    }
    
    // Get completed sessions for the selected date (including default working tasks)
    private var completedSessionsForSelectedDate: [FocusSession] {
        return focusSessions.filter { session in
            session.isCompleted && calendar.isDate(session.createdAt, inSameDayAs: selectedDate)
        }
    }
    
    // Get tasks that were completed through timer sessions but don't have a manually created task
    private var timerCompletedTasksForDate: [Task] {
        let manualTaskIds = Set(tasksForSelectedDate.map { $0.id })
        let sessionTaskIds = completedSessionsForSelectedDate.compactMap { $0.taskId }
        
        return allTasks.filter { task in
            task.isCompleted &&
            calendar.isDate(task.completedAt ?? task.createdAt, inSameDayAs: selectedDate) &&
            !manualTaskIds.contains(task.id) &&
            sessionTaskIds.contains(task.id)
        }
    }
    
    // Combined tasks for display (manual + timer completed)
    private var allTasksForSelectedDate: [Task] {
        var combined = tasksForSelectedDate
        combined.append(contentsOf: timerCompletedTasksForDate)
        return combined.sorted { task1, task2 in
            // Sort by completion status first (incomplete first), then by creation time
            if task1.isCompleted != task2.isCompleted {
                return !task1.isCompleted
            }
            return task1.createdAt > task2.createdAt
        }
    }
    
    // Calculate current streak of consecutive days with completed focus sessions
    private var currentStreak: Int {
        let completedSessions = focusSessions.filter { $0.isCompleted }
        
        guard !completedSessions.isEmpty else { return 0 }
        
        // Group sessions by day
        let sessionsByDay = Dictionary(grouping: completedSessions) { session in
            calendar.startOfDay(for: session.createdAt)
        }
        
        // Get unique days with sessions, sorted in descending order
        let daysWithSessions = Array(sessionsByDay.keys).sorted(by: >)
        
        guard !daysWithSessions.isEmpty else { return 0 }
        
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var currentDay = today
        
        // Count consecutive days starting from today
        for day in daysWithSessions {
            if calendar.isDate(day, inSameDayAs: currentDay) {
                streak += 1
                currentDay = calendar.date(byAdding: .day, value: -1, to: currentDay) ?? currentDay
            } else if day < currentDay {
                // Check if this day is the next consecutive day
                let expectedDay = calendar.date(byAdding: .day, value: -1, to: currentDay)
                if let expectedDay = expectedDay, calendar.isDate(day, inSameDayAs: expectedDay) {
                    streak += 1
                    currentDay = day
                } else {
                    // Gap found, streak ends
                    break
                }
            }
        }
        
        return streak
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    // Calendar Header
                    calendarHeader
                    
                    // Tasks Content
                    tasksContent
                }
                
                // Floating Add Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { 
                            newTaskPlannedDate = selectedDate
                            showingNewTaskSheet = true 
                        }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(
                                    Circle()
                                        .fill(Color.red)
                                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                                )
                        }
                        .padding(.trailing, 24)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .sheet(isPresented: $showingNewTaskSheet) {
            NewTaskSheet(
                taskTitle: $newTaskTitle,
                selectedTag: $selectedTagForNewTask,
                taskDuration: $newTaskDuration,
                plannedDate: $newTaskPlannedDate,
                tags: tags,
                onSave: createNewTask,
                onCancel: cancelNewTask
            )
        }
        .onAppear {
            setupInitialTags()
        }
    }
    
    private var calendarHeader: some View {
        VStack(spacing: 16) {
            // Date header with streak
            HStack {
                Spacer()
                
                Text(selectedDateHeaderText)
                    .font(.custom("Geist", size: 24))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Streak display (always shown)
                HStack(spacing: 4) {
                    Image("fire")
                        .resizable()
                        .frame(width: 16, height: 16)
                        .foregroundColor(.orange)
                    
                    Text("\(currentStreak)")
                        .font(.custom("Geist", size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            // Week Days with animation
            HStack(spacing: 0) {
                ForEach(Array(weekDates.enumerated()), id: \.offset) { index, date in
                    VStack(spacing: 8) {
                        Text(dayOfWeekText(date))
                            .font(.custom("Geist", size: 14))
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Button(action: { selectedDate = date }) {
                            Text("\(calendar.component(.day, from: date))")
                                .font(.custom("Geist", size: 16))
                                .fontWeight(.medium)
                                .foregroundColor(calendar.isDate(date, inSameDayAs: selectedDate) ? .white : .primary)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(calendar.isDate(date, inSameDayAs: selectedDate) ? Color.red : Color.clear)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 24)
            .id("week-\(currentWeekOffset)")
            .offset(x: isAnimating ? (animationDirection > 0 ? -50 : 50) : 0)
            .opacity(isAnimating ? 0.3 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: isAnimating)
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if value.translation.width > 50 {
                            // Swiping right (previous week)
                            animationDirection = -1
                            withAnimation(.easeInOut(duration: 0.15)) {
                                isAnimating = true
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                currentWeekOffset -= 1
                                animationDirection = 1
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    isAnimating = false
                                }
                            }
                        } else if value.translation.width < -50 {
                            // Swiping left (next week)
                            animationDirection = 1
                            withAnimation(.easeInOut(duration: 0.15)) {
                                isAnimating = true
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                currentWeekOffset += 1
                                animationDirection = -1
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    isAnimating = false
                                }
                            }
                        }
                    }
            )
        }
        .padding(.bottom, 24)
        .background(Color.gray.opacity(0.05))
    }
    
    private var tasksContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Tasks List
            if allTasksForSelectedDate.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    
                    Image(systemName: "calendar")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No tasks completed")
                        .font(.custom("Geist", size: 20))
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("Start a focus session to track your work")
                        .font(.custom("Geist", size: 16))
                        .fontWeight(.light)
                        .foregroundColor(.secondary.opacity(0.7))
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Pending Tasks Section
                        let pendingTasks = allTasksForSelectedDate.filter { !$0.isCompleted }
                        if !pendingTasks.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Button(action: { 
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showTodoSection.toggle()
                                    }
                                }) {
                                    HStack {
                                        Text("To-Do")
                                            .font(.custom("Geist", size: 18))
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        HStack(spacing: 6) {
                                            Text("\(pendingTasks.count)")
                                                .font(.custom("Geist", size: 14))
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                            
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.secondary)
                                                .rotationEffect(.degrees(showTodoSection ? 0 : -90))
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(Color.blue.opacity(0.1))
                                        )
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal, 24)
                                
                                if showTodoSection {
                                    ForEach(pendingTasks, id: \.id) { task in
                                        TaskRowView(task: task)
                                            .padding(.horizontal, 24)
                                    }
                                }
                            }
                        }
                        
                        // Completed Tasks Section
                        let completedTasks = allTasksForSelectedDate.filter { $0.isCompleted }
                        if !completedTasks.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Button(action: { 
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showCompletedSection.toggle()
                                    }
                                }) {
                                    HStack {
                                        Text("Completed")
                                            .font(.custom("Geist", size: 18))
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        HStack(spacing: 6) {
                                            Text("\(completedTasks.count)")
                                                .font(.custom("Geist", size: 14))
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                            
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.secondary)
                                                .rotationEffect(.degrees(showCompletedSection ? 0 : -90))
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(Color.green.opacity(0.1))
                                        )
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal, 24)
                                
                                if showCompletedSection {
                                    ForEach(completedTasks, id: \.id) { task in
                                        CompletedTaskRowView(task: task, sessions: getSessionsForTask(task))
                                            .padding(.horizontal, 24)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.bottom, 100) // Space for floating button
                }
            }
        }
    }
    
    private var selectedDateHeaderText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd"
        return formatter.string(from: selectedDate)
    }
    
    private var selectedDateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: selectedDate)
    }
    
    private func dayOfWeekText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date).uppercased()
    }
    

    
    private func setupInitialTags() {
        if tags.isEmpty {
            createDefaultTags()
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
    
    private func createNewTask() {
        guard !newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let task = Task(title: newTaskTitle, duration: newTaskDuration, tag: selectedTagForNewTask, plannedDate: newTaskPlannedDate)
        modelContext.insert(task)
        
        do {
            try modelContext.save()
            newTaskTitle = ""
            selectedTagForNewTask = nil
            newTaskDuration = 25
            newTaskPlannedDate = Date()
            showingNewTaskSheet = false
        } catch {
            print("Error saving new task: \(error)")
        }
    }
    
    private func cancelNewTask() {
        newTaskTitle = ""
        selectedTagForNewTask = nil
        newTaskDuration = 25
        newTaskPlannedDate = Date()
        showingNewTaskSheet = false
    }
    
    private func toggleTaskCompletion(_ task: Task) {
        task.isCompleted.toggle()
        task.completedAt = task.isCompleted ? Date() : nil
        
        do {
            try modelContext.save()
        } catch {
            print("Error updating task: \(error)")
        }
    }
    
    private func getSessionsForTask(_ task: Task) -> [FocusSession] {
        return focusSessions.filter { session in
            session.taskId == task.id && session.isCompleted
        }
    }
}

struct TaskRowView: View {
    let task: Task
    
    var tagColor: Color {
        guard let colorString = task.tagColor else { return .gray }
        switch colorString {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "red": return .red
        default: return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Completion circle (non-interactive)
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundColor(task.isCompleted ? .green : .secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.custom("Geist", size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                    .strikethrough(task.isCompleted)
                
                HStack(spacing: 8) {
                    if let tagName = task.tagName {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(tagColor)
                                .frame(width: 8, height: 8)
                            
                            Text(tagName)
                                .font(.custom("Geist", size: 12))
                                .fontWeight(.light)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text("\(task.duration) min")
                        .font(.custom("Geist", size: 12))
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.blue.opacity(0.1))
                        )
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.05))
        )
        .contentShape(Rectangle())
    }
}

struct CompletedTaskRowView: View {
    let task: Task
    let sessions: [FocusSession]
    
    var tagColor: Color {
        guard let colorString = task.tagColor else { return .gray }
        switch colorString {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "red": return .red
        default: return .gray
        }
    }
    
    var totalTimeSpent: Int {
        // actualDuration is in seconds, convert to minutes
        return sessions.reduce(0) { total, session in
            total + (session.actualDuration / 60)
        }
    }
    
    var totalBreakTime: Int {
        // breakDuration is in seconds, convert to minutes
        return sessions.reduce(0) { total, session in
            total + (session.breakDuration / 60)
        }
    }
    
    var formattedTime: String {
        let hours = totalTimeSpent / 60
        let minutes = totalTimeSpent % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var formattedBreakTime: String {
        if totalBreakTime > 0 {
            return "\(totalBreakTime)m"
        } else {
            return "0m"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Completion circle (non-interactive)
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(.custom("Geist", size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .strikethrough(true)
                
                HStack(spacing: 8) {
                    if let tagName = task.tagName {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(tagColor)
                                .frame(width: 8, height: 8)
                            
                            Text(tagName)
                                .font(.custom("Geist", size: 12))
                                .fontWeight(.light)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Time spent badge
                    if totalTimeSpent > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                            
                            Text(formattedTime)
                                .font(.custom("Geist", size: 12))
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.green.opacity(0.1))
                        )
                    }
                    
                    // Break time badge
                    if totalBreakTime > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "cup.and.heat.waves")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                            
                            Text(formattedBreakTime)
                                .font(.custom("Geist", size: 12))
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.orange.opacity(0.1))
                        )
                    }
                    
                    // Sessions count
                    if sessions.count > 0 {
                        Text("\(sessions.count) session\(sessions.count == 1 ? "" : "s")")
                            .font(.custom("Geist", size: 12))
                            .fontWeight(.light)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
    }
}

struct NewTaskSheet: View {
    @Binding var taskTitle: String
    @Binding var selectedTag: FocusTag?
    @Binding var taskDuration: Int
    @Binding var plannedDate: Date
    let tags: [FocusTag]
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 28) {
                    // Task Title Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Task Title")
                                .font(.custom("Geist", size: 18))
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        
                        TextField("What do you want to focus on?", text: $taskTitle)
                            .font(.custom("Geist", size: 16))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.gray.opacity(0.08))
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )

                    }
                    
                    // Planned Date Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Planned Date")
                                .font(.custom("Geist", size: 18))
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        
                        DatePicker("Select date", selection: $plannedDate, displayedComponents: .date)
                            .datePickerStyle(GraphicalDatePickerStyle())
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.gray.opacity(0.05))
                            )
                    }
                    
                    // Duration Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Focus Duration")
                                .font(.custom("Geist", size: 18))
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                            ForEach([15, 25, 30, 45, 60, 90], id: \.self) { duration in
                                let isSelected = taskDuration == duration
                                
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        taskDuration = duration
                                    }
                                }) {
                                    VStack(spacing: 8) {
                                        Text("\(duration)")
                                            .font(.custom("Geist", size: 24))
                                            .fontWeight(.bold)
                                            .foregroundColor(isSelected ? .white : .primary)
                                        
                                        Text("min")
                                            .font(.custom("Geist", size: 12))
                                            .fontWeight(.medium)
                                            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 70)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(isSelected ? Color.blue : Color.gray.opacity(0.08))
                                            .stroke(isSelected ? Color.blue : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                                    )
                                }
                                .scaleEffect(isSelected ? 1.02 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: isSelected)
                            }
                        }
                    }
                    
                    // Tag Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Category")
                                .font(.custom("Geist", size: 18))
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                            ForEach(tags, id: \.id) { tag in
                                ModernTagSelectionChip(
                                    tag: tag,
                                    isSelected: selectedTag?.id == tag.id
                                ) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedTag = selectedTag?.id == tag.id ? nil : tag
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
            .background(Color(.systemBackground))
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .font(.custom("Geist", size: 17))
                    .foregroundColor(.blue)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                    }
                    .font(.custom("Geist", size: 17))
                    .fontWeight(.semibold)
                    .foregroundColor(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                    .disabled(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct TagSelectionChip: View {
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
            Text(tag.name)
                .font(.custom("Geist", size: 14))
                .fontWeight(.light)
                .foregroundColor(isSelected ? .white : chipColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? chipColor : chipColor.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(chipColor, lineWidth: isSelected ? 0 : 1)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ModernTagSelectionChip: View {
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

#Preview {
    TaskManagerView()
        .modelContainer(for: [FocusTag.self, Task.self, FocusSession.self, AppTimerState.self], inMemory: true)
}