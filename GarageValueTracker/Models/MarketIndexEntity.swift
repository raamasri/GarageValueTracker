import Foundation
import CoreData

@objc(MarketIndexEntity)
public class MarketIndexEntity: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var indexDescription: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
}

extension MarketIndexEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<MarketIndexEntity> {
        return NSFetchRequest<MarketIndexEntity>(entityName: "MarketIndexEntity")
    }
    
    convenience init(context: NSManagedObjectContext, name: String, description: String? = nil) {
        self.init(context: context)
        self.id = UUID()
        self.name = name
        self.indexDescription = description
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@objc(MarketIndexMemberEntity)
public class MarketIndexMemberEntity: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var indexID: UUID
    @NSManaged public var make: String
    @NSManaged public var model: String
    @NSManaged public var yearStart: Int16
    @NSManaged public var yearEnd: Int16
    @NSManaged public var trimFilter: String?
    @NSManaged public var createdAt: Date
}

extension MarketIndexMemberEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<MarketIndexMemberEntity> {
        return NSFetchRequest<MarketIndexMemberEntity>(entityName: "MarketIndexMemberEntity")
    }
    
    convenience init(context: NSManagedObjectContext, indexID: UUID, make: String, model: String, yearStart: Int, yearEnd: Int, trimFilter: String? = nil) {
        self.init(context: context)
        self.id = UUID()
        self.indexID = indexID
        self.make = make
        self.model = model
        self.yearStart = Int16(yearStart)
        self.yearEnd = Int16(yearEnd)
        self.trimFilter = trimFilter
        self.createdAt = Date()
    }
    
    var displayName: String {
        let yearRange = yearStart == yearEnd ? "\(yearStart)" : "\(yearStart)-\(yearEnd)"
        var name = "\(yearRange) \(make) \(model)"
        if let trim = trimFilter { name += " \(trim)" }
        return name
    }
}
