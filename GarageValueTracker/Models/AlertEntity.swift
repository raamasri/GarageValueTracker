import Foundation
import CoreData

@objc(AlertEntity)
public class AlertEntity: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var vehicleID: UUID?
    @NSManaged public var alertType: String
    @NSManaged public var title: String
    @NSManaged public var message: String?
    @NSManaged public var threshold: Double
    @NSManaged public var isEnabled: Bool
    @NSManaged public var lastTriggered: Date?
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
}

extension AlertEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<AlertEntity> {
        return NSFetchRequest<AlertEntity>(entityName: "AlertEntity")
    }
    
    convenience init(context: NSManagedObjectContext, vehicleID: UUID? = nil, type: AlertType, title: String, message: String? = nil, threshold: Double = 0) {
        self.init(context: context)
        self.id = UUID()
        self.vehicleID = vehicleID
        self.alertType = type.rawValue
        self.title = title
        self.message = message
        self.threshold = threshold
        self.isEnabled = true
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var type: AlertType {
        AlertType(rawValue: alertType) ?? .priceTarget
    }
}

enum AlertType: String, CaseIterable {
    case priceTarget = "price_target"
    case depreciationCliff = "depreciation_cliff"
    case sellWindow = "sell_window"
    case segmentMovement = "segment_movement"
    case registrationReminder = "registration_reminder"
    case insuranceReminder = "insurance_reminder"
    case inspectionReminder = "inspection_reminder"
    case maintenanceDue = "maintenance_due"
    
    var displayName: String {
        switch self {
        case .priceTarget: return "Price Target"
        case .depreciationCliff: return "Depreciation Cliff"
        case .sellWindow: return "Sell Window"
        case .segmentMovement: return "Segment Movement"
        case .registrationReminder: return "Registration Reminder"
        case .insuranceReminder: return "Insurance Reminder"
        case .inspectionReminder: return "Inspection Reminder"
        case .maintenanceDue: return "Maintenance Due"
        }
    }
    
    var icon: String {
        switch self {
        case .priceTarget: return "target"
        case .depreciationCliff: return "chart.line.downtrend.xyaxis"
        case .sellWindow: return "calendar.badge.clock"
        case .segmentMovement: return "chart.xyaxis.line"
        case .registrationReminder: return "doc.text"
        case .insuranceReminder: return "shield"
        case .inspectionReminder: return "checkmark.seal"
        case .maintenanceDue: return "wrench.and.screwdriver"
        }
    }
}
