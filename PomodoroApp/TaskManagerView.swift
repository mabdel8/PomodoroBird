//
//  TaskManagerView.swift
//  PomodoroApp
//
//  Created by Mohamed Abdelmagid on 7/23/25.
//

import SwiftUI
import SwiftData

struct TaskManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Task.createdAt, order: .reverse) private var allTasks: [Task]
    @Query(sort: \FocusTag.name) private var tags: [FocusTag]
    
    @State private var selectedDate = Date()
    @State private var currentWeekOffset = 0
    @State private var showingNewTaskSheet = false
    @State private var newTaskTitle = ""
    @State private var selectedTagForNewTask: FocusTag?
    @State private var newTaskDuration = 25
    @State private var newTaskPlannedDate = Date()
    
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
            // Month and Year with navigation
            HStack {
                Button(action: { changeWeek(-1) }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text(monthYearText)
                    .font(.custom("Geist", size: 24))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: { changeWeek(1) }) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            // Week Days
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
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if value.translation.width > 50 {
                            changeWeek(-1)
                        } else if value.translation.width < -50 {
                            changeWeek(1)
                        }
                    }
            )
        }
        .padding(.bottom, 24)
        .background(Color.gray.opacity(0.05))
    }
    
    private var tasksContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Today's Plan Header
            HStack {
                Text("Today's Plan")
                    .font(.custom("Geist", size: 28))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !tasksForSelectedDate.isEmpty {
                    Text("\(tasksForSelectedDate.filter(\.isCompleted).count)/\(tasksForSelectedDate.count)")
                        .font(.custom("Geist", size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.gray.opacity(0.1))
                        )
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            // Tasks List
            if tasksForSelectedDate.isEmpty {
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
                    LazyVStack(spacing: 12) {
                        ForEach(tasksForSelectedDate, id: \.id) { task in
                            TaskRowView(task: task) {
                                toggleTaskCompletion(task)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 100) // Space for floating button
                }
            }
        }
    }
    
    private var monthYearText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        if let weekDate = calendar.date(byAdding: .weekOfYear, value: currentWeekOffset, to: Date()) {
            return formatter.string(from: weekDate)
        }
        return formatter.string(from: Date())
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
    
    private func changeWeek(_ direction: Int) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentWeekOffset += direction
        }
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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Task Title")
                        .font(.custom("Geist", size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    TextField("Enter task title", text: $taskTitle)
                        .font(.custom("Geist", size: 16))
                        .fontWeight(.light)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Planned Date")
                        .font(.custom("Geist", size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    DatePicker("", selection: $plannedDate, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                        .labelsHidden()
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Duration")
                        .font(.custom("Geist", size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        ForEach([15, 25, 30, 45, 60, 90], id: \.self) { duration in
                            let isSelected = taskDuration == duration
                            
                            Button(action: {
                                taskDuration = duration
                            }) {
                                Text("\(duration)m")
                                    .font(.custom("Geist", size: 14))
                                    .fontWeight(.medium)
                                    .foregroundColor(isSelected ? .white : .blue)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(isSelected ? .blue : .blue.opacity(0.1))
                                    )
                            }
                            .animation(.easeInOut(duration: 0.2), value: isSelected)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tag")
                        .font(.custom("Geist", size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(tags, id: \.id) { tag in
                                TagSelectionChip(
                                    tag: tag,
                                    isSelected: selectedTag?.id == tag.id
                                ) {
                                    selectedTag = selectedTag?.id == tag.id ? nil : tag
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
                
                Spacer()
            }
            .padding(24)
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                        .font(.custom("Geist", size: 16))
                        .fontWeight(.light)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save", action: onSave)
                        .font(.custom("Geist", size: 16))
                        .fontWeight(.medium)
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

#Preview {
    TaskManagerView()
        .modelContainer(for: [FocusTag.self, Task.self, FocusSession.self, AppTimerState.self], inMemory: true)
}