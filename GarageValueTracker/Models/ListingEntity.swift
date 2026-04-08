import Foundation
import CoreData

@objc(ListingEntity)
public class ListingEntity: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var url: String?
    @NSManaged public var make: String
    @NSManaged public var model: String
    @NSManaged public var year: Int16
    @NSManaged public var trim: String?
    @NSManaged public var mileage: Int32
    @NSManaged public var askingPrice: Double
    @NSManaged public var source: String?
    @NSManaged public var priceHistoryJSON: String?
    @NSManaged public var dealScore: Int16
    @NSManaged public var lastChecked: Date?
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
}

extension ListingEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ListingEntity> {
        return NSFetchRequest<ListingEntity>(entityName: "ListingEntity")
    }
    
    convenience init(context: NSManagedObjectContext, make: String, model: String, year: Int, trim: String? = nil, mileage: Int, askingPrice: Double, url: String? = nil, source: String? = nil, dealScore: Int = 0) {
        self.init(context: context)
        self.id = UUID()
        self.make = make
        self.model = model
        self.year = Int16(year)
        self.trim = trim
        self.mileage = Int32(mileage)
        self.askingPrice = askingPrice
        self.url = url
        self.source = source
        self.dealScore = Int16(dealScore)
        self.lastChecked = Date()
        self.createdAt = Date()
        self.updatedAt = Date()
        
        let firstEntry = ListingPriceEntry(date: Date(), price: askingPrice)
        if let data = try? JSONEncoder().encode([firstEntry]) {
            self.priceHistoryJSON = data.base64EncodedString()
        }
    }
    
    var displayName: String {
        "\(year) \(make) \(model)\(trim.map { " \($0)" } ?? "")"
    }
    
    var priceHistory: [ListingPriceEntry] {
        guard let json = priceHistoryJSON,
              let data = Data(base64Encoded: json),
              let decoded = try? JSONDecoder().decode([ListingPriceEntry].self, from: data) else {
            return []
        }
        return decoded.sorted { $0.date < $1.date }
    }
    
    func recordPriceChange(_ newPrice: Double) {
        var history = priceHistory
        history.append(ListingPriceEntry(date: Date(), price: newPrice))
        if let data = try? JSONEncoder().encode(history) {
            priceHistoryJSON = data.base64EncodedString()
        }
        askingPrice = newPrice
        lastChecked = Date()
        updatedAt = Date()
    }
    
    var priceDropCount: Int {
        let history = priceHistory
        guard history.count >= 2 else { return 0 }
        var drops = 0
        for i in 1..<history.count {
            if history[i].price < history[i-1].price { drops += 1 }
        }
        return drops
    }
    
    var totalPriceChange: Double {
        let history = priceHistory
        guard let first = history.first, let last = history.last else { return 0 }
        return last.price - first.price
    }
}

struct ListingPriceEntry: Codable {
    let date: Date
    let price: Double
}
