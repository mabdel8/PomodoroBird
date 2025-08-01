//
//  TaskComponents.swift
//  PomodoroApp
//
//  Created by Claude Code on 7/31/25.
//

import SwiftUI
import SwiftData

// MARK: - Task Selector Sheet
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

// MARK: - Completion Popup View
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

// MARK: - Task Creation Sheet
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

// MARK: - Task Creation Tag Chip
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
    }
}

// MARK: - Quick Task Creation Sheet
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