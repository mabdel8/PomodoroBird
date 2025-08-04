// PurchaseModel SwiftUI
// Created by Abdalla Abdelmagid on 7/31/2025

// Make cool stuff and share your build with me:

//  --> x.com/adamlyttleapps
//  --> github.com/adamlyttleapps

import Foundation
import StoreKit

// Type alias to disambiguate between SwiftData Task model and Swift concurrency Task
typealias ConcurrencyTask<Success, Failure: Error> = _Concurrency.Task<Success, Failure>

class PurchaseModel: ObservableObject {
    
    @Published var productIds: [String]
    @Published var productDetails: [PurchaseProductDetails] = []
    @Published var products: [Product] = []

    @Published var isSubscribed: Bool = false
    @Published var isPurchasing: Bool = false
    @Published var isFetchingProducts: Bool = false
    
    private var updateListenerTask: ConcurrencyTask<Void, Error>? = nil
    
    init() {
        // Initialize with actual StoreKit product IDs
        self.productIds = ["lifetimeplan", "weekly_399"]
        self.productDetails = [
            PurchaseProductDetails(price: "Loading...", productId: "lifetimeplan", duration: "lifetime", durationPlanName: "Lifetime Plan", hasTrial: false),
            PurchaseProductDetails(price: "Loading...", productId: "weekly_399", duration: "week", durationPlanName: "3-Day Trial", hasTrial: true)
        ]
        
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()
        
        ConcurrencyTask {
            await fetchProducts()
            await checkSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    @MainActor
    func fetchProducts() async {
        isFetchingProducts = true
        
        do {
            products = try await Product.products(for: productIds)
            
            // Update product details with actual prices
            var updatedDetails: [PurchaseProductDetails] = []
            
            for product in products {
                let hasTrial = product.id == "weekly_399"
                let duration = product.id == "lifetimeplan" ? "lifetime" : "week"
                let planName = product.id == "lifetimeplan" ? "Lifetime Plan" : "3-Day Trial"
                
                updatedDetails.append(PurchaseProductDetails(
                    price: product.displayPrice,
                    productId: product.id,
                    duration: duration,
                    durationPlanName: planName,
                    hasTrial: hasTrial
                ))
            }
            
            productDetails = updatedDetails
            isFetchingProducts = false
            
        } catch {
            print("Failed to fetch products: \(error)")
            isFetchingProducts = false
        }
    }
    
    func purchaseSubscription(productId: String) {
        ConcurrencyTask {
            await purchase(productId: productId)
        }
    }
    
    @MainActor
    private func purchase(productId: String) async {
        guard let product = products.first(where: { $0.id == productId }) else {
            print("Product not found: \(productId)")
            return
        }
        
        isPurchasing = true
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updateSubscriptionStatus()
                await transaction.finish()
                
            case .userCancelled:
                print("User cancelled the purchase")
                
            case .pending:
                print("Purchase is pending")
                
            @unknown default:
                print("Unknown purchase result")
            }
        } catch {
            print("Purchase failed: \(error)")
        }
        
        isPurchasing = false
    }
    
    func restorePurchases() {
        ConcurrencyTask {
            await restoreTransactions()
        }
    }
    
    @MainActor
    private func restoreTransactions() async {
        try? await AppStore.sync()
        await checkSubscriptionStatus()
    }
    
    @MainActor
    func checkSubscriptionStatus() async {
        var hasActiveSubscription = false
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if transaction.productID == "lifetimeplan" {
                    hasActiveSubscription = true
                    break
                } else if transaction.productID == "weekly_399" {
                    // Check if subscription is still active
                    if let subscriptionStatus = try await transaction.subscriptionStatus {
                        switch subscriptionStatus.state {
                        case .subscribed, .inGracePeriod, .inBillingRetryPeriod:
                            hasActiveSubscription = true
                        default:
                            break
                        }
                    }
                }
            } catch {
                print("Error checking transaction: \(error)")
            }
        }
        
        isSubscribed = hasActiveSubscription
    }
    
    @MainActor
    private func updateSubscriptionStatus() async {
        await checkSubscriptionStatus()
    }
    
    private func listenForTransactions() -> ConcurrencyTask<Void, Error> {
        return ConcurrencyTask.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updateSubscriptionStatus()
                    await transaction.finish()
                } catch {
                    print("Transaction failed verification: \(error)")
                }
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

enum StoreError: Error {
    case failedVerification
}

// Extension to add subscriptionStatus to Transaction
extension Transaction {
    var subscriptionStatus: Product.SubscriptionInfo.Status? {
        get async throws {
            guard let product = try await Product.products(for: [self.productID]).first,
                  let subscription = product.subscription else {
                return nil
            }
            
            let statuses = try await subscription.status
            return statuses.first
        }
    }
}

class PurchaseProductDetails: ObservableObject, Identifiable {
    let id: UUID
    
    @Published var price: String
    @Published var productId: String
    @Published var duration: String
    @Published var durationPlanName: String
    @Published var hasTrial: Bool
    
    init(price: String = "", productId: String = "", duration: String = "", durationPlanName: String = "", hasTrial: Bool = false) {
        self.id = UUID()
        self.price = price
        self.productId = productId
        self.duration = duration
        self.durationPlanName = durationPlanName
        self.hasTrial = hasTrial
    }
}

