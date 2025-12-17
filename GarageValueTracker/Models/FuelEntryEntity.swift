import Foundation
import CoreData

@objc(FuelEntryEntity)
public class FuelEntryEntity: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var vehicleID: UUID
    @NSManaged public var date: Date
    @NSManaged public var mileage: Int32
    @NSManaged public var gallons: Double
    @NSManaged public var cost: Double
    @NSManaged public var pricePerGallon: Double
    @NSManaged public var station: String?
    @NSManaged public var notes: String?
    @NSManaged public var createdAt: Date
}

extension FuelEntryEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<FuelEntryEntity> {
        return NSFetchRequest<FuelEntryEntity>(entityName: "FuelEntryEntity")
    }
    
    convenience init(context: NSManagedObjectContext,
                     vehicleID: UUID,
                     date: Date,
                     mileage: Int,
                     gallons: Double,
                     cost: Double) {
        self.init(context: context)
        self.id = UUID()
        self.vehicleID = vehicleID
        self.date = date
        self.mileage = Int32(mileage)
        self.gallons = gallons
        self.cost = cost
        self.pricePerGallon = cost / gallons
        self.createdAt = Date()
    }
    
    // Calculate MPG if previous entry exists
    func calculateMPG(previousEntry: FuelEntryEntity?) -> Double? {
        guard let previous = previousEntry else { return nil }
        
        let milesDriven = Double(self.mileage - previous.mileage)
        guard milesDriven > 0 && gallons > 0 else { return nil }
        
        return milesDriven / gallons
    }
}

