import Foundation
import CoreData
import CoreLocation

@objc(VehicleLocationEventEntity)
public class VehicleLocationEventEntity: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var vehicleID: UUID
    @NSManaged public var date: Date
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var address: String?
    @NSManaged public var eventType: String
    @NSManaged public var title: String?
    @NSManaged public var notes: String?
    @NSManaged public var sourceEntityID: UUID?
    @NSManaged public var createdAt: Date
}

extension VehicleLocationEventEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<VehicleLocationEventEntity> {
        return NSFetchRequest<VehicleLocationEventEntity>(entityName: "VehicleLocationEventEntity")
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var locationEventType: LocationEventType {
        LocationEventType(rawValue: eventType) ?? .trip
    }
}

enum LocationEventType: String, CaseIterable, Identifiable {
    case fuel = "fuel"
    case service = "service"
    case cost = "cost"
    case home = "home"
    case purchase = "purchase"
    case accident = "accident"
    case trip = "trip"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fuel: return "Fuel"
        case .service: return "Service"
        case .cost: return "Cost"
        case .home: return "Home"
        case .purchase: return "Purchase"
        case .accident: return "Accident"
        case .trip: return "Trip"
        }
    }

    var icon: String {
        switch self {
        case .fuel: return "fuelpump.fill"
        case .service: return "wrench.and.screwdriver.fill"
        case .cost: return "dollarsign.circle.fill"
        case .home: return "house.fill"
        case .purchase: return "car.fill"
        case .accident: return "exclamationmark.triangle.fill"
        case .trip: return "flag.fill"
        }
    }

    var color: String {
        switch self {
        case .fuel: return "cyan"
        case .service: return "blue"
        case .cost: return "green"
        case .home: return "purple"
        case .purchase: return "indigo"
        case .accident: return "red"
        case .trip: return "orange"
        }
    }
}
