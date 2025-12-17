import Foundation

// MARK: - JSON Structures
struct VehicleMakeDatabase: Codable {
    let makes: [VehicleMakeInfo]
}

struct VehicleMakeInfo: Codable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let models: [String]
}

// MARK: - Vehicle Database Service
class VehicleDatabaseService {
    static let shared = VehicleDatabaseService()
    
    private var database: VehicleMakeDatabase?
    
    private init() {
        loadDatabase()
    }
    
    // MARK: - Database Loading
    private func loadDatabase() {
        guard let url = Bundle.main.url(forResource: "vehicle_makes_models", withExtension: "json") else {
            print("❌ Could not find vehicle_makes_models.json")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            database = try JSONDecoder().decode(VehicleMakeDatabase.self, from: data)
            print("✅ Loaded \(database?.makes.count ?? 0) vehicle makes")
        } catch {
            print("❌ Error loading vehicle database: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Query Methods
    
    /// Get all available makes
    func getAllMakes() -> [String] {
        guard let database = database else { return [] }
        return database.makes.map { $0.name }.sorted()
    }
    
    /// Get models for a specific make
    func getModels(for make: String) -> [String] {
        guard let database = database else { return [] }
        return database.makes.first(where: { $0.name == make })?.models ?? []
    }
    
    /// Get available years (last 30 years + next year)
    func getAvailableYears() -> [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        let startYear = currentYear - 30
        let endYear = currentYear + 1
        return Array(startYear...endYear).reversed()
    }
    
    /// Check if make exists in database
    func makeExists(_ make: String) -> Bool {
        guard let database = database else { return false }
        return database.makes.contains(where: { $0.name.lowercased() == make.lowercased() })
    }
    
    /// Check if model exists for make
    func modelExists(_ model: String, for make: String) -> Bool {
        let models = getModels(for: make)
        return models.contains(where: { $0.lowercased() == model.lowercased() })
    }
}

