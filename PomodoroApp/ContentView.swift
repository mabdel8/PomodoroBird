//
//  ContentView.swift
//  PomodoroApp
//
//  Created by Mohamed Abdelmagid on 7/23/25.
//

import SwiftUI
import SwiftData
import Foundation


struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appStateManager: AppStateManager
    @Query(sort: \FocusTag.name) private var tags: [FocusTag]
    @Query(filter: #Predicate<Task> { !$0.isCompleted }, sort: \Task.createdAt, order: .reverse) private var availableTasks: [Task]
    @Query private var timerStates: [AppTimerState]
    @Query(sort: \FocusSession.createdAt, order: .reverse) private var recentSessions: [FocusSession]
    @Query(sort: \CollectedBird.collectedAt, order: .reverse) private var collectedBirds: [CollectedBird]
    
    @State private var selectedTab = 0
    @State private var stateManager: TimerStateManager?
    
    var body: some View {
        Group {
            if appStateManager.showOnboarding {
                OnboardingFlowView {
                    appStateManager.onboardingCompleted()
                }
            } else if appStateManager.showPaywall {
                PurchaseView(
                    isPresented: $appStateManager.showPaywall,
                    hasCooldown: !appStateManager.paywallIsManuallyOpened
                )
                    .environmentObject(appStateManager.purchaseManager)
                    .onDisappear {
                        appStateManager.paywallDismissed()
                    }
            } else {
                mainAppContent
            }
        }
        .onAppear {
            initializeStateManager()
        }
        .onChange(of: appStateManager.navigateToAnalytics) { shouldNavigate in
            if shouldNavigate {
                selectedTab = 2 // Navigate to Analytics tab
                appStateManager.analyticsNavigationHandled()
            }
        }
    }
    
    private var mainAppContent: some View {
        TabView(selection: $selectedTab) {
            Group {
                if let stateManager = stateManager {
                    TimerView(selectedTab: $selectedTab, stateManager: stateManager)
                } else {
                    VStack {
                        ProgressView()
                        Text("Loading...")
                            .font(.custom("Geist", size: 16))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tabItem {
                Image(selectedTab == 0 ? "timerfilled" : "timer")
                Text("Timer")
            }
            .tag(0)
            
            TaskManagerView()
                .tabItem {
                    Image(selectedTab == 1 ? "stackfilled" : "stack")
                    Text("Tasks")
                }
                .tag(1)
            
            CollectionView()
                .tabItem {
                    Image(selectedTab == 2 ? "collectionsfilled" : "collections")
                        .font(.system(size: 18))
                    Text("Collection")
                }
                .tag(2)
            
            AnalyticsView()
                .environmentObject(appStateManager)
                .tabItem {
                    Image(selectedTab == 3 ? "chartsfilled" : "charts")
                    Text("Analytics")
                }
                .tag(3)
        }
        .accentColor(.black)
        .animation(.easeInOut(duration: 0.3), value: selectedTab)
        .onAppear {
            initializeStateManager()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openCollectionTab)) { _ in
            withAnimation(.easeInOut(duration: 0.4)) {
                selectedTab = 2 // Switch to Collection tab with animation
            }
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
}

// TimerView is now in its own file - TimerView.swift

#Preview {
    ContentView()
        .modelContainer(for: [FocusTag.self, Task.self, FocusSession.self, AppTimerState.self, CollectedBird.self], inMemory: true)
        .environmentObject(AppStateManager())
}

#Preview("TimerView") {
    ContentView()
        .modelContainer(for: [FocusTag.self, Task.self, FocusSession.self, AppTimerState.self, CollectedBird.self], inMemory: true)
        .environmentObject(AppStateManager())
}

