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
    
    private let purchaseModel = PurchaseModel()
    
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
            .assign(to: &$isSubscribed)
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
    
    var purchaseManager: PurchaseModel {
        return purchaseModel
    }
}