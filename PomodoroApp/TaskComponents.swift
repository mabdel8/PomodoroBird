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
    let onAddTask: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 32) {
                        headerSection
                        if !availableTasks.isEmpty {
                            availableTasksSection
                        } else {
                            emptyStateSection
                        }
                        Spacer(minLength: 100)
                    }
                }
                
                // Add Task Button at bottom
                VStack(spacing: 16) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            dismiss()
                            onAddTask()
                        }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .semibold))
                            
                            Text("Add Task")
                                .font(.custom("Geist", size: 16))
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black)
                        )
                        .scaleEffect(1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: true)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .background(Color.white)
            }
            .background(Color.white)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.custom("Geist", size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(.black)
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Select Task")
                .font(.system(size: 24, weight: .semibold, design: .default))
                .foregroundColor(.primary)
        }
        .padding(.top, 32)
        .padding(.bottom, 16)
    }
    
    private var availableTasksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Available Tasks")
                .font(.custom("Geist", size: 14))
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.top, 8)
                .padding(.bottom, 4)
            
            VStack(spacing: 12) {
                ForEach(availableTasks, id: \.id) { task in
                    taskButton(for: task)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }
    
    private var emptyStateSection: some View {
        VStack(spacing: 24) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No tasks yet")
                    .font(.custom("Geist", size: 20))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Add one to get started!")
                    .font(.custom("Geist", size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func taskButton(for task: Task) -> some View {
        Button(action: { 
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                onTaskSelected(task)
            }
        }) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(task.title)
                        .font(.custom("Geist", size: 16))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    if let tagName = task.tagName, let tagColor = task.tagColor {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(colorFromString(tagColor))
                                .frame(width: 8, height: 8)
                            Text(tagName)
                                .font(.custom("Geist", size: 13))
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                if selectedTask?.id == task.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.black)
                        .font(.system(size: 20, weight: .medium))
                        .scaleEffect(1.1)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTask?.id == task.id)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary.opacity(0.6))
                        .font(.system(size: 20, weight: .medium))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedTask?.id == task.id ? Color.black.opacity(0.05) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedTask?.id == task.id ? Color.black.opacity(0.3) : Color.gray.opacity(0.1), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            .scaleEffect(selectedTask?.id == task.id ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTask?.id == task.id)
        }
        .buttonStyle(PlainButtonStyle())
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
    
    private func formatTimeWithSeconds(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.6)
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
                        .foregroundColor(.black)
                    
                    Text("Session Complete")
                        .font(.custom("Geist", size: 24))
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                }
                
                // Session details
                if let session = session {
                    VStack(spacing: 16) {
                        // Focus time with exact seconds
                        HStack {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.black)
                            
                            Text("Focus time:")
                                .font(.custom("Geist", size: 16))
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Text(formatTimeWithSeconds(session.actualDuration))
                                .font(.custom("Geist", size: 16))
                                .fontWeight(.medium)
                                .foregroundColor(.black)
                        }
                        
                        // Break time with exact seconds (if any)
                        if session.breakDuration > 0 {
                            HStack {
                                Image(systemName: "cup.and.heat.waves")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                                
                                Text("Break time:")
                                    .font(.custom("Geist", size: 16))
                                    .foregroundColor(.gray)
                                
                                Spacer()
                                
                                Text(formatTimeWithSeconds(session.breakDuration))
                                    .font(.custom("Geist", size: 16))
                                    .fontWeight(.medium)
                                    .foregroundColor(.black)
                            }
                        }
                        
                        // Task info
                        if let taskTitle = session.taskTitle {
                            HStack {
                                Image(systemName: "target")
                                    .font(.system(size: 16))
                                    .foregroundColor(.black)
                                
                                Text("Task:")
                                    .font(.custom("Geist", size: 16))
                                    .foregroundColor(.gray)
                                
                                Spacer()
                                
                                Text(taskTitle)
                                    .font(.custom("Geist", size: 16))
                                    .fontWeight(.medium)
                                    .foregroundColor(.black)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
                
                Text("Mark this session as completed?")
                    .font(.custom("Geist", size: 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                
                // Action buttons
                HStack(spacing: 12) {
                    // Cancel button
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.custom("Geist", size: 16))
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
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
                                    .fill(Color.black)
                            )
                    }
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
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
    
    private var isFormValid: Bool {
        !taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
    
    private func tagBackgroundColor(_ colorString: String) -> Color {
        switch colorString {
        case "blue": return Color(hex: "F0F8FF") // Light blue
        case "green": return Color(hex: "F0FFF0") // Light green
        case "purple": return Color(hex: "F9F0FF") // Light purple
        case "orange": return Color(hex: "FFF8F0") // Light orange
        case "red": return Color(hex: "FFF0F0") // Light red
        default: return Color(hex: "F0F8FF")
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header Section
                    VStack(spacing: 8) {
                        Text("Quick Start")
                            .font(.system(size: 24, weight: .semibold, design: .default))
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 16)
                    
                    // Task Name Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Task Name")
                            .font(.custom("Geist", size: 16))
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                        
                        TextField("What would you like to focus on?", text: $taskName)
                            .font(.custom("Geist", size: 16))
                            .fontWeight(.medium)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color(hex: "E5E5E5"), lineWidth: 1)
                                    )
                            )
                            .submitLabel(.done)
                    }
                    .padding(.horizontal, 24)
                    
                    // Category Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Category")
                            .font(.custom("Geist", size: 16))
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                            ForEach(tags, id: \.id) { tag in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedTag = tag
                                    }
                                }) {
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(tagColor(tag.color))
                                            .frame(width: 16, height: 16)
                                        
                                        Text(tag.name)
                                            .font(.custom("Geist", size: 16))
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(selectedTag?.id == tag.id ? tagBackgroundColor(tag.color) : Color.white)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(selectedTag?.id == tag.id ? tagColor(tag.color) : tagColor(tag.color).opacity(0.3), lineWidth: 1.5)
                                            )
                                    )
                                }
                                .scaleEffect(selectedTag?.id == tag.id ? 1.02 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: selectedTag?.id == tag.id)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer(minLength: 40)
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .font(.custom("Geist", size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Start Timer") {
                        onSave()
                        dismiss()
                    }
                    .font(.custom("Geist", size: 16))
                    .fontWeight(.semibold)
                    .foregroundColor(isFormValid ? .black : .gray)
                    .disabled(!isFormValid)
                }
            }
        }
    }
}