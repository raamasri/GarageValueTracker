import SwiftUI
import SwiftData

@main
struct GarageValueTrackerApp: App {
    let modelContainer: ModelContainer
    
    init() {
        do {
            modelContainer = try ModelContainer(for: 
                VehicleEntity.self,
                CostEntryEntity.self,
                ValuationSnapshotEntity.self,
                UserSettingsEntity.self
            )
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}



