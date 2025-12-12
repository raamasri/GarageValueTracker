import Foundation
import SwiftData

@Model
final class VehicleEntity {
    var id: UUID
    var ownershipType: OwnershipType
    var vin: String?
    var year: Int
    var make: String
    var model: String
    var trim: String
    var transmission: String
    var mileageCurrent: Int
    var zip: String
    var segment: String?
    var regionBucket: String?
    var mileageBand: String?
    
    // Purchase info (for owned vehicles)
    var purchasePrice: Double?
    var purchaseDate: Date?
    var purchaseMileage: Int?
    
    // Watchlist info
    var targetPrice: Double?
    var alertEnabled: Bool
    
    var createdAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \CostEntryEntity.vehicle)
    var costEntries: [CostEntryEntity]?
    
    @Relationship(deleteRule: .cascade, inverse: \ValuationSnapshotEntity.vehicle)
    var valuationSnapshots: [ValuationSnapshotEntity]?
    
    init(
        id: UUID = UUID(),
        ownershipType: OwnershipType,
        vin: String? = nil,
        year: Int,
        make: String,
        model: String,
        trim: String,
        transmission: String,
        mileageCurrent: Int,
        zip: String,
        segment: String? = nil,
        regionBucket: String? = nil,
        mileageBand: String? = nil,
        purchasePrice: Double? = nil,
        purchaseDate: Date? = nil,
        purchaseMileage: Int? = nil,
        targetPrice: Double? = nil,
        alertEnabled: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.ownershipType = ownershipType
        self.vin = vin
        self.year = year
        self.make = make
        self.model = model
        self.trim = trim
        self.transmission = transmission
        self.mileageCurrent = mileageCurrent
        self.zip = zip
        self.segment = segment
        self.regionBucket = regionBucket
        self.mileageBand = mileageBand
        self.purchasePrice = purchasePrice
        self.purchaseDate = purchaseDate
        self.purchaseMileage = purchaseMileage
        self.targetPrice = targetPrice
        self.alertEnabled = alertEnabled
        self.createdAt = createdAt
    }
    
    var displayName: String {
        "\(year) \(make) \(model) \(trim)"
    }
}

enum OwnershipType: String, Codable {
    case owned
    case watchlist
}



