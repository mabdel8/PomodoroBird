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
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TimerView(selectedTab: $selectedTab)
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
            
            AnalyticsView()
                .tabItem {
                    Image(selectedTab == 2 ? "chartsfilled" : "charts")
                    Text("Analytics")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Image(selectedTab == 3 ? "cogfilled" : "cog")
                    Text("Settings")
                }
                .tag(3)
        }
        .accentColor(.black)
    }
}

// TimerView is now in its own file - TimerView.swift

#Preview {
    ContentView()
        .modelContainer(for: [FocusTag.self, Task.self, FocusSession.self, AppTimerState.self, CollectedBird.self], inMemory: true)
}

#Preview("TimerView") {
    TimerView(selectedTab: .constant(0))
        .modelContainer(for: [FocusTag.self, Task.self, FocusSession.self, AppTimerState.self, CollectedBird.self], inMemory: true)
}

