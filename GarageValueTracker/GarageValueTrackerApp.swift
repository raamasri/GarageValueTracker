import SwiftUI
import CoreData

@main
struct GarageValueTrackerApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var settingsManager = AppSettingsManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(settingsManager)
                .preferredColorScheme(settingsManager.colorScheme)
                .tint(settingsManager.accentColor.color)
        }
    }
}
