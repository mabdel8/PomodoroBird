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
        loadSettings()
        checkCloudKitAvailability()
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
        isCloudKitEnabled = UserDefaults.standard.bool(forKey: "isCloudKitEnabled")
    }
    
    func saveSettings() {
        UserDefaults.standard.set(isCloudKitEnabled, forKey: "isCloudKitEnabled")
        print("☁️ CloudKit settings saved: enabled = \(isCloudKitEnabled)")
    }
    
    func toggleCloudKit() {
        isCloudKitEnabled.toggle()
        saveSettings()
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
        
        if isCloudKitEnabled && isCloudKitAvailable {
            print("☁️ Creating CloudKit ModelContainer...")
            // CloudKit configuration
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
                // Fallback to local storage
                return createLocalContainer(schema: schema)
            }
        } else {
            // Local storage only
            print("📱 Creating local ModelContainer...")
            return createLocalContainer(schema: schema)
        }
    }
    
    private func createLocalContainer(schema: Schema) -> ModelContainer {
        // Try local storage first
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