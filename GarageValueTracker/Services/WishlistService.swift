import Foundation
import CoreData

class WishlistService {
    static let shared = WishlistService()
    
    private init() {}
    
    // MARK: - Wishlist Vehicle Operations
    
    /// Get all wishlist vehicles
    func getAllWishlistVehicles(context: NSManagedObjectContext) -> [WishlistVehicleEntity] {
        let request: NSFetchRequest<WishlistVehicleEntity> = WishlistVehicleEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \WishlistVehicleEntity.createdAt, ascending: false)
        ]
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ Error fetching wishlist vehicles: \(error)")
            return []
        }
    }
    
    /// Add a vehicle to wishlist
    func addToWishlist(
        context: NSManagedObjectContext,
        make: String,
        model: String,
        year: Int16,
        trim: String? = nil,
        mileage: Int32 = 0,
        currentPrice: Double,
        targetPrice: Double = 0,
        location: String? = nil,
        seller: String? = nil,
        listingURL: String? = nil,
        vin: String? = nil,
        notes: String? = nil,
        imageData: Data? = nil
    ) -> WishlistVehicleEntity? {
        let vehicle = WishlistVehicleEntity(
            context: context,
            make: make,
            model: model,
            year: year,
            trim: trim,
            mileage: mileage,
            currentPrice: currentPrice,
            targetPrice: targetPrice,
            location: location,
            seller: seller,
            listingURL: listingURL,
            vin: vin,
            notes: notes,
            imageData: imageData
        )
        
        // Add initial price history entry
        _ = PriceHistoryEntity(
            context: context,
            wishlistVehicleID: vehicle.id,
            price: currentPrice,
            date: Date(),
            source: "Initial"
        )
        
        do {
            try context.save()
            print("✅ Added vehicle to wishlist: \(vehicle.displayName)")
            return vehicle
        } catch {
            print("❌ Error adding to wishlist: \(error)")
            return nil
        }
    }
    
    /// Update price for a wishlist vehicle
    func updatePrice(
        for vehicleID: UUID,
        newPrice: Double,
        context: NSManagedObjectContext,
        source: String = "Manual"
    ) -> Bool {
        let request: NSFetchRequest<WishlistVehicleEntity> = WishlistVehicleEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", vehicleID as CVarArg)
        
        do {
            let vehicles = try context.fetch(request)
            guard let vehicle = vehicles.first else { return false }
            
            // Only add to history if price changed
            if vehicle.currentPrice != newPrice {
                vehicle.currentPrice = newPrice
                vehicle.lastPriceUpdate = Date()
                vehicle.updatedAt = Date()
                
                // Add price history entry
                _ = PriceHistoryEntity(
                    context: context,
                    wishlistVehicleID: vehicleID,
                    price: newPrice,
                    date: Date(),
                    source: source
                )
                
                try context.save()
                
                // Check target price and send notification
                if vehicle.targetPrice > 0 {
                    if newPrice <= vehicle.targetPrice {
                        NotificationService.shared.sendPriceTargetAlert(
                            vehicleName: vehicle.displayName,
                            currentPrice: newPrice,
                            targetPrice: vehicle.targetPrice
                        )
                    } else {
                        let percentAway = ((newPrice - vehicle.targetPrice) / vehicle.targetPrice) * 100
                        if percentAway <= 10 {
                            NotificationService.shared.sendPriceDropAlert(
                                vehicleName: vehicle.displayName,
                                currentPrice: newPrice,
                                targetPrice: vehicle.targetPrice,
                                percentAway: percentAway
                            )
                        }
                    }
                }
                
                print("✅ Updated price for \(vehicle.displayName): $\(newPrice)")
                return true
            }
            
            return true
        } catch {
            print("❌ Error updating price: \(error)")
            return false
        }
    }
    
    /// Delete a wishlist vehicle
    func deleteWishlistVehicle(
        _ vehicle: WishlistVehicleEntity,
        context: NSManagedObjectContext
    ) -> Bool {
        // Delete associated price history
        let historyRequest: NSFetchRequest<PriceHistoryEntity> = PriceHistoryEntity.fetchRequest()
        historyRequest.predicate = NSPredicate(format: "wishlistVehicleID == %@", vehicle.id as CVarArg)
        
        do {
            let history = try context.fetch(historyRequest)
            history.forEach { context.delete($0) }
            
            context.delete(vehicle)
            try context.save()
            print("✅ Deleted wishlist vehicle: \(vehicle.displayName)")
            return true
        } catch {
            print("❌ Error deleting wishlist vehicle: \(error)")
            return false
        }
    }
    
    // MARK: - Price History Operations
    
    /// Get price history for a wishlist vehicle
    func getPriceHistory(
        for vehicleID: UUID,
        context: NSManagedObjectContext
    ) -> [PriceHistoryEntity] {
        let request: NSFetchRequest<PriceHistoryEntity> = PriceHistoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "wishlistVehicleID == %@", vehicleID as CVarArg)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \PriceHistoryEntity.date, ascending: true)
        ]
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ Error fetching price history: \(error)")
            return []
        }
    }
    
    /// Calculate price statistics
    func getPriceStatistics(
        for vehicleID: UUID,
        context: NSManagedObjectContext
    ) -> PriceStatistics? {
        let history = getPriceHistory(for: vehicleID, context: context)
        guard !history.isEmpty else { return nil }
        
        let prices = history.map { $0.price }
        let lowestPrice = prices.min() ?? 0
        let highestPrice = prices.max() ?? 0
        let averagePrice = prices.reduce(0, +) / Double(prices.count)
        
        // Calculate trend
        var trend: PriceTrend = .stable
        if history.count >= 2 {
            let recentPrices = Array(history.suffix(3)).map { $0.price }
            if recentPrices.count >= 2 {
                let priceChange = recentPrices.last! - recentPrices.first!
                let percentChange = (priceChange / recentPrices.first!) * 100
                
                if percentChange > 2 {
                    trend = .increasing
                } else if percentChange < -2 {
                    trend = .decreasing
                }
            }
        }
        
        return PriceStatistics(
            lowestPrice: lowestPrice,
            highestPrice: highestPrice,
            averagePrice: averagePrice,
            currentPrice: prices.last ?? 0,
            priceChangeSinceAdded: (prices.last ?? 0) - prices.first!,
            daysTracked: history.count,
            trend: trend
        )
    }
    
    /// Move wishlist vehicle to garage
    func moveToGarage(
        _ wishlistVehicle: WishlistVehicleEntity,
        purchasePrice: Double,
        purchaseDate: Date,
        mileage: Int32,
        vin: String? = nil,
        context: NSManagedObjectContext
    ) -> VehicleEntity? {
        // Create new garage vehicle
        let garageVehicle = VehicleEntity(
            context: context,
            make: wishlistVehicle.make,
            model: wishlistVehicle.model,
            year: Int(wishlistVehicle.year),
            trim: wishlistVehicle.trim,
            vin: vin ?? wishlistVehicle.vin,
            mileage: Int(mileage),
            purchasePrice: purchasePrice,
            purchaseDate: purchaseDate
        )
        
        // Set additional properties
        garageVehicle.currentValue = purchasePrice
        garageVehicle.notes = wishlistVehicle.notes
        garageVehicle.imageData = wishlistVehicle.imageData
        
        // Delete wishlist vehicle and its history
        _ = deleteWishlistVehicle(wishlistVehicle, context: context)
        
        do {
            try context.save()
            print("✅ Moved wishlist vehicle to garage: \(garageVehicle.displayName)")
            return garageVehicle
        } catch {
            print("❌ Error moving to garage: \(error)")
            return nil
        }
    }
}

// MARK: - Supporting Types

struct PriceStatistics {
    let lowestPrice: Double
    let highestPrice: Double
    let averagePrice: Double
    let currentPrice: Double
    let priceChangeSinceAdded: Double
    let daysTracked: Int
    let trend: PriceTrend
    
    var priceChangeSinceAddedPercentage: Double {
        guard lowestPrice > 0 else { return 0 }
        return (priceChangeSinceAdded / lowestPrice) * 100
    }
}

enum PriceTrend {
    case increasing
    case decreasing
    case stable
    
    var icon: String {
        switch self {
        case .increasing: return "arrow.up.right"
        case .decreasing: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }
    
    var color: String {
        switch self {
        case .increasing: return "red"
        case .decreasing: return "green"
        case .stable: return "gray"
        }
    }
    
    var displayName: String {
        switch self {
        case .increasing: return "Increasing"
        case .decreasing: return "Decreasing"
        case .stable: return "Stable"
        }
    }
}

