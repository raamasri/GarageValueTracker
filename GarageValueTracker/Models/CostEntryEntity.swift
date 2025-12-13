import Foundation
import CoreData

@objc(CostEntryEntity)
public class CostEntryEntity: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var vehicleID: UUID
    @NSManaged public var date: Date
    @NSManaged public var category: String
    @NSManaged public var amount: Double
    @NSManaged public var merchantName: String?
    @NSManaged public var notes: String?
    @NSManaged public var receiptImageData: Data?
    @NSManaged public var receiptImagePath: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
}

extension CostEntryEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CostEntryEntity> {
        return NSFetchRequest<CostEntryEntity>(entityName: "CostEntryEntity")
    }
    
    convenience init(context: NSManagedObjectContext,
                     vehicleID: UUID,
                     date: Date = Date(),
                     category: String,
                     amount: Double,
                     merchantName: String? = nil,
                     notes: String? = nil,
                     receiptImageData: Data? = nil) {
        self.init(context: context)
        self.id = UUID()
        self.vehicleID = vehicleID
        self.date = date
        self.category = category
        self.amount = amount
        self.merchantName = merchantName
        self.notes = notes
        self.receiptImageData = receiptImageData
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// Cost categories
enum CostCategory: String, CaseIterable {
    case maintenance = "Maintenance"
    case repair = "Repair"
    case fuel = "Fuel"
    case insurance = "Insurance"
    case registration = "Registration"
    case modification = "Modification"
    case cleaning = "Cleaning"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .maintenance: return "wrench.and.screwdriver"
        case .repair: return "hammer"
        case .fuel: return "fuelpump"
        case .insurance: return "shield"
        case .registration: return "doc.text"
        case .modification: return "sparkles"
        case .cleaning: return "sparkles"
        case .other: return "ellipsis.circle"
        }
    }
}
