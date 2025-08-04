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
            
            Group {
                if appStateManager.isSubscribed {
                    AnalyticsView()
                } else {
                    PaywallPromptView()
                        .environmentObject(appStateManager)
                }
            }
                .tabItem {
                    Image(selectedTab == 2 ? "chartsfilled" : "charts")
                    Text("Analytics")
                }
                .tag(2)
            
            CollectionView()
                .tabItem {
                    Image(selectedTab == 3 ? "collectionsfilled" : "collections")
                        .font(.system(size: 18))
                    Text("Collection")
                }
                .tag(3)
            

        }
        .accentColor(.black)
        .onAppear {
            initializeStateManager()
        }
        .sheet(isPresented: $appStateManager.showOnboarding) {
            OnboardingView(
                appName: "Pomodoro Timer",
                features: [
                    Feature(title: "Boost Productivity", description: "Stay focused with timed work and break sessions.", icon: "clock"),
                    Feature(title: "Stay Motivated", description: "Earn unique rewards after each session.", icon: "star"),
                    Feature(title: "Track Your Progress", description: "View your focus stats and trends over time.", icon: "chart.bar"),
                    Feature(title: "Minimal & Ad-Free", description: "Enjoy a clean, distraction-free experience.", icon: "sparkles")
                ],
                color: Color.blue
            )
            .onDisappear {
                appStateManager.onboardingCompleted()
            }
        }
        .sheet(isPresented: $appStateManager.showPaywall) {
            PurchaseView(isPresented: $appStateManager.showPaywall)
                .environmentObject(appStateManager.purchaseManager)
                .onDisappear {
                    appStateManager.paywallDismissed()
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
}

#Preview("TimerView") {
    ContentView()
        .modelContainer(for: [FocusTag.self, Task.self, FocusSession.self, AppTimerState.self, CollectedBird.self], inMemory: true)
}

