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
    
    // Chart title based on selected period
    private var chartTitle: String {
        switch selectedPeriod {
        case .weekly:
            return "Daily Focus Time"
        case .monthly:
            return "Weekly Focus Time"
        case .yearly:
            return "Monthly Focus Time"
        }
    }
    
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
            // Show current week (always 7 days starting from week start)
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: endDate)?.start ?? endDate
            startDate = weekStart
        case .monthly:
            // Show current month (calendar month view)
            startDate = calendar.dateInterval(of: .month, for: endDate)?.start ?? endDate
        case .yearly:
            // Show current year from January to December
            startDate = calendar.dateInterval(of: .year, for: endDate)?.start ?? endDate
        }
        
        // Group sessions by day
        let sessionsByDay = Dictionary(grouping: focusSessions.filter { 
            $0.isCompleted && $0.sessionType == "focus" && $0.createdAt >= startDate
        }) { session in
            calendar.startOfDay(for: session.createdAt)
        }
        
        // Create heatmap data for each day
        var current = startDate
        
        switch selectedPeriod {
        case .weekly:
            // Always show exactly 7 days for weekly view
            for i in 0..<7 {
                let dayDate = calendar.date(byAdding: .day, value: i, to: startDate) ?? startDate
                let dayStart = calendar.startOfDay(for: dayDate)
                let sessionsForDay = sessionsByDay[dayStart] ?? []
                let totalMinutes = sessionsForDay.reduce(0) { $0 + ($1.actualDuration / 60) }
                
                data.append(HeatmapDay(
                    date: dayStart,
                    sessionCount: sessionsForDay.count,
                    focusMinutes: totalMinutes
                ))
            }
        case .monthly:
            let finalDate = calendar.dateInterval(of: .month, for: endDate)?.end ?? endDate
            while current <= finalDate {
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
        case .yearly:
            let yearEnd = calendar.dateInterval(of: .year, for: endDate)?.end ?? endDate
            while current <= yearEnd {
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
        
        switch selectedPeriod {
        case .weekly:
            // Show daily data for current week
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
            for i in 0..<7 {
                let date = calendar.date(byAdding: .day, value: i, to: weekStart) ?? weekStart
                let formatter = DateFormatter()
                formatter.dateFormat = "E"
                let label = formatter.string(from: date)
                
                let dayStart = calendar.startOfDay(for: date)
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
                
                let sessionsForDay = focusSessions.filter { session in
                    session.isCompleted && 
                    session.sessionType == "focus" &&
                    session.createdAt >= dayStart && 
                    session.createdAt < dayEnd
                }
                
                let totalMinutes = sessionsForDay.reduce(0) { $0 + ($1.actualDuration / 60) }
                
                data.append(DailyStatsData(
                    date: date,
                    label: label,
                    focusMinutes: totalMinutes,
                    sessionCount: sessionsForDay.count
                ))
            }
            
        case .monthly:
            // Show weekly data for current month
            let monthStart = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
            let monthEnd = calendar.dateInterval(of: .month, for: Date())?.end ?? Date()
            
            var weekStart = calendar.dateInterval(of: .weekOfYear, for: monthStart)?.start ?? monthStart
            var weekNumber = 1
            
            while weekStart < monthEnd && weekNumber <= 5 {
                let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
                
                let sessionsForWeek = focusSessions.filter { session in
                    session.isCompleted && 
                    session.sessionType == "focus" &&
                    session.createdAt >= weekStart && 
                    session.createdAt < weekEnd
                }
                
                let totalMinutes = sessionsForWeek.reduce(0) { $0 + ($1.actualDuration / 60) }
                
                data.append(DailyStatsData(
                    date: weekStart,
                    label: "W\(weekNumber)",
                    focusMinutes: totalMinutes,
                    sessionCount: sessionsForWeek.count
                ))
                
                weekStart = weekEnd
                weekNumber += 1
            }
            
        case .yearly:
            // Show monthly data for current year
            let yearStart = calendar.dateInterval(of: .year, for: Date())?.start ?? Date()
            for i in 0..<12 {
                let monthStart = calendar.date(byAdding: .month, value: i, to: yearStart) ?? yearStart
                let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
                
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM"
                let label = formatter.string(from: monthStart)
                
                let sessionsForMonth = focusSessions.filter { session in
                    session.isCompleted && 
                    session.sessionType == "focus" &&
                    session.createdAt >= monthStart && 
                    session.createdAt < monthEnd
                }
                
                let totalMinutes = sessionsForMonth.reduce(0) { $0 + ($1.actualDuration / 60) }
                
                data.append(DailyStatsData(
                    date: monthStart,
                    label: label,
                    focusMinutes: totalMinutes,
                    sessionCount: sessionsForMonth.count
                ))
            }
        }
        
        return data
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
                heatmapContainer
                
                // Pie Chart Section
                if !pieChartData.isEmpty {
                    pieChartContainer
                }
                
                // Bar Chart Section
                barChartContainer
                
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
                        .frame(maxWidth: .infinity)
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
        Group {
            switch selectedPeriod {
            case .weekly:
                weeklyHeatmap
            case .monthly:
                monthlyHeatmap
            case .yearly:
                yearlyHeatmap
            }
        }
    }
    
    private var weeklyHeatmap: some View {
        VStack(spacing: 16) {
            // Weekly calendar - centered
            HStack(spacing: 4) {
                ForEach(heatmapData, id: \.date) { day in
                    VStack(spacing: 4) {
                        Text(dayOfWeekShort(day.date))
                            .font(.custom("Geist", size: 10))
                            .foregroundColor(.secondary)
                        
                        Rectangle()
                            .fill(heatmapColor(for: day.focusMinutes))
                            .frame(width: 32, height: 32)
                            .cornerRadius(6)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            
            // Legend - bottom right
            HStack {
                Spacer()
                heatmapLegend
            }
        }
    }
    
    private var monthlyHeatmap: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                // Days of week header
                HStack(spacing: 4) {
                    ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                        Text(day)
                            .font(.custom("Geist", size: 12))
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .frame(width: 32)
                    }
                }
                
                // Calendar grid
                let weeks = generateCalendarWeeks()
                ForEach(0..<weeks.count, id: \.self) { weekIndex in
                    HStack(spacing: 4) {
                        ForEach(weeks[weekIndex], id: \.date) { day in
                            Rectangle()
                                .fill(day.isCurrentMonth ? heatmapColor(for: day.focusMinutes) : Color.clear)
                                .frame(width: 32, height: 32)
                                .cornerRadius(6)
                        }
                    }
                }
            }
            
            // Legend
            HStack {
                Spacer()
                heatmapLegend
            }
        }
    }
    
    private var yearlyHeatmap: some View {
        VStack(spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    // Month labels - compact
                    monthLabelsForYearly
                    
                    // Heatmap grid
                    LazyHGrid(rows: Array(repeating: GridItem(.fixed(12), spacing: 2), count: 15), spacing: 2) {
                        ForEach(heatmapData, id: \.date) { day in
                            Rectangle()
                                .fill(heatmapColor(for: day.focusMinutes))
                                .frame(width: 12, height: 12)
                                .cornerRadius(2)
                        }
                    }
                }
            }
            
            // Legend
            HStack {
                Spacer()
                heatmapLegend
            }
        }
    }
    
    private var heatmapContainer: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Activity Heatmap")
                    .font(.custom("Geist", size: 20))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            activityHeatmap
        }
        .padding(20)
        .background(Color(.systemBackground))
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
    
    private var pieChartContainer: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Time by Category")
                    .font(.custom("Geist", size: 20))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            timeDistributionChart
        }
        .padding(20)
        .background(Color(.systemBackground))
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
    
    private var barChartContainer: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(chartTitle)
                    .font(.custom("Geist", size: 20))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            dailyFocusChart
        }
        .padding(20)
        .background(Color(.systemBackground))
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
    
    private var timeDistributionChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            if pieChartData.isEmpty {
                emptyPieChartView
            } else {
                pieChartWithLegend
            }
        }
    }
    
    private var emptyPieChartView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No focus data")
                .font(.custom("Geist", size: 16))
                .foregroundColor(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
    
    private var pieChartWithLegend: some View {
        HStack(spacing: 20) {
            pieChart
            legendView
        }
    }
    
    private var pieChart: some View {
        Chart(pieChartData, id: \.tagName) { data in
            SectorMark(
                angle: .value("Minutes", data.minutes),
                angularInset: 1.0
            )
            .foregroundStyle(colorFromString(data.color))
            .cornerRadius(4)
        }
        .frame(width: 160, height: 160)
    }
    
    private var legendView: some View {
        let totalMinutes = pieChartData.reduce(0) { $0 + $1.minutes }
        
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(pieChartData.prefix(6)), id: \.tagName) { data in
                legendItem(data: data, totalMinutes: totalMinutes)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func legendItem(data: TagTimeData, totalMinutes: Int) -> some View {
        let percentage = totalMinutes > 0 ? Int((Double(data.minutes) / Double(totalMinutes)) * 100) : 0
        
        return HStack(spacing: 8) {
            Circle()
                .fill(colorFromString(data.color))
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(data.tagName)
                    .font(.custom("Geist", size: 13))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                Text("\(data.minutes) min")
                    .font(.custom("Geist", size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(percentage)%")
                .font(.custom("Geist", size: 11))
                .fontWeight(.medium)
                .foregroundColor(.secondary)
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
    }
    
    private var monthLabelsForYearly: some View {
        let monthAbbreviations = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let totalColumns = Int(ceil(Double(heatmapData.count) / 15.0))
        
        return HStack(spacing: 0) {
            ForEach(0..<totalColumns, id: \.self) { columnIndex in
                let monthIndex = columnIndex / 2 // Every 2 columns = roughly 1 month
                
                let shouldShow = columnIndex % 2 == 0 && monthIndex < monthAbbreviations.count
                let monthText = shouldShow ? monthAbbreviations[monthIndex] : ""
                
                Text(monthText)
                    .font(.custom("Geist", size: 7))
                    .foregroundColor(.secondary)
                    .frame(width: 14.5, alignment: .center) // Minimal spacing between months
            }
        }
    }
    
    private var heatmapLegend: some View {
        HStack(spacing: 4) {
            Text("Less")
                .font(.custom("Geist", size: 11))
                .foregroundColor(.secondary)
            
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(width: 10, height: 10)
                .cornerRadius(2)
            
            Rectangle()
                .fill(Color.green.opacity(0.3))
                .frame(width: 10, height: 10)
                .cornerRadius(2)
            
            Rectangle()
                .fill(Color.green.opacity(0.6))
                .frame(width: 10, height: 10)
                .cornerRadius(2)
            
            Rectangle()
                .fill(Color.green.opacity(0.9))
                .frame(width: 10, height: 10)
                .cornerRadius(2)
            
            Text("More")
                .font(.custom("Geist", size: 11))
                .foregroundColor(.secondary)
        }
    }
    
    private func heatmapColor(for minutes: Int) -> Color {
        switch minutes {
        case 0:
            return Color.gray.opacity(0.1) // No focus
        case 1...59:
            return Color.green.opacity(0.3) // Less than 1 hour
        case 60...179:
            return Color.green.opacity(0.6) // 1-3 hours
        default:
            return Color.green.opacity(0.9) // More than 3 hours
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
    
    private func dayOfWeekShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(1))
    }
    
    private func monthName(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
    
    private func generateCalendarWeeks() -> [[CalendarDay]] {
        let calendar = Calendar.current
        let monthStart = calendar.dateInterval(of: .month, for: currentDate)?.start ?? currentDate
        let monthEnd = calendar.dateInterval(of: .month, for: currentDate)?.end ?? currentDate
        
        // Find the start of the calendar view (beginning of week containing first day of month)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: monthStart)?.start ?? monthStart
        
        var weeks: [[CalendarDay]] = []
        var currentWeek: [CalendarDay] = []
        var current = weekStart
        
        // Generate 6 weeks to ensure we cover the entire month
        for _ in 0..<42 { // 6 weeks * 7 days
            let isCurrentMonth = calendar.isDate(current, equalTo: monthStart, toGranularity: .month)
            
            // Find session data for this day
            let dayData = heatmapData.first { calendar.isDate($0.date, inSameDayAs: current) }
            
            currentWeek.append(CalendarDay(
                date: current,
                focusMinutes: dayData?.focusMinutes ?? 0,
                isCurrentMonth: isCurrentMonth
            ))
            
            if currentWeek.count == 7 {
                weeks.append(currentWeek)
                currentWeek = []
                
                // Stop if we've gone past the month and completed a week
                if current > monthEnd && weeks.count >= 4 {
                    break
                }
            }
            
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }
        
        // Add any remaining days
        if !currentWeek.isEmpty {
            weeks.append(currentWeek)
        }
        
        return weeks
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

struct CalendarDay {
    let date: Date
    let focusMinutes: Int
    let isCurrentMonth: Bool
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