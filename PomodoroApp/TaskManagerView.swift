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
    
    private var calendar = Calendar.current
    
    // Get the current week's dates
    private var weekDates: [Date] {
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: calendar.date(byAdding: .weekOfYear, value: currentWeekOffset, to: Date()) ?? Date())?.start ?? Date()
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }
    
    // Filter tasks for the selected date
    private var tasksForSelectedDate: [Task] {
        return allTasks.filter { task in
            calendar.isDate(task.plannedDate, inSameDayAs: selectedDate)
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
                        .foregroundColor(.primary)
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
        let incompleteTasks = tasksForSelectedDate.filter { !$0.isCompleted }
        let completedTasks = tasksForSelectedDate.filter { $0.isCompleted }
        
        return VStack(alignment: .leading, spacing: 0) {
            if tasksForSelectedDate.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Spacer()
                    
                    Image(systemName: "calendar")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No tasks planned")
                        .font(.custom("Geist", size: 20))
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("Add a task for \(selectedDateText)")
                        .font(.custom("Geist", size: 16))
                        .fontWeight(.light)
                        .foregroundColor(.secondary.opacity(0.7))
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // To-Do Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("To-Do")
                                    .font(.custom("Geist", size: 24))
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if !incompleteTasks.isEmpty {
                                    Text("\(incompleteTasks.count)")
                                        .font(.custom("Geist", size: 14))
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(Color.gray.opacity(0.1))
                                        )
                                }
                            }
                            
                            if incompleteTasks.isEmpty {
                                Text("All tasks completed! 🎉")
                                    .font(.custom("Geist", size: 16))
                                    .fontWeight(.light)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 20)
                                    .frame(maxWidth: .infinity)
                            } else {
                                LazyVStack(spacing: 12) {
                                    ForEach(incompleteTasks, id: \.id) { task in
                                        TaskRowView(task: task) {
                                            toggleTaskCompletion(task)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Completed Section
                        if !completedTasks.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("Completed")
                                        .font(.custom("Geist", size: 24))
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Text("\(completedTasks.count)")
                                        .font(.custom("Geist", size: 14))
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(Color.green.opacity(0.1))
                                        )
                                }
                                
                                LazyVStack(spacing: 12) {
                                    ForEach(completedTasks, id: \.id) { task in
                                        TaskRowView(task: task) {
                                            toggleTaskCompletion(task)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
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
}

struct TaskRowView: View {
    let task: Task
    let onToggle: () -> Void
    
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
            // Completion circle
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(task.isCompleted ? .green : .secondary)
            }
            .buttonStyle(PlainButtonStyle())
            
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

struct NewTaskSheet: View {
    @Binding var taskTitle: String
    @Binding var selectedTag: FocusTag?
    @Binding var taskDuration: Int
    @Binding var plannedDate: Date
    let tags: [FocusTag]
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @State private var showingTagSheet = false
    @Environment(\.modelContext) private var modelContext
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy"
        return formatter
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Task Name Section
                            HStack(spacing: 16) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 24))
                                    .foregroundColor(.primary)
                                    .frame(width: 32)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Task Name")
                                        .font(.custom("Geist", size: 17))
                                        .fontWeight(.regular)
                                        .foregroundColor(.primary)
                                    
                                    TextField("Enter task name", text: $taskTitle)
                                        .font(.custom("Geist", size: 16))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 20)
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            
                            // Date Section
                            Button(action: {}) {
                                HStack(spacing: 16) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 24))
                                        .foregroundColor(.primary)
                                        .frame(width: 32)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Date")
                                            .font(.custom("Geist", size: 17))
                                            .fontWeight(.regular)
                                            .foregroundColor(.primary)
                                        
                                        Text(dateFormatter.string(from: plannedDate))
                                            .font(.custom("Geist", size: 16))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 20)
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Duration Section
                            Menu {
                                ForEach(Array(stride(from: 5, through: 120, by: 5)), id: \.self) { duration in
                                    Button("\(duration) min") {
                                        taskDuration = duration
                                    }
                                }
                            } label: {
                                HStack(spacing: 16) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 24))
                                        .foregroundColor(.primary)
                                        .frame(width: 32)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Duration")
                                            .font(.custom("Geist", size: 17))
                                            .fontWeight(.regular)
                                            .foregroundColor(.primary)
                                        
                                        Text("\(taskDuration) min")
                                            .font(.custom("Geist", size: 16))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 20)
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Category Section
                            Button(action: { showingTagSheet = true }) {
                                HStack(spacing: 16) {
                                    Image(systemName: "tag")
                                        .font(.system(size: 24))
                                        .foregroundColor(.primary)
                                        .frame(width: 32)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Category")
                                            .font(.custom("Geist", size: 17))
                                            .fontWeight(.regular)
                                            .foregroundColor(.primary)
                                        
                                        if let selectedTag = selectedTag {
                                            Text(selectedTag.name)
                                                .font(.custom("Geist", size: 16))
                                                .foregroundColor(.blue)
                                        } else {
                                            Text("Select a category")
                                                .font(.custom("Geist", size: 16))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 20)
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 32)
                        .padding(.bottom, 120) // Extra space for the done button
                    }
                    
                    Spacer()
                    
                    // Done Button at bottom - always visible
                    Button("Done") {
                        onSave()
                    }
                    .font(.custom("Geist", size: 17))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.4) : Color.blue)
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                    .disabled(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .ignoresSafeArea(.keyboard)
            }
            .navigationTitle("Add Task")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { onCancel() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingTagSheet) {
            TagSelectionSheet(
                tags: tags,
                selectedTag: $selectedTag,
                onCreateTag: createNewTag
            )
        }
    }
    
    private func tagColor(_ colorString: String) -> Color {
        switch colorString {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "red": return .red
        default: return .blue
        }
    }
    
    private func createNewTag(name: String, color: String) {
        let newTag = FocusTag(name: name, color: color)
        modelContext.insert(newTag)
        
        do {
            try modelContext.save()
            selectedTag = newTag
        } catch {
            print("Error saving new tag: \(error)")
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

struct TagSelectionSheet: View {
    let tags: [FocusTag]
    @Binding var selectedTag: FocusTag?
    let onCreateTag: (String, String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingNewTagAlert = false
    @State private var newTagName = ""
    @State private var newTagColor = "blue"
    
    private let availableColors = [
        ("blue", Color.blue),
        ("green", Color.green),
        ("purple", Color.purple),
        ("orange", Color.orange),
        ("red", Color.red)
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(tags, id: \.id) { tag in
                        Button(action: {
                            selectedTag = tag
                            dismiss()
                        }) {
                            HStack {
                                Circle()
                                    .fill(tagColor(tag.color))
                                    .frame(width: 20, height: 20)
                                
                                Text(tag.name)
                                    .font(.custom("Geist", size: 17))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedTag?.id == tag.id {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    
                    Button(action: { showingNewTagAlert = true }) {
                        HStack {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.gray)
                                )
                            
                            Text("Create New Tag")
                                .font(.custom("Geist", size: 17))
                                .foregroundColor(.blue)
                            
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Select Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.custom("Geist", size: 17))
                    .fontWeight(.semibold)
                }
            }
        }
        .alert("New Tag", isPresented: $showingNewTagAlert) {
            TextField("Tag name", text: $newTagName)
            
            Button("Cancel", role: .cancel) {
                newTagName = ""
            }
            
            Button("Create") {
                if !newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    onCreateTag(newTagName, newTagColor)
                    newTagName = ""
                    dismiss()
                }
            }
            .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Enter a name for your new tag")
        }
    }
    
    private func tagColor(_ colorString: String) -> Color {
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