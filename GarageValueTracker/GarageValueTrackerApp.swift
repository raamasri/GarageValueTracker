import SwiftUI
import SwiftData

@main
struct GarageValueTrackerApp: App {
    let modelContainer: ModelContainer
    
    init() {
        do {
            // Configure persistent storage
            let schema = Schema([
                VehicleEntity.self,
                CostEntryEntity.self,
                ValuationSnapshotEntity.self,
                UserSettingsEntity.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,  // Persist to disk
                allowsSave: true
            )
            
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            // Initialize default settings if needed
            initializeDefaultSettings()
            
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Verify persistence on app launch
                    print("✅ App launched - SwiftData persistence active")
                    printStorageInfo()
                }
        }
        .modelContainer(modelContainer)
    }
    
    // Initialize default user settings on first launch
    private func initializeDefaultSettings() {
        let context = modelContainer.mainContext
        
        // Check if settings already exist
        let fetchDescriptor = FetchDescriptor<UserSettingsEntity>()
        if let settings = try? context.fetch(fetchDescriptor), !settings.isEmpty {
            print("✅ User settings found: \(settings.count) record(s)")
            return
        }
        
        // Create default settings for first launch
        let defaultSettings = UserSettingsEntity(
            hoursPerWeekActiveListing: 1.5,
            hoursPerTestDrive: 1.0,
            hoursPerPriceChange: 0.5,
            defaultZipCode: "",
            currencySymbol: "$"
        )
        
        context.insert(defaultSettings)
        
        do {
            try context.save()
            print("✅ Default user settings created and saved")
        } catch {
            print("❌ Failed to save default settings: \(error)")
        }
    }
    
    // Debug: Print storage information
    private func printStorageInfo() {
        let context = modelContainer.mainContext
        
        // Count vehicles
        let vehicleDescriptor = FetchDescriptor<VehicleEntity>()
        let vehicleCount = (try? context.fetch(vehicleDescriptor).count) ?? 0
        
        // Count costs
        let costDescriptor = FetchDescriptor<CostEntryEntity>()
        let costCount = (try? context.fetch(costDescriptor).count) ?? 0
        
        // Count snapshots
        let snapshotDescriptor = FetchDescriptor<ValuationSnapshotEntity>()
        let snapshotCount = (try? context.fetch(snapshotDescriptor).count) ?? 0
        
        print("""
        📊 SwiftData Storage:
        - Vehicles: \(vehicleCount)
        - Cost Entries: \(costCount)
        - Valuation Snapshots: \(snapshotCount)
        """)
    }
}
