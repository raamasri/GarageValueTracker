import Foundation
import CoreData

@objc(VehicleEntity)
public class VehicleEntity: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var make: String
    @NSManaged public var model: String
    @NSManaged public var year: Int16
    @NSManaged public var trim: String?
    @NSManaged public var selectedTrimID: UUID?
    @NSManaged public var trimMSRP: Double
    @NSManaged public var vin: String?
    @NSManaged public var mileage: Int32
    @NSManaged public var purchasePrice: Double
    @NSManaged public var purchaseDate: Date
    @NSManaged public var currentValue: Double
    @NSManaged public var lastValuationUpdate: Date?
    @NSManaged public var imageData: Data?
    @NSManaged public var notes: String?
    @NSManaged public var location: String?
    @NSManaged public var hasAccidentHistory: Bool
    @NSManaged public var accidentDetails: String? // JSON encoded
    @NSManaged public var accidentValueImpact: Double
    @NSManaged public var insuranceProvider: String?
    @NSManaged public var insurancePremium: Double
    @NSManaged public var insuranceRenewalDate: Date?
    @NSManaged public var coverageLevel: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
}

extension VehicleEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<VehicleEntity> {
        return NSFetchRequest<VehicleEntity>(entityName: "VehicleEntity")
    }
    
    convenience init(context: NSManagedObjectContext,
                     make: String,
                     model: String,
                     year: Int,
                     trim: String? = nil,
                     vin: String? = nil,
                     mileage: Int = 0,
                     purchasePrice: Double,
                     purchaseDate: Date = Date()) {
        self.init(context: context)
        self.id = UUID()
        self.make = make
        self.model = model
        self.year = Int16(year)
        self.trim = trim
        self.vin = vin
        self.mileage = Int32(mileage)
        self.purchasePrice = purchasePrice
        self.purchaseDate = purchaseDate
        self.currentValue = purchasePrice
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var displayName: String {
        var name = "\(year) \(make) \(model)"
        if let trim = trim {
            name += " \(trim)"
        }
        return name
    }
    
    var accidentRecords: [AccidentRecord] {
        guard let details = accidentDetails,
              let data = Data(base64Encoded: details),
              let decoded = try? JSONDecoder().decode([AccidentRecord].self, from: data) else {
            return []
        }
        return decoded
    }
    
    func addAccident(_ accident: AccidentRecord) {
        var accidents = accidentRecords
        accidents.append(accident)
        
        if let encoded = try? JSONEncoder().encode(accidents) {
            accidentDetails = encoded.base64EncodedString()
            hasAccidentHistory = true
            updatedAt = Date()
        }
    }
    
    func calculateAccidentImpact() -> Double {
        guard hasAccidentHistory else { return 0.0 }
        
        let accidents = accidentRecords
        var totalImpact: Double = 0.0
        
        for accident in accidents {
            let impact: Double
            switch accident.severity {
            case .minor:
                impact = currentValue * 0.075 // 7.5% average
            case .moderate:
                impact = currentValue * 0.15 // 15% average
            case .major:
                impact = currentValue * 0.25 // 25% average
            case .structural:
                impact = currentValue * 0.35 // 35% average
            }
            totalImpact += impact
        }
        
        // Cap maximum impact at 50% of value
        return min(totalImpact, currentValue * 0.5)
    }
}

// Accident Record Structure
struct AccidentRecord: Codable {
    let date: Date
    let severity: AccidentSeverity
    let damageType: String
    let repairCost: Double?
    let notes: String?
    
    enum AccidentSeverity: String, Codable {
        case minor = "Minor"
        case moderate = "Moderate"
        case major = "Major"
        case structural = "Structural"
        
        var depreciationPercent: Double {
            switch self {
            case .minor: return 0.075
            case .moderate: return 0.15
            case .major: return 0.25
            case .structural: return 0.35
            }
        }
    }
}
