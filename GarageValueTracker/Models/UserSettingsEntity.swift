import Foundation
import CoreData

@objc(UserSettingsEntity)
public class UserSettingsEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var currency: String
    @NSManaged public var distanceUnit: String // miles or km
    @NSManaged public var notificationsEnabled: Bool
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
}

extension UserSettingsEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserSettingsEntity> {
        return NSFetchRequest<UserSettingsEntity>(entityName: "UserSettingsEntity")
    }
    
    nonisolated convenience init(context: NSManagedObjectContext) {
        self.init(context: context)
        self.id = UUID()
        self.currency = "USD"
        self.distanceUnit = "miles"
        self.notificationsEnabled = true
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
