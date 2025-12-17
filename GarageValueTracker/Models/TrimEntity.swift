import Foundation
import CoreData

@objc(TrimEntity)
public class TrimEntity: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var make: String
    @NSManaged public var model: String
    @NSManaged public var year: Int16
    @NSManaged public var trimLevel: String
    @NSManaged public var msrp: Double
    @NSManaged public var features: String? // JSON encoded array
    @NSManaged public var marketValue: Double
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
}

extension TrimEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TrimEntity> {
        return NSFetchRequest<TrimEntity>(entityName: "TrimEntity")
    }
    
    convenience init(context: NSManagedObjectContext,
                     make: String,
                     model: String,
                     year: Int,
                     trimLevel: String,
                     msrp: Double,
                     features: [String]? = nil,
                     marketValue: Double? = nil) {
        self.init(context: context)
        self.id = UUID()
        self.make = make
        self.model = model
        self.year = Int16(year)
        self.trimLevel = trimLevel
        self.msrp = msrp
        self.marketValue = marketValue ?? msrp
        
        if let features = features {
            self.features = try? JSONEncoder().encode(features).base64EncodedString()
        }
        
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var featuresList: [String] {
        guard let features = features,
              let data = Data(base64Encoded: features),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return decoded
    }
    
    var displayName: String {
        return "\(year) \(make) \(model) \(trimLevel)"
    }
    
    func formattedMSRP() -> String {
        return String(format: "$%.0f", msrp)
    }
    
    func formattedMarketValue() -> String {
        return String(format: "$%.0f", marketValue)
    }
}

// Trim comparison helper
extension TrimEntity {
    func priceDifference(from otherTrim: TrimEntity) -> Double {
        return self.msrp - otherTrim.msrp
    }
    
    func formattedPriceDifference(from otherTrim: TrimEntity) -> String {
        let diff = priceDifference(from: otherTrim)
        let sign = diff >= 0 ? "+" : ""
        return String(format: "%@$%.0f", sign, abs(diff))
    }
}

