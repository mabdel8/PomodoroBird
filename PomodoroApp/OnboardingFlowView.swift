//
//  OnboardingFlowView.swift
//  PomodoroApp
//
//  Created by Claude on 8/5/25.
//

import SwiftUI

struct OnboardingFlowView: View {
    @State private var currentPage = 0
    let onComplete: () -> Void
    
    var body: some View {
        TabView(selection: $currentPage) {
            OnboardingPage1()
                .tag(0)
            
            OnboardingPage2()
                .tag(1)
            
            OnboardingPage3(onComplete: onComplete)
                .tag(2)
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .ignoresSafeArea()
        .background(Color(.systemBackground))
        .overlay(alignment: .topTrailing) {
            if currentPage < 2 {
                Button("Skip") {
                    onComplete()
                }
                .font(.custom("Geist", size: 16))
                .foregroundColor(.secondary)
                .padding(.top, 16)
                .padding(.trailing, 20)
            }
        }
        .overlay(alignment: .bottom) {
            if currentPage < 2 {
                PageIndicator(currentPage: currentPage, totalPages: 3)
                    .padding(.bottom, 50)
            }
        }
    }
}

// MARK: - Page 1: App Recognition & Reviews
struct OnboardingPage1: View {
    @State private var currentReviewIndex = 0
    @State private var animationTimer: Timer?
    
    let reviews = [
        Review(
            avatar: "Avatar1",
            name: "Sarah Chen",
            rating: 5,
            text: "This app completely transformed my productivity! The bird collection system makes focus sessions fun and rewarding."
        ),
        Review(
            avatar: "Avatar2", 
            name: "Marcus Rodriguez",
            rating: 5,
            text: "Love how the Pomodoro technique is gamified here. Collecting birds keeps me motivated to stay focused every day."
        )
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 20)
            
            // Artist Bird Character
            Image("artistbird")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 180, height: 180)
            
            // App of the Day Award
            VStack(spacing: 12) {
                Image("laurel")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                
            }
            
            Spacer(minLength: 16)
            
            // Animated Reviews Section
            VStack(spacing: 12) {
                let currentReview = reviews[currentReviewIndex]
                
                // Avatar
                Image(currentReview.avatar)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                
                // Stars
                Image("fivestar")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 24)
                
                // Review Text
                Text(currentReview.text)
                    .font(.custom("Geist", size: 15))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .lineLimit(3)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                
                // Reviewer Name
                Text("— \(currentReview.name)")
                    .font(.custom("Geist", size: 14))
                    .foregroundColor(.secondary)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
            .id(currentReviewIndex) // Force view recreation for smooth animation
            
            Spacer(minLength: 80) // Extra space to avoid page indicator
        }
        .padding(.horizontal, 24)
        .onAppear {
            startReviewTimer()
        }
        .onDisappear {
            stopReviewTimer()
        }
    }
    
    private func startReviewTimer() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.8)) {
                currentReviewIndex = (currentReviewIndex + 1) % reviews.count
            }
        }
    }
    
    private func stopReviewTimer() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
}

// MARK: - Page 2: Task Management Features  
struct OnboardingPage2: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 20)
            
            // Task Screenshot with Gradient
            ZStack {
                Image("taskscreenshot")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 300)
                    .cornerRadius(16)
                    .overlay(
                        // Gradient overlay for fading effect at bottom
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .clear, location: 0.6),
                                .init(color: Color(.systemBackground).opacity(0.8), location: 1.0)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .cornerRadius(16)
                    )
            }
            
            Spacer(minLength: 16)
            

            
            Spacer(minLength: 16)
            
            // Description Text
            VStack(spacing: 8) {
                // Bird with Checklist
                Image("checklist")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                Text("Stay Organized & Focused")
                    .font(.custom("Geist", size: 24))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Create tasks, set focus durations, and track your productivity with beautiful categories and timers.")
                    .font(.custom("Geist", size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .lineLimit(3)
            }
            
            Spacer(minLength: 80) // Extra space to avoid page indicator
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Page 3: Collection System & CTA
struct OnboardingPage3: View {
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 20)
            
            // Collection Screenshot
            Image("collectionscreenshot")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 300)
                .cornerRadius(16)
                .overlay(
                    // Gradient overlay for fading effect at bottom
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .clear, location: 0.6),
                            .init(color: Color(.systemBackground).opacity(0.8), location: 1.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .cornerRadius(16)
                )
            
            Spacer(minLength: 12)
            
            // Final CTA Section
            VStack(spacing: 10) {
                Text("We're all set!")
                    .font(.custom("Geist", size: 26))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Complete focus sessions to unlock adorable bird characters. Each bird represents your dedication to productivity!")
                    .font(.custom("Geist", size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .lineLimit(3)
            }
            
            Spacer(minLength: 16)
            
            // Let's Go Button
            Button(action: onComplete) {
                Text("Let's go!")
                    .font(.custom("Geist", size: 18))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 200)
                    .padding(.vertical, 16)
                    .background(Color.black)
                    .cornerRadius(25)
            }
            
            Spacer(minLength: 80) // Space for page indicator
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Supporting Views

struct Review {
    let avatar: String
    let name: String
    let rating: Int
    let text: String
}

struct TaskRow: View {
    let title: String
    let category: String
    let duration: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            // Colored Left Border
            Rectangle()
                .fill(color)
                .frame(width: 3, height: 40)
            
            // Checkbox
            Circle()
                .stroke(color.opacity(0.3), lineWidth: 2)
                .frame(width: 20, height: 20)
            
            // Task Info
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("Geist", size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                    
                    Text(category)
                        .font(.custom("Geist", size: 14))
                        .foregroundColor(color)
                    
                    Text(duration)
                        .font(.custom("Geist", size: 14))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
}

struct BirdCollectionCard: View {
    let imageName: String
    let title: String
    let isUnlocked: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .opacity(isUnlocked ? 1.0 : 0.3)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isUnlocked ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                        .frame(width: 80, height: 80)
                )
            
            Text(title)
                .font(.custom("Geist", size: 12))
                .foregroundColor(isUnlocked ? .primary : .secondary)
        }
    }
}

struct PageIndicator: View {
    let currentPage: Int
    let totalPages: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? Color.primary : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }
}

#Preview {
    OnboardingFlowView {
        print("Onboarding completed")
    }
}
