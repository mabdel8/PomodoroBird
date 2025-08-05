//
//  AppStateManager.swift
//  PomodoroApp
//
//  Created by Claude on 8/4/25.
//

import SwiftUI
import Foundation
import Combine

class AppStateManager: ObservableObject {
    @Published var showOnboarding = false
    @Published var showPaywall = false
    @Published var isSubscribed = false
    @Published var navigateToAnalytics = false
    
    private let purchaseModel = PurchaseModel()
    private var wasSubscribed = false
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        checkAppState()
    }
    
    private func checkAppState() {
        let hasSeenOnboarding = UserDefaults.standard.bool(forKey: "OnboardingSeen")
        
        if !hasSeenOnboarding {
            // New user - show onboarding first
            showOnboarding = true
        } else {
            // Existing user - check subscription status
            checkSubscriptionAndShowPaywall()
        }
        
        // Monitor subscription status changes
        purchaseModel.$isSubscribed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newSubscriptionStatus in
                guard let self = self else { return }
                
                // Check if this is a new subscription (wasn't subscribed before, now is)
                if !self.wasSubscribed && newSubscriptionStatus {
                    // Purchase was successful - dismiss paywall and navigate to analytics
                    self.showPaywall = false
                    self.navigateToAnalytics = true
                }
                
                self.isSubscribed = newSubscriptionStatus
                self.wasSubscribed = newSubscriptionStatus
            }
            .store(in: &cancellables)
    }
    
    private func checkSubscriptionAndShowPaywall() {
        // Check if user has active subscription
        let _: _Concurrency.Task<Void, Never> = _Concurrency.Task {
            await purchaseModel.checkSubscriptionStatus()
            
            DispatchQueue.main.async {
                if !self.purchaseModel.isSubscribed {
                    self.showPaywall = true
                }
                self.isSubscribed = self.purchaseModel.isSubscribed
            }
        }
    }
    
    func onboardingCompleted() {
        UserDefaults.standard.set(true, forKey: "OnboardingSeen")
        showOnboarding = false
        
        // After onboarding, check if we need to show paywall
        if !purchaseModel.isSubscribed {
            showPaywall = true
        }
    }
    
    func paywallDismissed() {
        showPaywall = false
        isSubscribed = purchaseModel.isSubscribed
    }
    
    func presentPaywall() {
        showPaywall = true
    }
    
    func analyticsNavigationHandled() {
        navigateToAnalytics = false
    }
    
    var purchaseManager: PurchaseModel {
        return purchaseModel
    }
}