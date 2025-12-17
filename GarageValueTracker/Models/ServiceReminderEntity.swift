import Foundation
import CoreData

@objc(ServiceReminderEntity)
public class ServiceReminderEntity: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var vehicleID: UUID
    @NSManaged public var serviceType: String
    @NSManaged public var iconName: String
    @NSManaged public var dueDate: Date
    @NSManaged public var dueMileage: Int32
    @NSManaged public var intervalMonths: Int16
    @NSManaged public var intervalMileage: Int32
    @NSManaged public var lastServiceDate: Date?
    @NSManaged public var lastServiceMileage: Int32
    @NSManaged public var isCompleted: Bool
    @NSManaged public var completedDate: Date?
    @NSManaged public var notes: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
}

extension ServiceReminderEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ServiceReminderEntity> {
        return NSFetchRequest<ServiceReminderEntity>(entityName: "ServiceReminderEntity")
    }
    
    convenience init(context: NSManagedObjectContext,
                     vehicleID: UUID,
                     serviceType: String,
                     iconName: String,
                     dueDate: Date,
                     dueMileage: Int = 0,
                     intervalMonths: Int = 0,
                     intervalMileage: Int = 0) {
        self.init(context: context)
        self.id = UUID()
        self.vehicleID = vehicleID
        self.serviceType = serviceType
        self.iconName = iconName
        self.dueDate = dueDate
        self.dueMileage = Int32(dueMileage)
        self.intervalMonths = Int16(intervalMonths)
        self.intervalMileage = Int32(intervalMileage)
        self.isCompleted = false
        self.lastServiceMileage = 0
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // Calculate days remaining
    var daysRemaining: Int {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: now, to: dueDate)
        return components.day ?? 0
    }
    
    // Calculate months remaining
    var monthsRemaining: Int {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.month], from: now, to: dueDate)
        return max(components.month ?? 0, 0)
    }
    
    // Calculate weeks remaining
    var weeksRemaining: Int {
        let days = daysRemaining
        return max(days / 7, 0)
    }
    
    // Is overdue
    var isOverdue: Bool {
        return dueDate < Date() && !isCompleted
    }
    
    // Calculate progress percentage
    func progressPercentage(currentMileage: Int) -> Double {
        guard intervalMileage > 0 else {
            // Time-based calculation
            guard let lastDate = lastServiceDate else { return 0.0 }
            let totalInterval = TimeInterval(intervalMonths) * 30 * 24 * 60 * 60 // Approximate
            let elapsed = Date().timeIntervalSince(lastDate)
            return min((elapsed / totalInterval) * 100, 100)
        }
        
        // Mileage-based calculation
        let mileageSinceLastService = currentMileage - Int(lastServiceMileage)
        return min((Double(mileageSinceLastService) / Double(intervalMileage)) * 100, 100)
    }
}

