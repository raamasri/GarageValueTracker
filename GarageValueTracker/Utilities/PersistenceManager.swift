import SwiftUI
import SwiftData

/// Manages local app storage and data persistence
/// Ensures all user data (vehicles, costs, settings) persists across app launches
class PersistenceManager {
    static let shared = PersistenceManager()
    
    private init() {}
    
    // MARK: - Vehicle Management
    
    /// Save a vehicle to persistent storage
    func saveVehicle(_ vehicle: VehicleEntity, context: ModelContext) {
        context.insert(vehicle)
        saveContext(context, type: "Vehicle")
    }
    
    /// Delete a vehicle and all related data (cascade)
    func deleteVehicle(_ vehicle: VehicleEntity, context: ModelContext) {
        context.delete(vehicle)
        saveContext(context, type: "Vehicle")
    }
    
    /// Fetch all owned vehicles
    func fetchOwnedVehicles(context: ModelContext) -> [VehicleEntity] {
        let descriptor = FetchDescriptor<VehicleEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor).filter { $0.ownershipType == .owned }) ?? []
    }
    
    /// Fetch all watchlist vehicles
    func fetchWatchlistVehicles(context: ModelContext) -> [VehicleEntity] {
        let descriptor = FetchDescriptor<VehicleEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor).filter { $0.ownershipType == .watchlist }) ?? []
    }
    
    // MARK: - Cost Entry Management
    
    /// Save a cost entry
    func saveCostEntry(_ cost: CostEntryEntity, context: ModelContext) {
        context.insert(cost)
        saveContext(context, type: "Cost Entry")
    }
    
    /// Delete a cost entry
    func deleteCostEntry(_ cost: CostEntryEntity, context: ModelContext) {
        context.delete(cost)
        saveContext(context, type: "Cost Entry")
    }
    
    // MARK: - Valuation Snapshot Management
    
    /// Save a valuation snapshot
    func saveValuationSnapshot(_ snapshot: ValuationSnapshotEntity, context: ModelContext) {
        context.insert(snapshot)
        saveContext(context, type: "Valuation Snapshot")
    }
    
    /// Fetch valuation history for a vehicle
    func fetchValuationHistory(for vehicle: VehicleEntity, context: ModelContext) -> [ValuationSnapshotEntity] {
        let descriptor = FetchDescriptor<ValuationSnapshotEntity>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? context.fetch(descriptor).filter { $0.vehicle?.id == vehicle.id }) ?? []
    }
    
    // MARK: - User Settings Management
    
    /// Get user settings (creates default if none exist)
    func getUserSettings(context: ModelContext) -> UserSettingsEntity {
        let descriptor = FetchDescriptor<UserSettingsEntity>()
        
        if let settings = try? context.fetch(descriptor).first {
            return settings
        }
        
        // Create default settings
        let defaultSettings = UserSettingsEntity()
        context.insert(defaultSettings)
        saveContext(context, type: "User Settings")
        return defaultSettings
    }
    
    /// Update user settings
    func updateUserSettings(_ settings: UserSettingsEntity, context: ModelContext) {
        saveContext(context, type: "User Settings")
    }
    
    // MARK: - Data Export/Import
    
    /// Get storage statistics
    func getStorageStats(context: ModelContext) -> StorageStats {
        let vehicles = (try? context.fetch(FetchDescriptor<VehicleEntity>())) ?? []
        let costs = (try? context.fetch(FetchDescriptor<CostEntryEntity>())) ?? []
        let snapshots = (try? context.fetch(FetchDescriptor<ValuationSnapshotEntity>())) ?? []
        
        let ownedVehicles = vehicles.filter { $0.ownershipType == .owned }
        let watchlistVehicles = vehicles.filter { $0.ownershipType == .watchlist }
        
        let totalCosts = costs.reduce(0.0) { $0 + $1.amount }
        
        return StorageStats(
            totalVehicles: vehicles.count,
            ownedVehicles: ownedVehicles.count,
            watchlistVehicles: watchlistVehicles.count,
            totalCostEntries: costs.count,
            totalCostAmount: totalCosts,
            valuationSnapshots: snapshots.count,
            oldestVehicleDate: vehicles.map(\.createdAt).min(),
            lastModifiedDate: Date()
        )
    }
    
    /// Clear all data (use with caution - for testing/reset)
    func clearAllData(context: ModelContext) {
        // Delete all vehicles (cascade will handle related data)
        let vehicles = (try? context.fetch(FetchDescriptor<VehicleEntity>())) ?? []
        vehicles.forEach { context.delete($0) }
        
        // Delete orphaned cost entries (shouldn't exist due to cascade)
        let costs = (try? context.fetch(FetchDescriptor<CostEntryEntity>())) ?? []
        costs.forEach { context.delete($0) }
        
        // Delete orphaned snapshots
        let snapshots = (try? context.fetch(FetchDescriptor<ValuationSnapshotEntity>())) ?? []
        snapshots.forEach { context.delete($0) }
        
        // Don't delete settings - keep user preferences
        
        saveContext(context, type: "Clear All Data")
    }
    
    // MARK: - Private Helpers
    
    private func saveContext(_ context: ModelContext, type: String) {
        do {
            try context.save()
            print("✅ \(type) saved to persistent storage")
        } catch {
            print("❌ Failed to save \(type): \(error.localizedDescription)")
        }
    }
}

// MARK: - Storage Statistics

struct StorageStats {
    let totalVehicles: Int
    let ownedVehicles: Int
    let watchlistVehicles: Int
    let totalCostEntries: Int
    let totalCostAmount: Double
    let valuationSnapshots: Int
    let oldestVehicleDate: Date?
    let lastModifiedDate: Date
    
    var summary: String {
        """
        📊 Storage Summary:
        - Total Vehicles: \(totalVehicles) (Owned: \(ownedVehicles), Watchlist: \(watchlistVehicles))
        - Cost Entries: \(totalCostEntries) (Total: $\(String(format: "%.2f", totalCostAmount)))
        - Valuation Snapshots: \(valuationSnapshots)
        - Data Since: \(oldestVehicleDate?.formatted(date: .abbreviated, time: .omitted) ?? "N/A")
        - Last Modified: \(lastModifiedDate.formatted(date: .abbreviated, time: .shortened))
        """
    }
}

// MARK: - UserDefaults for Simple Preferences

/// Manages simple app preferences that don't need SwiftData
class AppPreferences {
    static let shared = AppPreferences()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let lastLaunchDate = "lastLaunchDate"
        static let launchCount = "launchCount"
        static let preferredTheme = "preferredTheme"
        static let notificationsEnabled = "notificationsEnabled"
    }
    
    // MARK: - Onboarding
    
    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Keys.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Keys.hasCompletedOnboarding) }
    }
    
    // MARK: - App Usage Tracking
    
    var lastLaunchDate: Date? {
        get { defaults.object(forKey: Keys.lastLaunchDate) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastLaunchDate) }
    }
    
    var launchCount: Int {
        get { defaults.integer(forKey: Keys.launchCount) }
        set { defaults.set(newValue, forKey: Keys.launchCount) }
    }
    
    func recordLaunch() {
        lastLaunchDate = Date()
        launchCount += 1
    }
    
    // MARK: - App Preferences
    
    var notificationsEnabled: Bool {
        get { defaults.bool(forKey: Keys.notificationsEnabled) }
        set { defaults.set(newValue, forKey: Keys.notificationsEnabled) }
    }
    
    // MARK: - Reset
    
    func resetAllPreferences() {
        let domain = Bundle.main.bundleIdentifier!
        defaults.removePersistentDomain(forName: domain)
        defaults.synchronize()
    }
}

