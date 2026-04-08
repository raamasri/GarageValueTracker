import Foundation
import CoreData

@objc(DealAnalysisEntity)
public class DealAnalysisEntity: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var vehicleID: UUID?
    @NSManaged public var overallScore: Int16 // 0-100
    @NSManaged public var priceScore: Int16
    @NSManaged public var mileageScore: Int16
    @NSManaged public var conditionScore: Int16
    @NSManaged public var marketScore: Int16
    @NSManaged public var insights: String? // JSON encoded array
    @NSManaged public var recommendation: String?
    @NSManaged public var location: String?
    @NSManaged public var hasAccidentHistory: Bool
    @NSManaged public var createdAt: Date
}

extension DealAnalysisEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DealAnalysisEntity> {
        return NSFetchRequest<DealAnalysisEntity>(entityName: "DealAnalysisEntity")
    }
    
    convenience init(context: NSManagedObjectContext,
                     vehicleID: UUID? = nil,
                     overallScore: Int,
                     priceScore: Int,
                     mileageScore: Int,
                     conditionScore: Int,
                     marketScore: Int,
                     insights: [String],
                     recommendation: String,
                     location: String? = nil,
                     hasAccidentHistory: Bool = false) {
        self.init(context: context)
        self.id = UUID()
        self.vehicleID = vehicleID
        self.overallScore = Int16(overallScore)
        self.priceScore = Int16(priceScore)
        self.mileageScore = Int16(mileageScore)
        self.conditionScore = Int16(conditionScore)
        self.marketScore = Int16(marketScore)
        self.insights = try? JSONEncoder().encode(insights).base64EncodedString()
        self.recommendation = recommendation
        self.location = location
        self.hasAccidentHistory = hasAccidentHistory
        self.createdAt = Date()
    }
    
    var insightsList: [String] {
        guard let insights = insights,
              let data = Data(base64Encoded: insights),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return decoded
    }
    
    var grade: DealGrade {
        switch overallScore {
        case 90...100: return .excellent
        case 75..<90: return .good
        case 60..<75: return .fair
        case 40..<60: return .belowAverage
        default: return .poor
        }
    }
    
    var gradeColor: String {
        switch grade {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "yellow"
        case .belowAverage: return "orange"
        case .poor: return "red"
        }
    }
}

// Deal Grade Enum
enum DealGrade: String {
    case excellent = "Excellent Deal"
    case good = "Good Deal"
    case fair = "Fair Deal"
    case belowAverage = "Below Average"
    case poor = "Poor Deal"
    
    var emoji: String {
        switch self {
        case .excellent: return "🎉"
        case .good: return "✅"
        case .fair: return "👍"
        case .belowAverage: return "⚠️"
        case .poor: return "❌"
        }
    }
}

// Deal Analysis Result (for calculations)
struct DealAnalysisResult {
    let overallScore: Int
    let priceScore: Int
    let mileageScore: Int
    let conditionScore: Int
    let marketScore: Int
    let insights: [String]
    let recommendation: String
    let grade: DealGrade
    
    let askingPrice: Double
    let priceDifference: Double
    let expectedMileage: Int
    let mileageDifference: Int
    let accidentImpact: Double?
    let locationAdjustment: Double?
    
    var fairValueLow: Double?
    var fairValueMid: Double?
    var fairValueHigh: Double?
    var verdict: DealVerdict?
    var daysOnMarketEstimate: ClosedRange<Int>?
    var regionalContext: String?
    var syntheticComps: [SyntheticComp]?
    var segment: String?
    var confidence: Double?
}

enum DealVerdict: String {
    case underpriced = "UNDERPRICED"
    case fair = "FAIR"
    case rich = "RICH"
    
    var color: String {
        switch self {
        case .underpriced: return "green"
        case .fair: return "blue"
        case .rich: return "red"
        }
    }
}

