import Foundation
import CoreData

@objc(PriceHistoryEntity)
public class PriceHistoryEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var wishlistVehicleID: UUID
    @NSManaged public var price: Double
    @NSManaged public var date: Date
    @NSManaged public var source: String?
    @NSManaged public var createdAt: Date
    
    convenience init(
        context: NSManagedObjectContext,
        wishlistVehicleID: UUID,
        price: Double,
        date: Date,
        source: String? = "Manual"
    ) {
        self.init(context: context)
        self.id = UUID()
        self.wishlistVehicleID = wishlistVehicleID
        self.price = price
        self.date = date
        self.source = source
        self.createdAt = Date()
    }
}

extension PriceHistoryEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PriceHistoryEntity> {
        return NSFetchRequest<PriceHistoryEntity>(entityName: "PriceHistoryEntity")
    }
}








