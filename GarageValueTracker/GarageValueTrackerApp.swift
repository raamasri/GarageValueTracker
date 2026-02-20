import SwiftUI
import CoreData
import UserNotifications

@main
struct GarageValueTrackerApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var settingsManager = AppSettingsManager.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(settingsManager)
                .preferredColorScheme(settingsManager.colorScheme)
                .tint(settingsManager.accentColor.color)
                .onAppear {
                    NotificationService.shared.requestPermission { _ in }
                    scheduleAllVehicleNotifications()
                }
        }
    }
    
    private func scheduleAllVehicleNotifications() {
        let context = persistenceController.container.viewContext
        let request = VehicleEntity.fetchRequest()
        
        do {
            let vehicles = try context.fetch(request)
            for vehicle in vehicles {
                NotificationService.shared.scheduleAllReminders(for: vehicle, context: context)
            }
        } catch {
            print("Error scheduling notifications: \(error)")
        }
    }
}
