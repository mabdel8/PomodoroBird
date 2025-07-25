//
//  AnalyticsView.swift
//  PomodoroApp
//
//  Created by Abdalla Abdelmagid on 7/23/25.
//

import SwiftUI
import SwiftData
import Charts

enum TimePeriod: String, CaseIterable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
}

struct AnalyticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FocusSession.createdAt, order: .reverse) private var focusSessions: [FocusSession]
    @Query(sort: \FocusTag.name) private var tags: [FocusTag]
    
    @State private var selectedPeriod: TimePeriod = .weekly
    @State private var currentDate = Date()
    
    private var calendar = Calendar.current
    
    // Filter sessions based on selected period
    private var filteredSessions: [FocusSession] {
        let completedFocusSessions = focusSessions.filter { 
            $0.isCompleted && $0.sessionType == "focus" 
        }
        
        switch selectedPeriod {
        case .weekly:
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: currentDate)?.start ?? currentDate
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? currentDate
            return completedFocusSessions.filter { 
                $0.createdAt >= weekStart && $0.createdAt < weekEnd 
            }
        case .monthly:
            let monthStart = calendar.dateInterval(of: .month, for: currentDate)?.start ?? currentDate
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? currentDate
            return completedFocusSessions.filter { 
                $0.createdAt >= monthStart && $0.createdAt < monthEnd 
            }
        case .yearly:
            let yearStart = calendar.dateInterval(of: .year, for: currentDate)?.start ?? currentDate
            let yearEnd = calendar.date(byAdding: .year, value: 1, to: yearStart) ?? currentDate
            return completedFocusSessions.filter { 
                $0.createdAt >= yearStart && $0.createdAt < yearEnd 
            }
        }
    }
    
    // Heatmap data
    private var heatmapData: [HeatmapDay] {
        let calendar = Calendar.current
        var data: [HeatmapDay] = []
        
        let endDate = Date()
        let startDate: Date
        
        switch selectedPeriod {
        case .weekly:
            startDate = calendar.date(byAdding: .day, value: -49, to: endDate) ?? endDate // 7 weeks
        case .monthly:
            startDate = calendar.date(byAdding: .day, value: -90, to: endDate) ?? endDate // ~3 months
        case .yearly:
            startDate = calendar.date(byAdding: .day, value: -365, to: endDate) ?? endDate // 1 year
        }
        
        // Group sessions by day
        let sessionsByDay = Dictionary(grouping: focusSessions.filter { 
            $0.isCompleted && $0.sessionType == "focus" && $0.createdAt >= startDate
        }) { session in
            calendar.startOfDay(for: session.createdAt)
        }
        
        // Create heatmap data for each day
        var current = startDate
        while current <= endDate {
            let dayStart = calendar.startOfDay(for: current)
            let sessionsForDay = sessionsByDay[dayStart] ?? []
            let totalMinutes = sessionsForDay.reduce(0) { $0 + ($1.actualDuration / 60) }
            
            data.append(HeatmapDay(
                date: dayStart,
                sessionCount: sessionsForDay.count,
                focusMinutes: totalMinutes
            ))
            
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }
        
        return data
    }
    
    // Pie chart data
    private var pieChartData: [TagTimeData] {
        let tagGroups = Dictionary(grouping: filteredSessions) { session in
            session.tagName ?? "No Category"
        }
        
        return tagGroups.map { tagName, sessions in
            let totalMinutes = sessions.reduce(0) { $0 + ($1.actualDuration / 60) }
            let tagColor = sessions.first?.tagColor ?? "blue"
            
            return TagTimeData(
                tagName: tagName,
                minutes: totalMinutes,
                color: tagColor
            )
        }.filter { $0.minutes > 0 }
        .sorted { $0.minutes > $1.minutes }
    }
    
    // Bar chart data
    private var barChartData: [DailyStatsData] {
        let calendar = Calendar.current
        var data: [DailyStatsData] = []
        
        let endDate = Date()
        let days: Int
        
        switch selectedPeriod {
        case .weekly:
            days = 7
        case .monthly:
            days = 30
        case .yearly:
            days = 12 // Show months instead of days for yearly
        }
        
        for i in 0..<days {
            let date: Date
            let label: String
            
            if selectedPeriod == .yearly {
                date = calendar.date(byAdding: .month, value: -i, to: endDate) ?? endDate
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM"
                label = formatter.string(from: date)
            } else {
                date = calendar.date(byAdding: .day, value: -i, to: endDate) ?? endDate
                let formatter = DateFormatter()
                formatter.dateFormat = selectedPeriod == .weekly ? "E" : "d"
                label = formatter.string(from: date)
            }
            
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            
            let sessionsForPeriod = focusSessions.filter { session in
                session.isCompleted && 
                session.sessionType == "focus" &&
                session.createdAt >= dayStart && 
                session.createdAt < dayEnd
            }
            
            let totalMinutes = sessionsForPeriod.reduce(0) { $0 + ($1.actualDuration / 60) }
            
            data.append(DailyStatsData(
                date: date,
                label: label,
                focusMinutes: totalMinutes,
                sessionCount: sessionsForPeriod.count
            ))
        }
        
        return data.reversed()
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header with period selector
                VStack(spacing: 24) {
                    HStack {
                        Text("Analytics")
                            .font(.custom("Geist", size: 32))
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    
                    // Period Selector
                    periodSelector
                }
                
                // Stats Overview
                statsOverview
                
                // Heatmap Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Activity Heatmap")
                        .font(.custom("Geist", size: 22))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 24)
                    
                    activityHeatmap
                }
                
                // Pie Chart Section
                if !pieChartData.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Time by Category")
                            .font(.custom("Geist", size: 22))
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 24)
                        
                        timeDistributionChart
                    }
                }
                
                // Bar Chart Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Daily Focus Time")
                        .font(.custom("Geist", size: 22))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 24)
                    
                    dailyFocusChart
                }
                
                Spacer(minLength: 100)
            }
        }
        .background(Color(.systemBackground))
    }
    
    private var periodSelector: some View {
        HStack(spacing: 0) {
            ForEach(TimePeriod.allCases, id: \.self) { period in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedPeriod = period
                    }
                }) {
                    Text(period.rawValue)
                        .font(.custom("Geist", size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(selectedPeriod == period ? .white : .primary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedPeriod == period ? Color.blue : Color.clear)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.1))
        )
        .padding(.horizontal, 24)
    }
    
    private var statsOverview: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Total Focus",
                value: "\(filteredSessions.reduce(0) { $0 + ($1.actualDuration / 60) })",
                unit: "min",
                color: .blue
            )
            
            StatCard(
                title: "Sessions",
                value: "\(filteredSessions.count)",
                unit: "",
                color: .green
            )
            
            StatCard(
                title: "Avg Session",
                value: filteredSessions.isEmpty ? "0" : "\(filteredSessions.reduce(0) { $0 + ($1.actualDuration / 60) } / filteredSessions.count)",
                unit: "min",
                color: .orange
            )
        }
        .padding(.horizontal, 24)
    }
    
    private var activityHeatmap: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: Array(repeating: GridItem(.fixed(12), spacing: 2), count: 7), spacing: 2) {
                ForEach(heatmapData, id: \.date) { day in
                    Rectangle()
                        .fill(heatmapColor(for: day.focusMinutes))
                        .frame(width: 12, height: 12)
                        .cornerRadius(2)
                }
            }
            .padding(.horizontal, 24)
        }
    }
    
    private var timeDistributionChart: some View {
        VStack(spacing: 16) {
            Chart(pieChartData, id: \.tagName) { data in
                SectorMark(
                    angle: .value("Minutes", data.minutes),
                    innerRadius: .ratio(0.4),
                    angularInset: 2
                )
                .foregroundStyle(colorFromString(data.color))
                .opacity(0.8)
            }
            .frame(height: 200)
            .padding(.horizontal, 24)
            
            // Legend
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(pieChartData, id: \.tagName) { data in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(colorFromString(data.color))
                            .frame(width: 12, height: 12)
                        
                        Text(data.tagName)
                            .font(.custom("Geist", size: 14))
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("\(data.minutes)m")
                            .font(.custom("Geist", size: 12))
                            .fontWeight(.light)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }
    
    private var dailyFocusChart: some View {
        Chart(barChartData, id: \.date) { data in
            BarMark(
                x: .value("Period", data.label),
                y: .value("Minutes", data.focusMinutes)
            )
            .foregroundStyle(.blue.gradient)
            .cornerRadius(4)
        }
        .frame(height: 200)
        .padding(.horizontal, 24)
    }
    
    private func heatmapColor(for minutes: Int) -> Color {
        switch minutes {
        case 0:
            return Color.gray.opacity(0.1)
        case 1...25:
            return Color.green.opacity(0.3)
        case 26...50:
            return Color.green.opacity(0.5)
        case 51...75:
            return Color.green.opacity(0.7)
        default:
            return Color.green.opacity(0.9)
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

struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.custom("Geist", size: 14))
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack(alignment: .bottom, spacing: 4) {
                Text(value)
                    .font(.custom("Geist", size: 24))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if !unit.isEmpty {
                    Text(unit)
                        .font(.custom("Geist", size: 14))
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .offset(y: -2)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Data Models

struct HeatmapDay {
    let date: Date
    let sessionCount: Int
    let focusMinutes: Int
}

struct TagTimeData {
    let tagName: String
    let minutes: Int
    let color: String
}

struct DailyStatsData {
    let date: Date
    let label: String
    let focusMinutes: Int
    let sessionCount: Int
}

#Preview {
    AnalyticsView()
        .modelContainer(for: [FocusTag.self, Task.self, FocusSession.self, AppTimerState.self], inMemory: true)
} 