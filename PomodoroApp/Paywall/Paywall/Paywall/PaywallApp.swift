//
//  PaywallApp.swift
//  Paywall
//
//  Created by Abdalla Abdelmagid on 7/31/25.
//

import SwiftUI

@main
struct PaywallApp: App {
    @State private var showPaywall = true
    
    var body: some Scene {
        WindowGroup {
            PurchaseView(isPresented: $showPaywall)
        }
    }
}
