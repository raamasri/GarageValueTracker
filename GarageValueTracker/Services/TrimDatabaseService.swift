import Foundation
import CoreData

// MARK: - JSON Structures
struct TrimData: Codable, Hashable {
    let make: String
    let model: String
    let year: Int
    let trimLevel: String
    let msrp: Double
    let features: [String]
}

struct TrimDatabase: Codable {
    let trims: [TrimData]
}

// MARK: - Trim Database Service
class TrimDatabaseService {
    static let shared = TrimDatabaseService()
    
    private var trimDatabase: TrimDatabase?
    private let context: NSManagedObjectContext
    
    private init() {
        self.context = PersistenceController.shared.container.viewContext
        loadDatabase()
    }
    
    // MARK: - Database Loading
    private func loadDatabase() {
        guard let url = Bundle.main.url(forResource: "trim_database", withExtension: "json") else {
            print("❌ Could not find trim_database.json")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            trimDatabase = try JSONDecoder().decode(TrimDatabase.self, from: data)
            print("✅ Loaded \(trimDatabase?.trims.count ?? 0) trim configurations")
        } catch {
            print("❌ Error loading trim database: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Query Methods
    
    /// Get all available trims for a specific vehicle
    func getTrims(make: String, model: String, year: Int) -> [TrimData] {
        guard let database = trimDatabase else { return [] }
        
        return database.trims.filter {
            $0.make.lowercased() == make.lowercased() &&
            $0.model.lowercased() == model.lowercased() &&
            $0.year == year
        }.sorted { $0.msrp < $1.msrp }
    }
    
    /// Get a specific trim by exact match
    func getTrim(make: String, model: String, year: Int, trimLevel: String) -> TrimData? {
        guard let database = trimDatabase else { return nil }
        
        return database.trims.first {
            $0.make.lowercased() == make.lowercased() &&
            $0.model.lowercased() == model.lowercased() &&
            $0.year == year &&
            $0.trimLevel.lowercased() == trimLevel.lowercased()
        }
    }
    
    /// Check if trim data exists for a vehicle
    func hasTrimsAvailable(make: String, model: String, year: Int) -> Bool {
        return !getTrims(make: make, model: model, year: year).isEmpty
    }
    
    /// Get all unique makes in database
    func getAllMakes() -> [String] {
        guard let database = trimDatabase else { return [] }
        let makes = Set(database.trims.map { $0.make })
        return Array(makes).sorted()
    }
    
    /// Get all models for a make
    func getModels(for make: String) -> [String] {
        guard let database = trimDatabase else { return [] }
        let models = Set(database.trims.filter { $0.make.lowercased() == make.lowercased() }.map { $0.model })
        return Array(models).sorted()
    }
    
    /// Get available years for a make/model
    func getYears(make: String, model: String) -> [Int] {
        guard let database = trimDatabase else { return [] }
        let years = Set(database.trims.filter {
            $0.make.lowercased() == make.lowercased() &&
            $0.model.lowercased() == model.lowercased()
        }.map { $0.year })
        return Array(years).sorted(by: >)
    }
    
    // MARK: - CoreData Integration
    
    /// Save or update a trim in CoreData
    @discardableResult
    func saveTrimToDatabase(trimData: TrimData) -> TrimEntity? {
        // Check if trim already exists
        let fetchRequest: NSFetchRequest<TrimEntity> = TrimEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "make == %@ AND model == %@ AND year == %d AND trimLevel == %@",
            trimData.make, trimData.model, trimData.year, trimData.trimLevel
        )
        
        do {
            let results = try context.fetch(fetchRequest)
            
            let trim: TrimEntity
            if let existingTrim = results.first {
                // Update existing
                trim = existingTrim
                trim.updatedAt = Date()
            } else {
                // Create new
                trim = TrimEntity(
                    context: context,
                    make: trimData.make,
                    model: trimData.model,
                    year: trimData.year,
                    trimLevel: trimData.trimLevel,
                    msrp: trimData.msrp,
                    features: trimData.features
                )
            }
            
            trim.msrp = trimData.msrp
            trim.features = try? JSONEncoder().encode(trimData.features).base64EncodedString()
            
            try context.save()
            return trim
        } catch {
            print("❌ Error saving trim: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Get or create TrimEntity from TrimData
    func getOrCreateTrimEntity(from trimData: TrimData) -> TrimEntity? {
        // First check if it exists in CoreData
        let fetchRequest: NSFetchRequest<TrimEntity> = TrimEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "make == %@ AND model == %@ AND year == %d AND trimLevel == %@",
            trimData.make, trimData.model, trimData.year, trimData.trimLevel
        )
        
        do {
            let results = try context.fetch(fetchRequest)
            if let existingTrim = results.first {
                return existingTrim
            }
            
            // Create new if doesn't exist
            return saveTrimToDatabase(trimData: trimData)
        } catch {
            print("❌ Error fetching trim: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Trim Comparison
extension TrimDatabaseService {
    /// Compare two trims and get the differences
    func compareTrims(_ trim1: TrimData, with trim2: TrimData) -> TrimComparison {
        let priceDiff = trim2.msrp - trim1.msrp
        let features1Set = Set(trim1.features)
        let features2Set = Set(trim2.features)
        
        let addedFeatures = Array(features2Set.subtracting(features1Set))
        let removedFeatures = Array(features1Set.subtracting(features2Set))
        
        return TrimComparison(
            baseTrim: trim1,
            comparedTrim: trim2,
            priceDifference: priceDiff,
            addedFeatures: addedFeatures,
            removedFeatures: removedFeatures
        )
    }
}

// MARK: - Trim Comparison Result
struct TrimComparison {
    let baseTrim: TrimData
    let comparedTrim: TrimData
    let priceDifference: Double
    let addedFeatures: [String]
    let removedFeatures: [String]
    
    var formattedPriceDifference: String {
        let sign = priceDifference >= 0 ? "+" : ""
        return String(format: "%@$%.0f", sign, abs(priceDifference))
    }
    
    var summary: String {
        if priceDifference > 0 {
            return "\(comparedTrim.trimLevel) adds \(formattedPriceDifference)"
        } else if priceDifference < 0 {
            return "\(comparedTrim.trimLevel) saves \(formattedPriceDifference)"
        } else {
            return "Same price"
        }
    }
}

