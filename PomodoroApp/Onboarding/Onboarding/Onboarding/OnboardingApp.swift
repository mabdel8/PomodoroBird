//
//  OnboardingApp.swift
//  Onboarding
//
//  Created by Abdalla Abdelmagid on 7/31/25.
//

import SwiftUI

@main
struct OnboardingApp: App {
    var body: some Scene {
        WindowGroup {
            OnboardingView(appName: "Pomodoro Timer", features: [
                Feature(title: "Boost Productivity", description: "Stay focused with timed work and break sessions.", icon: "clock"),
                Feature(title: "Stay Motivated", description: "Earn unique rewards after each session.", icon: "star"),
                Feature(title: "Track Your Progress", description: "View your focus stats and trends over time.", icon: "chart.bar"),
                Feature(title: "Minimal & Ad-Free", description: "Enjoy a clean, distraction-free experience.", icon: "sparkles"),
            ], color: Color.blue)
        }
    }
}
