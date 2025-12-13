import Foundation
import CoreData

@objc(VehicleEntity)
public class VehicleEntity: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var make: String
    @NSManaged public var model: String
    @NSManaged public var year: Int16
    @NSManaged public var trim: String?
    @NSManaged public var vin: String?
    @NSManaged public var mileage: Int32
    @NSManaged public var purchasePrice: Double
    @NSManaged public var purchaseDate: Date
    @NSManaged public var currentValue: Double
    @NSManaged public var lastValuationUpdate: Date?
    @NSManaged public var imageData: Data?
    @NSManaged public var notes: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
}

extension VehicleEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<VehicleEntity> {
        return NSFetchRequest<VehicleEntity>(entityName: "VehicleEntity")
    }
    
    convenience init(context: NSManagedObjectContext,
                     make: String,
                     model: String,
                     year: Int,
                     trim: String? = nil,
                     vin: String? = nil,
                     mileage: Int = 0,
                     purchasePrice: Double,
                     purchaseDate: Date = Date()) {
        self.init(context: context)
        self.id = UUID()
        self.make = make
        self.model = model
        self.year = Int16(year)
        self.trim = trim
        self.vin = vin
        self.mileage = Int32(mileage)
        self.purchasePrice = purchasePrice
        self.purchaseDate = purchaseDate
        self.currentValue = purchasePrice
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var displayName: String {
        var name = "\(year) \(make) \(model)"
        if let trim = trim {
            name += " \(trim)"
        }
        return name
    }
}
