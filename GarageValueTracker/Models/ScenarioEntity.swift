import Foundation
import CoreData

@objc(ScenarioEntity)
public class ScenarioEntity: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var vehicleID: UUID?
    @NSManaged public var name: String
    @NSManaged public var scenarioType: String
    @NSManaged public var parametersJSON: String
    @NSManaged public var resultJSON: String?
    @NSManaged public var createdAt: Date
}

extension ScenarioEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ScenarioEntity> {
        return NSFetchRequest<ScenarioEntity>(entityName: "ScenarioEntity")
    }
    
    convenience init(context: NSManagedObjectContext, vehicleID: UUID? = nil, name: String, type: ScenarioType, parameters: ScenarioParameters) {
        self.init(context: context)
        self.id = UUID()
        self.vehicleID = vehicleID
        self.name = name
        self.scenarioType = type.rawValue
        if let data = try? JSONEncoder().encode(parameters) {
            self.parametersJSON = data.base64EncodedString()
        } else {
            self.parametersJSON = ""
        }
        self.createdAt = Date()
    }
    
    var type: ScenarioType {
        ScenarioType(rawValue: scenarioType) ?? .hold
    }
    
    var parameters: ScenarioParameters? {
        guard let data = Data(base64Encoded: parametersJSON),
              let decoded = try? JSONDecoder().decode(ScenarioParameters.self, from: data) else {
            return nil
        }
        return decoded
    }
    
    var result: ScenarioResult? {
        guard let json = resultJSON,
              let data = Data(base64Encoded: json),
              let decoded = try? JSONDecoder().decode(ScenarioResult.self, from: data) else {
            return nil
        }
        return decoded
    }
    
    func saveResult(_ result: ScenarioResult) {
        if let data = try? JSONEncoder().encode(result) {
            resultJSON = data.base64EncodedString()
        }
    }
}

enum ScenarioType: String, CaseIterable {
    case bull = "bull"
    case bear = "bear"
    case hold = "hold"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .bull: return "Bull Case"
        case .bear: return "Bear Case"
        case .hold: return "Hold Scenario"
        case .custom: return "Custom"
        }
    }
    
    var icon: String {
        switch self {
        case .bull: return "arrow.up.right.circle"
        case .bear: return "arrow.down.right.circle"
        case .hold: return "arrow.right.circle"
        case .custom: return "slider.horizontal.3"
        }
    }
}

struct ScenarioParameters: Codable {
    var yearsToProject: Int
    var annualAppreciationRate: Double?
    var annualDepreciationRate: Double?
    var annualMileage: Int
    var annualMaintenanceCost: Double
    var annualInsuranceCost: Double
}

struct ScenarioResult: Codable {
    let projectedValues: [ScenarioProjectedValue]
    let totalCostOfOwnership: Double
    let netEquityChange: Double
    let annualizedReturn: Double
}

struct ScenarioProjectedValue: Codable, Identifiable {
    var id: Int { year }
    let year: Int
    let projectedValue: Double
    let cumulativeCosts: Double
    let netEquity: Double
}
