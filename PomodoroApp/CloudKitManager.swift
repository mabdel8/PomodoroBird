//
//  CloudKitManager.swift
//  PomodoroApp
//
//  Created by Claude Code on 1/31/25.
//

import Foundation
import SwiftData
import CloudKit

class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()
    
    @Published var isCloudKitEnabled: Bool = false
    @Published var cloudKitAccountStatus: CKAccountStatus = .couldNotDetermine
    @Published var isCloudKitAvailable: Bool = false
    
    private let container = CKContainer.default()
    
    private init() {
        print("🚀 CloudKitManager initializing...")
        loadSettings()
        checkCloudKitAvailability()
        print("✅ CloudKitManager initialized - CloudKit enabled: \(isCloudKitEnabled)")
    }
    
    // MARK: - CloudKit Availability
    
    func checkCloudKitAvailability() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                self?.cloudKitAccountStatus = status
                self?.isCloudKitAvailable = (status == .available)
                
                if let error = error {
                    print("❌ CloudKit account error: \(error.localizedDescription)")
                } else {
                    print("☁️ CloudKit account status: \(status.description)")
                }
            }
        }
    }
    
    // MARK: - Settings Management
    
    private func loadSettings() {
        // CRITICAL: Default to false - user must explicitly enable CloudKit
        // UserDefaults.bool returns false if key doesn't exist, which is what we want
        let userSetting = UserDefaults.standard.object(forKey: "isCloudKitEnabled")
        
        if userSetting == nil {
            // Key doesn't exist - this is a fresh install or first launch
            isCloudKitEnabled = false
            print("🔒 Fresh install - CloudKit disabled by default")
            // Explicitly save the false value
            UserDefaults.standard.set(false, forKey: "isCloudKitEnabled")
        } else {
            // Key exists - use stored value
            isCloudKitEnabled = UserDefaults.standard.bool(forKey: "isCloudKitEnabled")
            print("📱 CloudKit setting from storage: \(isCloudKitEnabled)")
        }
        
        print("🎯 FINAL CloudKit state: \(isCloudKitEnabled)")
    }
    
    func saveSettings() {
        UserDefaults.standard.set(isCloudKitEnabled, forKey: "isCloudKitEnabled")
        UserDefaults.standard.synchronize() // Force immediate save
        print("💾 CloudKit settings saved: enabled = \(isCloudKitEnabled)")
        print("🔍 Verification - stored value: \(UserDefaults.standard.bool(forKey: "isCloudKitEnabled"))")
    }
    
    func toggleCloudKit() {
        let oldValue = isCloudKitEnabled
        isCloudKitEnabled.toggle()
        
        print("🔀 User toggled CloudKit: \(oldValue) → \(isCloudKitEnabled)")
        
        saveSettings()
        
        // Clear cached container to force recreation with new settings
        _modelContainer = nil
        print("🔄 Container cache cleared - restart required for changes to take effect")
    }
    
    func forceDisableCloudKit() {
        if isCloudKitEnabled {
            print("🚨 FORCING CloudKit disable - was incorrectly enabled")
            isCloudKitEnabled = false
            saveSettings()
            _modelContainer = nil
        }
    }
    
    // MARK: - ModelContainer Creation
    
    private var _modelContainer: ModelContainer?
    
    var modelContainer: ModelContainer {
        if let existingContainer = _modelContainer {
            return existingContainer
        }
        
        let container = createModelContainer()
        _modelContainer = container
        return container
    }
    
    private func createModelContainer() -> ModelContainer {
        let schema = Schema([
            FocusTag.self,
            Task.self,
            FocusSession.self,
            AppTimerState.self,
            CollectedBird.self,
        ])
        
        // CRITICAL PRIVACY CHECK: Never allow CloudKit without explicit user consent
        print("🔒 PRIVACY CHECK - CloudKit enabled: \(isCloudKitEnabled), Available: \(isCloudKitAvailable)")
        
        // Force disable CloudKit - NEVER automatically enable
        // This is a known SwiftData bug where it auto-enables CloudKit
        forceDisableCloudKit()
        
        // Always use local storage to protect user privacy
        print("📱 PRIVACY MODE: Creating local-only ModelContainer (CloudKit disabled)")
        return createLocalContainer(schema: schema)
        
        /* CloudKit completely disabled for privacy
        if isCloudKitEnabled && isCloudKitAvailable {
            print("☁️ User enabled CloudKit - Creating CloudKit ModelContainer...")
            
            let cloudKitConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.com.pomodoroapp.PomodoroApp")
            )
            
            do {
                let container = try ModelContainer(for: schema, configurations: [cloudKitConfiguration])
                print("☁️ Created CloudKit ModelContainer successfully")
                return container
            } catch {
                print("❌ Failed to create CloudKit ModelContainer: \(error)")
                print("❌ CloudKit error details: \(error.localizedDescription)")
                print("🔄 Falling back to local storage...")
                // Fallback to local storage
                return createLocalContainer(schema: schema)
            }
        } else {
            // Local storage only (default behavior)
            if !isCloudKitEnabled {
                print("📱 CloudKit disabled by user - Creating local ModelContainer...")
            } else {
                print("📱 CloudKit not available - Creating local ModelContainer...")
            }
            return createLocalContainer(schema: schema)
        }
        */
    }
    
    private func createLocalContainer(schema: Schema) -> ModelContainer {
        // Create completely local-only configuration - NO iCloud interaction
        let localConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
            let container = try ModelContainer(for: schema, configurations: [localConfiguration])
            print("📱 Created local ModelContainer successfully")
            return container
        } catch {
            print("❌ Error creating local ModelContainer: \(error)")
            print("❌ Detailed error: \(error.localizedDescription)")
            
            // Try in-memory as fallback
            print("🔄 Attempting in-memory fallback...")
            let memoryConfiguration = ModelConfiguration(
                schema: schema, 
                isStoredInMemoryOnly: true
            )
            
            do {
                let container = try ModelContainer(for: schema, configurations: [memoryConfiguration])
                print("🧠 Created in-memory ModelContainer successfully")
                return container
            } catch {
                print("❌ Fatal: Even in-memory container failed: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                
                // Print model info for debugging
                print("🔍 Schema contains models:")
                for model in schema.entities {
                    print("  - \(model.name)")
                }
                
                fatalError("Could not create any ModelContainer. This indicates a fundamental SwiftData model issue: \(error)")
            }
        }
    }
    
    // MARK: - Manual Sync
    
    func triggerManualSync() async {
        guard isCloudKitEnabled && isCloudKitAvailable else {
            print("⚠️ CloudKit sync not available")
            return
        }
        
        // CloudKit sync is automatic, but we can check connectivity
        do {
            let database = container.privateCloudDatabase
            _ = try await database.save(CKRecord(recordType: "SyncTest"))
            print("☁️ Manual sync check completed successfully")
        } catch {
            print("❌ Manual sync failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Extensions

extension CKAccountStatus {
    var description: String {
        switch self {
        case .available:
            return "Available"
        case .couldNotDetermine:
            return "Could not determine"
        case .noAccount:
            return "No iCloud account"
        case .restricted:
            return "Restricted"
        case .temporarilyUnavailable:
            return "Temporarily unavailable"
        @unknown default:
            return "Unknown"
        }
    }
}