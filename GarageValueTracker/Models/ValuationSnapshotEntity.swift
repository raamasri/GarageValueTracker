import Foundation
import SwiftData

@Model
final class ValuationSnapshotEntity {
    var id: UUID
    var date: Date
    var low: Double
    var mid: Double
    var high: Double
    var confidence: ConfidenceLevel
    var sampleSize: Int
    var momentum90d: Double?
    var liquidityScore: Double?
    var recommendation: Recommendation?
    var vehicle: VehicleEntity?
    
    init(
        id: UUID = UUID(),
        date: Date,
        low: Double,
        mid: Double,
        high: Double,
        confidence: ConfidenceLevel,
        sampleSize: Int,
        momentum90d: Double? = nil,
        liquidityScore: Double? = nil,
        recommendation: Recommendation? = nil
    ) {
        self.id = id
        self.date = date
        self.low = low
        self.mid = mid
        self.high = high
        self.confidence = confidence
        self.sampleSize = sampleSize
        self.momentum90d = momentum90d
        self.liquidityScore = liquidityScore
        self.recommendation = recommendation
    }
}

enum ConfidenceLevel: String, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

enum Recommendation: String, Codable {
    case hold = "Hold"
    case considerSelling = "Consider Selling"
    case strongSell = "Strong Sell"
    
    var color: String {
        switch self {
        case .hold: return "green"
        case .considerSelling: return "orange"
        case .strongSell: return "red"
        }
    }
}



