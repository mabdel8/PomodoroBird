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
    @EnvironmentObject var appStateManager: AppStateManager
    @Query(sort: \FocusSession.createdAt, order: .reverse) private var focusSessions: [FocusSession]
    @Query(sort: \FocusTag.name) private var tags: [FocusTag]
    @Query(sort: \CollectedBird.collectedAt, order: .reverse) private var collectedBirds: [CollectedBird]
    
    @State private var selectedPeriod: TimePeriod = .weekly
    @State private var currentDate = Date()
    @State private var showingSessionHistory = false
    @State private var showingChartDetails = false
    
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
    
    // Current date string based on selected period
    private var currentDateString: String {
        let formatter = DateFormatter()
        
        switch selectedPeriod {
        case .weekly:
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: currentDate)?.start ?? currentDate
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? currentDate
            
            formatter.dateFormat = "MMM d"
            let startString = formatter.string(from: weekStart)
            let endString = formatter.string(from: weekEnd)
            return "\(startString) - \(endString)"
            
        case .monthly:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: currentDate)
            
        case .yearly:
            formatter.dateFormat = "yyyy"
            return formatter.string(from: currentDate)
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
    
    // Bar chart data with category breakdown
    private var categoryBreakdownData: [CategoryBreakdownData] {
        let calendar = Calendar.current
        var data: [CategoryBreakdownData] = []
        
        switch selectedPeriod {
        case .weekly:
            // Show daily data for selected week
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: currentDate)?.start ?? currentDate
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
                
                // Group sessions by category
                let categoryGroups = Dictionary(grouping: sessionsForDay) { session in
                    session.tagName ?? "No Category"
                }
                
                let categoryBreakdown = categoryGroups.map { categoryName, sessions in
                    let totalMinutes = sessions.reduce(0) { $0 + ($1.actualDuration / 60) }
                    let categoryColor = sessions.first?.tagColor ?? "blue"
                    return CategoryData(
                        categoryName: categoryName,
                        categoryColor: categoryColor,
                        minutes: totalMinutes
                    )
                }.sorted { $0.minutes > $1.minutes }
                
                let totalMinutes = sessionsForDay.reduce(0) { $0 + ($1.actualDuration / 60) }
                
                data.append(CategoryBreakdownData(
                    date: date,
                    label: label,
                    categoryBreakdown: categoryBreakdown,
                    totalMinutes: totalMinutes
                ))
            }
            
        case .monthly:
            // Show weekly data for selected month
            let monthStart = calendar.dateInterval(of: .month, for: currentDate)?.start ?? currentDate
            let monthEnd = calendar.dateInterval(of: .month, for: currentDate)?.end ?? currentDate
            
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
                
                // Group sessions by category
                let categoryGroups = Dictionary(grouping: sessionsForWeek) { session in
                    session.tagName ?? "No Category"
                }
                
                let categoryBreakdown = categoryGroups.map { categoryName, sessions in
                    let totalMinutes = sessions.reduce(0) { $0 + ($1.actualDuration / 60) }
                    let categoryColor = sessions.first?.tagColor ?? "blue"
                    return CategoryData(
                        categoryName: categoryName,
                        categoryColor: categoryColor,
                        minutes: totalMinutes
                    )
                }.sorted { $0.minutes > $1.minutes }
                
                let totalMinutes = sessionsForWeek.reduce(0) { $0 + ($1.actualDuration / 60) }
                
                data.append(CategoryBreakdownData(
                    date: weekStart,
                    label: "W\(weekNumber)",
                    categoryBreakdown: categoryBreakdown,
                    totalMinutes: totalMinutes
                ))
                
                weekStart = weekEnd
                weekNumber += 1
            }
            
        case .yearly:
            // Show monthly data for selected year
            let yearStart = calendar.dateInterval(of: .year, for: currentDate)?.start ?? currentDate
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
                
                // Group sessions by category
                let categoryGroups = Dictionary(grouping: sessionsForMonth) { session in
                    session.tagName ?? "No Category"
                }
                
                let categoryBreakdown = categoryGroups.map { categoryName, sessions in
                    let totalMinutes = sessions.reduce(0) { $0 + ($1.actualDuration / 60) }
                    let categoryColor = sessions.first?.tagColor ?? "blue"
                    return CategoryData(
                        categoryName: categoryName,
                        categoryColor: categoryColor,
                        minutes: totalMinutes
                    )
                }.sorted { $0.minutes > $1.minutes }
                
                let totalMinutes = sessionsForMonth.reduce(0) { $0 + ($1.actualDuration / 60) }
                
                data.append(CategoryBreakdownData(
                    date: monthStart,
                    label: label,
                    categoryBreakdown: categoryBreakdown,
                    totalMinutes: totalMinutes
                ))
            }
        }
        
        return data
    }
    
    // Bar chart data (keeping for backward compatibility)
    private var barChartData: [DailyStatsData] {
        let calendar = Calendar.current
        var data: [DailyStatsData] = []
        
        switch selectedPeriod {
        case .weekly:
            // Show daily data for selected week
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: currentDate)?.start ?? currentDate
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
            // Show weekly data for selected month
            let monthStart = calendar.dateInterval(of: .month, for: currentDate)?.start ?? currentDate
            let monthEnd = calendar.dateInterval(of: .month, for: currentDate)?.end ?? currentDate
            
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
            // Show monthly data for selected year
            let yearStart = calendar.dateInterval(of: .year, for: currentDate)?.start ?? currentDate
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
        Group {
            if appStateManager.isSubscribed {
                ScrollView {
                    VStack(spacing: 20) {
                        // Header with date navigation and period selector
                        VStack(spacing: 16) {
                            // Date navigation
                            HStack {
                                Button(action: navigatePrevious) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                                
                                Spacer()
                                
                                Text(currentDateString)
                                    .font(.custom("Geist", size: 20))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Button(action: navigateNext) {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                            
                            // Period Selector
                            periodSelector
                        }
                        
                        // Stats Overview with History Button
                        statsContainerWithHistoryButton
                        
                        // Pie Chart Section
                        if !pieChartData.isEmpty {
                            pieChartContainer
                        }
                        
                        // Bar Chart Section
                        barChartContainer
                        
                        // Bird Collection Section
                        if !collectedBirds.isEmpty {
                            birdCollectionContainer
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
                .background(Color(.systemBackground))
                .sheet(isPresented: $showingSessionHistory) {
                    SessionHistoryView(focusSessions: focusSessions)
                }
                .sheet(isPresented: $showingChartDetails) {
                    ChartDetailsView(categoryBreakdownData: categoryBreakdownData, selectedPeriod: selectedPeriod)
                }
            } else {
                PaywallPromptView()
                    .environmentObject(appStateManager)
            }
        }
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
                                .fill(selectedPeriod == period ? Color.black : Color.clear)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemGray5))
        )
        .padding(.horizontal, 24)
    }
    
    private var statsContainer: some View {
        let totalMinutes = filteredSessions.reduce(0) { $0 + ($1.actualDuration / 60) }
        let sessionCount = filteredSessions.count
        let averageMinutes = sessionCount > 0 ? totalMinutes / sessionCount : 0
        
        return VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Overview")
                    .font(.custom("Geist", size: 20))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    showingSessionHistory = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 14, weight: .medium))
                        
                        Text("History")
                            .font(.custom("Geist", size: 14))
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.blue.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            HStack(spacing: 32) {
                totalFocusView(totalMinutes: totalMinutes)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 1, height: 40)
                
                sessionsView(sessionCount: sessionCount)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 1, height: 40)
                
                averageSessionView(averageMinutes: averageMinutes)
            }
            
            // Most Focused Day
            mostFocusedDayView
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
    
    private var statsContainerWithHistoryButton: some View {
        statsContainer
    }
    
    private func totalFocusView(totalMinutes: Int) -> some View {
        VStack(spacing: 8) {
            Text("\(totalMinutes)")
                .font(.custom("Geist", size: 28))
                .fontWeight(.bold)
                .foregroundColor(.black)
            
            VStack(spacing: 2) {
                Text("Total Focus")
                    .font(.custom("Geist", size: 12))
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text("minutes")
                    .font(.custom("Geist", size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func sessionsView(sessionCount: Int) -> some View {
        VStack(spacing: 8) {
            Text("\(sessionCount)")
                .font(.custom("Geist", size: 28))
                .fontWeight(.bold)
                .foregroundColor(.black)
            
            VStack(spacing: 2) {
                Text("Sessions")
                    .font(.custom("Geist", size: 12))
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text("completed")
                    .font(.custom("Geist", size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func averageSessionView(averageMinutes: Int) -> some View {
        VStack(spacing: 8) {
            Text("\(averageMinutes)")
                .font(.custom("Geist", size: 28))
                .fontWeight(.bold)
                .foregroundColor(.black)
            
            VStack(spacing: 2) {
                Text("Avg Session")
                    .font(.custom("Geist", size: 12))
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text("minutes")
                    .font(.custom("Geist", size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var mostFocusedDayView: some View {
        let dailyTotals = Dictionary(grouping: filteredSessions) { session in
            calendar.startOfDay(for: session.createdAt)
        }.mapValues { sessions in
            sessions.reduce(0) { $0 + ($1.actualDuration / 60) }
        }
        
        let mostFocusedDay = dailyTotals.max { $0.value < $1.value }
        let formatter = DateFormatter()
        
        // Adjust date format based on selected period
        switch selectedPeriod {
        case .weekly:
            formatter.dateFormat = "E, MMM d" // "Fri, Jul 25"
        case .monthly:
            formatter.dateFormat = "MMM d" // "Jul 25"
        case .yearly:
            formatter.dateFormat = "MMM d, yyyy" // "Jul 25, 2024"
        }
        
        return HStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
                
                Text("Most Focused Day")
                    .font(.custom("Geist", size: 14))
                    .fontWeight(.bold)
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color(hex: "F2F2F2"))
            )
            
            Spacer()
            
            Group {
                if let mostDay = mostFocusedDay {
                    Text("\(formatter.string(from: mostDay.key)), \(mostDay.value) min")
                        .font(.custom("Geist", size: 14))
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                } else {
                    Text("No data")
                        .font(.custom("Geist", size: 14))
                        .foregroundColor(.secondary)
                }
            }
        }
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
    
        private var birdCollectionContainer: some View {
        VStack(alignment: .leading, spacing: 20) {
            collectionHeader
            collectionProgressSection
            collectionStatsSection
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
    
    private var collectionHeader: some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: "bird.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
                
                Text("\(selectedPeriod.rawValue) Progress")
                    .font(.custom("Geist", size: 20))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Button(action: {
                NotificationCenter.default.post(name: .openCollectionTab, object: nil)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .medium))
                    
                    Text("View All")
                        .font(.custom("Geist", size: 14))
                        .fontWeight(.medium)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.blue.opacity(0.1))
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var collectionProgressSection: some View {
        HStack(spacing: 32) {
            // Left side: Progress ring with better styling
            VStack(spacing: 12) {
                progressRing
            }
            .frame(maxWidth: .infinity)
            
            // Right side: Latest bird with improved layout
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .center, spacing: 12) {
                    if let recentBird = collectedBirds.first, let birdType = recentBird.birdType {
                        // First: Bird image
                        Image(birdType.birdImageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                        
                        // Second: Bird name
                        Text(birdType.displayName)
                            .font(.custom("Geist", size: 16))
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        // Third: Date
                        Text("Unlocked \(formatDate(recentBird.collectedAt))")
                            .font(.custom("Geist", size: 12))
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    } else {
                        // First: Bird image
                        Image(systemName: "bird.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue.opacity(0.6))
                        
                        // Second: Bird name
                        Text("No birds yet")
                            .font(.custom("Geist", size: 16))
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        // Third: Date
                        Text("Start focusing to collect")
                            .font(.custom("Geist", size: 12))
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
    }
    
    private var progressRing: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background circle with subtle shadow
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 10)
                    .frame(width: 100, height: 100)
                
                // Progress arc with gradient
                Circle()
                    .trim(from: 0, to: collectionProgress)
                    .stroke(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: collectionProgress)
                
                // Center content
                VStack(spacing: 2) {
                    Text("\(Int(collectionProgress * 100))%")
                        .font(.custom("Geist", size: 20))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Complete")
                        .font(.custom("Geist", size: 10))
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.3)
                }
            }
            
            Text("Collection Progress")
                .font(.custom("Geist", size: 12))
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    

    
    private var collectionStatsSection: some View {
        HStack(spacing: 32) {
            customStatItem(iconPath: "M20.25 14.15v4.25c0 1.094-.787 2.036-1.872 2.18-2.087.277-4.216.42-6.378.42s-4.291-.143-6.378-.42c-1.085-.144-1.872-1.086-1.872-2.18v-4.25m16.5 0a2.18 2.18 0 0 0 .75-1.661V8.706c0-1.081-.768-2.015-1.837-2.175a48.114 48.114 0 0 0-3.413-.387m4.5 8.006c-.194.165-.42.295-.673.38A23.978 23.978 0 0 1 12 15.75c-2.648 0-5.195-.429-7.577-1.22a2.016 2.016 0 0 1-.673-.38m0 0A2.18 2.18 0 0 1 3 12.489V8.706c0-1.081.768-2.015 1.837-2.175a48.111 48.111 0 0 1 3.413-.387m7.5 0V5.25A2.25 2.25 0 0 0 13.5 3h-3a2.25 2.25 0 0 0-2.25 2.25v.894m7.5 0a48.667 48.667 0 0 0-7.5 0M12 12.75h.008v.008H12v-.008Z", value: "\(birdsCollectedInPeriod)", label: "Birds Collected")
            
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1, height: 40)
            
            customStatItem(iconPath: "M9.813 15.904 9 18.75l-.813-2.846a4.5 4.5 0 0 0-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 0 0 3.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 0 0 3.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 0 0-3.09 3.09ZM18.259 8.715 18 9.75l-.259-1.035a3.375 3.375 0 0 0-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 0 0 2.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 0 0 2.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 0 0-2.456 2.456ZM16.894 20.567 16.5 21.75l-.394-1.183a2.25 2.25 0 0 0-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 0 0 1.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 0 0 1.423 1.423l1.183.394-1.183.394a2.25 2.25 0 0 0-1.423 1.423Z", value: "\(newBirdsInPeriod)", label: "New Birds")
            
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1, height: 40)
            
            customStatItem(iconPath: "M15.362 5.214A8.252 8.252 0 0 1 12 21 8.25 8.25 0 0 1 6.038 7.047 8.287 8.287 0 0 0 9 9.601a8.983 8.983 0 0 1 3.361-6.867 8.21 8.21 0 0 0 3 2.48ZM12 18a3.75 3.75 0 0 0 .495-7.468 5.99 5.99 0 0 0-1.925 3.547 5.975 5.975 0 0 1-2.133-1.001A3.75 3.75 0 0 0 12 18Z", value: "\(focusStreakInPeriod)", label: "Focus Streak")
        }
    }
    
    private func statItem(icon: String, value: String, label: String, iconColor: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
            
            VStack(spacing: 4) {
                Text(value)
                    .font(.custom("Geist", size: 18))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(label)
                    .font(.custom("Geist", size: 12))
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func customStatItem(iconPath: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.custom("Geist", size: 18))
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(label)
                .font(.custom("Geist", size: 12))
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
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
        Chart(categoryBreakdownData, id: \.date) { periodData in
            // Area mark for gradient fill with smooth curves
            AreaMark(
                x: .value("Period", periodData.label),
                y: .value("Minutes", periodData.totalMinutes)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.blue.opacity(0.4), Color.blue.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)
            
            // Line mark for the actual line with smooth curves
            LineMark(
                x: .value("Period", periodData.label),
                y: .value("Minutes", periodData.totalMinutes)
            )
            .foregroundStyle(Color.blue)
            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .foregroundStyle(.gray.opacity(0.6))
                    .font(.custom("Geist", size: 12))
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .foregroundStyle(.gray.opacity(0.6))
                    .font(.custom("Geist", size: 12))
            }
        }
        .frame(height: 200)
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
    
    // Navigation methods
    private func navigatePrevious() {
        switch selectedPeriod {
        case .weekly:
            currentDate = calendar.date(byAdding: .weekOfYear, value: -1, to: currentDate) ?? currentDate
        case .monthly:
            currentDate = calendar.date(byAdding: .month, value: -1, to: currentDate) ?? currentDate
        case .yearly:
            currentDate = calendar.date(byAdding: .year, value: -1, to: currentDate) ?? currentDate
        }
    }
    
    private func navigateNext() {
        switch selectedPeriod {
        case .weekly:
            currentDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) ?? currentDate
        case .monthly:
            currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
        case .yearly:
            currentDate = calendar.date(byAdding: .year, value: 1, to: currentDate) ?? currentDate
        }
    }
    
    private func showChartDetails() {
        showingChartDetails = true
    }
    

    

    

    
    private func timeAgo(from date: Date) -> String {
        let now = Date()
        let components = Calendar.current.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let days = components.day, days > 0 {
            return "\(days)d ago"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)h ago"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "now"
        }
    }
    
    // MARK: - Bird Collection Analytics
    
    private var uniqueBirdsCollected: Int {
        Set(collectedBirds.compactMap { $0.birdType }).count
    }
    
    private var collectionProgress: Double {
        guard !BirdType.allCases.isEmpty else { return 0 }
        return Double(uniqueBirdsCollected) / Double(BirdType.allCases.count)
    }
    
    // Dynamic collection stats based on selected period
    private var birdsCollectedInPeriod: Int {
        let startDate = getPeriodStartDate()
        let endDate = getPeriodEndDate()
        
        let birdsInPeriod = collectedBirds.filter { bird in
            bird.collectedAt >= startDate && bird.collectedAt <= endDate
        }
        
        return birdsInPeriod.count // Total birds collected (including duplicates)
    }
    
    private var newBirdsInPeriod: Int {
        let startDate = getPeriodStartDate()
        let endDate = getPeriodEndDate()
        
        // Get all birds collected before this period
        let birdsBeforePeriod = collectedBirds.filter { bird in
            bird.collectedAt < startDate
        }
        let birdTypesBeforePeriod = Set(birdsBeforePeriod.compactMap { $0.birdType })
        
        // Get birds collected in this period that are new (not collected before)
        let newBirdsInPeriod = collectedBirds.filter { bird in
            guard let birdType = bird.birdType else { return false }
            return bird.collectedAt >= startDate && 
                   bird.collectedAt <= endDate &&
                   !birdTypesBeforePeriod.contains(birdType)
        }
        
        return Set(newBirdsInPeriod.compactMap { $0.birdType }).count // Unique new birds
    }
    
    private var focusStreakInPeriod: Int {
        let startDate = getPeriodStartDate()
        let endDate = getPeriodEndDate()
        
        let sessionsInPeriod = focusSessions.filter { session in
            session.isCompleted && 
            session.sessionType == "focus" &&
            session.createdAt >= startDate && 
            session.createdAt <= endDate
        }
        
        // Calculate consecutive days with focus sessions
        let calendar = Calendar.current
        let sessionDates = Set(sessionsInPeriod.map { calendar.startOfDay(for: $0.createdAt) })
        let sortedDates = sessionDates.sorted()
        
        var streak = 0
        var currentStreak = 0
        var previousDate: Date?
        
        for date in sortedDates {
            if let prev = previousDate,
               calendar.dateComponents([.day], from: prev, to: date).day == 1 {
                currentStreak += 1
            } else {
                currentStreak = 1
            }
            streak = max(streak, currentStreak)
            previousDate = date
        }
        
        return streak
    }
    

    
    private func getPeriodStartDate() -> Date {
        let calendar = Calendar.current
        
        switch selectedPeriod {
        case .weekly:
            return calendar.dateInterval(of: .weekOfYear, for: currentDate)?.start ?? currentDate
        case .monthly:
            return calendar.dateInterval(of: .month, for: currentDate)?.start ?? currentDate
        case .yearly:
            return calendar.dateInterval(of: .year, for: currentDate)?.start ?? currentDate
        }
    }
    
    private func getPeriodEndDate() -> Date {
        let calendar = Calendar.current
        
        switch selectedPeriod {
        case .weekly:
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: currentDate)?.start ?? currentDate
            return calendar.date(byAdding: .day, value: 7, to: weekStart) ?? currentDate
        case .monthly:
            let monthStart = calendar.dateInterval(of: .month, for: currentDate)?.start ?? currentDate
            return calendar.date(byAdding: .month, value: 1, to: monthStart) ?? currentDate
        case .yearly:
            let yearStart = calendar.dateInterval(of: .year, for: currentDate)?.start ?? currentDate
            return calendar.date(byAdding: .year, value: 1, to: yearStart) ?? currentDate
        }
    }
    
    private var collectionRate: String {
        guard !collectedBirds.isEmpty else { return "0" }
        
        let calendar = Calendar.current
        let now = Date()
        
        let startDate: Date
        switch selectedPeriod {
        case .weekly:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .monthly:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .yearly:
            startDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        }
        
        let recentBirds = collectedBirds.filter { $0.collectedAt >= startDate }
        let uniqueRecentBirds = Set(recentBirds.compactMap { $0.birdType }).count
        
        return "\(uniqueRecentBirds)"
    }
    
    private var daysSinceFirstCollection: Int {
        guard let firstBird = collectedBirds.last else { return 0 }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: firstBird.collectedAt, to: Date())
        return components.day ?? 0
    }
    
    private var periodLabel: String {
        switch selectedPeriod {
        case .weekly:
            return "This Week"
        case .monthly:
            return "This Month"
        case .yearly:
            return "This Year"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

struct BirdCollectionItem: View {
    let birdType: BirdType
    let isCollected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isCollected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                    .frame(width: 64, height: 64)
                
                if isCollected {
                    Image(birdType.birdImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                } else {
                    ZStack {
                        Image(birdType.birdImageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48)
                            .grayscale(1.0)
                            .opacity(0.3)
                        
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.gray.opacity(0.6))
                    }
                }
            }
            
            Text(isCollected ? birdType.displayName : "???")
                .font(.custom("Geist", size: 10))
                .fontWeight(.medium)
                .foregroundColor(isCollected ? .primary : .secondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Data Models

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

struct CategoryBreakdownData {
    let date: Date
    let label: String
    let categoryBreakdown: [CategoryData]
    let totalMinutes: Int
}

struct CategoryData {
    let categoryName: String
    let categoryColor: String
    let minutes: Int
}

struct SessionHistoryView: View {
    let focusSessions: [FocusSession]
    @Environment(\.dismiss) private var dismiss
    
    private var recentSessions: [FocusSession] {
        focusSessions
            .filter { $0.isCompleted && $0.sessionType == "focus" }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(50)
            .map { $0 }
    }
    
    private var groupedSessions: [(String, [FocusSession])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: recentSessions) { session in
            calendar.startOfDay(for: session.createdAt)
        }
        
        return grouped.sorted { $0.key > $1.key }.map { date, sessions in
            let formatter = DateFormatter()
            formatter.dateStyle = .full
            let dateString = formatter.string(from: date)
            return (dateString, sessions.sorted { $0.createdAt > $1.createdAt })
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    ForEach(groupedSessions, id: \.0) { dateString, sessions in
                        dayContainer(dateString: dateString, sessions: sessions)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color.white)
            .navigationTitle("Session History")
            .navigationBarTitleDisplayMode(.large)
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
        .background(Color.white)
        .preferredColorScheme(.light)
    }
    
    private func dayContainer(dateString: String, sessions: [FocusSession]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date header above container
            Text(dateString)
                .font(.custom("Geist", size: 18))
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
            
            // Container with tasks
            VStack(spacing: 0) {
                ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                    VStack(spacing: 0) {
                        SessionRowView(session: session)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        
                        // Divider line (except for last item)
                        if index < sessions.count - 1 {
                            Rectangle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: 1)
                                .padding(.horizontal, 16)
                        }
                    }
                }
            }
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
}

struct SessionRowView: View {
    let session: FocusSession
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
        var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.taskTitle ?? "Focus Session")
                    .font(.custom("Geist", size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                if let tagName = session.tagName, let tagColor = session.tagColor {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(colorFromString(tagColor))
                            .frame(width: 8, height: 8)

                        Text(tagName)
                            .font(.custom("Geist", size: 12))
                            .fontWeight(.light)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                // Duration as pill
                Text("\(session.actualDuration / 60) min")
                    .font(.custom("Geist", size: 12))
                    .fontWeight(.medium)
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.1))
                    )

                // Time only (no date)
                Text(timeFormatter.string(from: session.createdAt))
                    .font(.custom("Geist", size: 11))
                    .foregroundColor(.secondary)
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

struct ChartDetailsView: View {
    let categoryBreakdownData: [CategoryBreakdownData]
    let selectedPeriod: TimePeriod
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(categoryBreakdownData, id: \.date) { periodData in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(periodData.label)
                                .font(.custom("Geist", size: 16))
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(periodData.totalMinutes) min")
                                .font(.custom("Geist", size: 16))
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                        }
                        
                        if !periodData.categoryBreakdown.isEmpty {
                            VStack(spacing: 8) {
                                ForEach(periodData.categoryBreakdown, id: \.categoryName) { category in
                                    HStack {
                                        Circle()
                                            .fill(colorFromString(category.categoryColor))
                                            .frame(width: 8, height: 8)
                                        
                                        Text(category.categoryName)
                                            .font(.custom("Geist", size: 14))
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Text("\(category.minutes) min")
                                            .font(.custom("Geist", size: 14))
                                            .fontWeight(.medium)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.leading, 8)
                        } else {
                            Text("No focus sessions")
                                .font(.custom("Geist", size: 14))
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Focus Details")
            .navigationBarTitleDisplayMode(.large)
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
    AnalyticsView()
        .modelContainer(for: [FocusTag.self, Task.self, FocusSession.self, AppTimerState.self, CollectedBird.self], inMemory: true)
        .environmentObject(AppStateManager())
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let openCollectionTab = Notification.Name("openCollectionTab")
}

 
