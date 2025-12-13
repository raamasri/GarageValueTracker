import Foundation
import CoreData

@objc(ValuationSnapshotEntity)
public class ValuationSnapshotEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var vehicleID: UUID
    @NSManaged public var date: Date
    @NSManaged public var estimatedValue: Double
    @NSManaged public var mileageAtTime: Int32
    @NSManaged public var source: String // API, Manual, etc.
    @NSManaged public var createdAt: Date
}

extension ValuationSnapshotEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ValuationSnapshotEntity> {
        return NSFetchRequest<ValuationSnapshotEntity>(entityName: "ValuationSnapshotEntity")
    }
    
    convenience init(context: NSManagedObjectContext,
                     vehicleID: UUID,
                     estimatedValue: Double,
                     mileage: Int,
                     source: String = "Manual") {
        self.init(context: context)
        self.id = UUID()
        self.vehicleID = vehicleID
        self.date = Date()
        self.estimatedValue = estimatedValue
        self.mileageAtTime = Int32(mileage)
        self.source = source
        self.createdAt = Date()
    }
}
