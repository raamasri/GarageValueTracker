import Foundation
import CoreData
import CoreLocation

@objc(TripEventEntity)
public class TripEventEntity: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var vehicleID: UUID
    @NSManaged public var date: Date
    @NSManaged public var destination: String
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var notes: String?
    @NSManaged public var createdAt: Date
}

extension TripEventEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TripEventEntity> {
        return NSFetchRequest<TripEventEntity>(entityName: "TripEventEntity")
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
