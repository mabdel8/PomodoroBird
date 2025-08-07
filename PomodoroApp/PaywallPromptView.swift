//
//  PaywallPromptView.swift
//  PomodoroApp
//
//  Created by Claude on 8/4/25.
//

import SwiftUI

struct PaywallPromptView: View {
    @EnvironmentObject var appStateManager: AppStateManager
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.black)
                
                Text("Analytics Premium")
                    .font(.custom("Geist", size: 28))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("Get detailed insights into your focus sessions, productivity trends, and progress over time.")
                    .font(.custom("Geist", size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            VStack(spacing: 12) {
                FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Focus Trends")
                FeatureRow(icon: "calendar", title: "Activity Heatmap")
                FeatureRow(icon: "chart.pie", title: "Category Breakdown")
                FeatureRow(icon: "trophy", title: "Achievement Tracking")
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            Button(action: {
                appStateManager.presentPaywall()
            }) {
                HStack {
                    Text("Unlock Analytics")
                        .font(.custom("Geist", size: 18))
                        .fontWeight(.semibold)
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.black)
                .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.black)
                .frame(width: 24)
            
            Text(title)
                .font(.custom("Geist", size: 16))
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.green)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PaywallPromptView()
        .environmentObject(AppStateManager())
}
