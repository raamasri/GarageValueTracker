import Foundation
import CoreData

@objc(WishlistVehicleEntity)
public class WishlistVehicleEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var make: String
    @NSManaged public var model: String
    @NSManaged public var year: Int16
    @NSManaged public var trim: String?
    @NSManaged public var mileage: Int32
    @NSManaged public var currentPrice: Double
    @NSManaged public var targetPrice: Double
    @NSManaged public var location: String?
    @NSManaged public var seller: String?
    @NSManaged public var listingURL: String?
    @NSManaged public var vin: String?
    @NSManaged public var notes: String?
    @NSManaged public var imageData: Data?
    @NSManaged public var lastPriceUpdate: Date?
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    
    var displayName: String {
        return "\(year) \(make) \(model)"
    }
    
    var priceChangeFromTarget: Double? {
        guard targetPrice > 0 else { return nil }
        return currentPrice - targetPrice
    }
    
    var priceChangePercentageFromTarget: Double? {
        guard targetPrice > 0 else { return nil }
        return ((currentPrice - targetPrice) / targetPrice) * 100
    }
    
    var isPriceUnderTarget: Bool {
        guard targetPrice > 0 else { return false }
        return currentPrice <= targetPrice
    }
    
    convenience init(
        context: NSManagedObjectContext,
        make: String,
        model: String,
        year: Int16,
        trim: String? = nil,
        mileage: Int32 = 0,
        currentPrice: Double,
        targetPrice: Double = 0,
        location: String? = nil,
        seller: String? = nil,
        listingURL: String? = nil,
        vin: String? = nil,
        notes: String? = nil,
        imageData: Data? = nil
    ) {
        self.init(context: context)
        self.id = UUID()
        self.make = make
        self.model = model
        self.year = year
        self.trim = trim
        self.mileage = mileage
        self.currentPrice = currentPrice
        self.targetPrice = targetPrice
        self.location = location
        self.seller = seller
        self.listingURL = listingURL
        self.vin = vin
        self.notes = notes
        self.imageData = imageData
        self.lastPriceUpdate = Date()
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

extension WishlistVehicleEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<WishlistVehicleEntity> {
        return NSFetchRequest<WishlistVehicleEntity>(entityName: "WishlistVehicleEntity")
    }
}

