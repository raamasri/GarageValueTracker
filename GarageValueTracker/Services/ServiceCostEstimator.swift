import Foundation

// MARK: - JSON Structures
struct ServiceDatabase: Codable {
    let services: [ServiceCategory]
}

struct ServiceCategory: Codable, Identifiable {
    var id: String { category }
    let category: String
    let services: [ServiceInfo]
}

struct ServiceInfo: Codable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let baseCost: Double
    let costRange: String
    let frequency: String
    let factors: [String]
}

// MARK: - Service Cost Estimator
class ServiceCostEstimator {
    static let shared = ServiceCostEstimator()
    
    private var database: ServiceDatabase?
    
    private init() {
        loadDatabase()
    }
    
    // MARK: - Database Loading
    private func loadDatabase() {
        guard let url = Bundle.main.url(forResource: "service_costs", withExtension: "json") else {
            print("❌ Could not find service_costs.json")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            database = try JSONDecoder().decode(ServiceDatabase.self, from: data)
            print("✅ Loaded \(database?.services.count ?? 0) service categories")
        } catch {
            print("❌ Error loading service database: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Query Methods
    
    /// Get all service categories
    func getAllCategories() -> [ServiceCategory] {
        return database?.services ?? []
    }
    
    /// Get services for a specific category
    func getServices(for category: String) -> [ServiceInfo] {
        return database?.services.first(where: { $0.category == category })?.services ?? []
    }
    
    /// Search for services by name
    func searchServices(query: String) -> [ServiceInfo] {
        guard let database = database else { return [] }
        
        let queryLower = query.lowercased()
        var results: [ServiceInfo] = []
        
        for category in database.services {
            for service in category.services {
                if service.name.lowercased().contains(queryLower) {
                    results.append(service)
                }
            }
        }
        
        return results
    }
    
    /// Get a specific service by name
    func getService(named: String) -> ServiceInfo? {
        guard let database = database else { return nil }
        
        for category in database.services {
            if let service = category.services.first(where: { $0.name.lowercased() == named.lowercased() }) {
                return service
            }
        }
        
        return nil
    }
    
    // MARK: - Cost Estimation
    
    /// Estimate cost for a service adjusted for vehicle type
    func estimateCost(service: ServiceInfo, vehicleType: VehicleType, vehicleAge: Int) -> CostEstimate {
        var adjustedCost = service.baseCost
        var adjustmentFactors: [String] = []
        
        // Vehicle type adjustments
        switch vehicleType {
        case .luxury:
            adjustedCost *= 1.40 // +40% for luxury vehicles
            adjustmentFactors.append("Luxury vehicle: +40%")
        case .truck:
            adjustedCost *= 1.25 // +25% for trucks
            adjustmentFactors.append("Truck/SUV: +25%")
        case .economy:
            adjustedCost *= 0.95 // -5% for economy vehicles
            adjustmentFactors.append("Economy vehicle: -5%")
        case .standard:
            break // No adjustment
        }
        
        // Age adjustment (older vehicles may need more work)
        if vehicleAge > 10 {
            adjustedCost *= 1.15 // +15% for vehicles over 10 years old
            adjustmentFactors.append("Vehicle age 10+ years: +15%")
        } else if vehicleAge > 7 {
            adjustedCost *= 1.08 // +8% for vehicles over 7 years
            adjustmentFactors.append("Vehicle age 7+ years: +8%")
        }
        
        // Calculate range
        let lowEnd = adjustedCost * 0.8
        let highEnd = adjustedCost * 1.2
        
        return CostEstimate(
            serviceName: service.name,
            estimatedCost: adjustedCost,
            costRange: (lowEnd, highEnd),
            adjustmentFactors: adjustmentFactors,
            baseService: service
        )
    }
    
    /// Estimate cost for a service given a vehicle entity
    func estimateCost(service: ServiceInfo, for vehicle: VehicleEntity) -> CostEstimate {
        let vehicleType = determineVehicleType(make: vehicle.make, model: vehicle.model)
        let currentYear = Calendar.current.component(.year, from: Date())
        let vehicleAge = currentYear - Int(vehicle.year)
        
        return estimateCost(service: service, vehicleType: vehicleType, vehicleAge: vehicleAge)
    }
    
    /// Determine vehicle type from make/model
    private func determineVehicleType(make: String, model: String) -> VehicleType {
        let luxuryMakes = ["BMW", "Mercedes-Benz", "Audi", "Lexus", "Porsche", "Cadillac", "Infiniti", "Acura"]
        let truckModels = ["f-150", "silverado", "ram", "tundra", "tacoma", "ranger", "colorado", "frontier"]
        let economyMakes = ["Hyundai", "Kia", "Nissan", "Mazda"]
        
        if luxuryMakes.contains(make) {
            return .luxury
        } else if truckModels.contains(where: { model.lowercased().contains($0) }) {
            return .truck
        } else if economyMakes.contains(make) {
            return .economy
        } else {
            return .standard
        }
    }
    
    // MARK: - Service Recommendations
    
    /// Get recommended services based on mileage
    func getRecommendedServices(for mileage: Int) -> [ServiceRecommendation] {
        guard let database = database else { return [] }
        
        var recommendations: [ServiceRecommendation] = []
        
        // Oil change (every 5-7k miles)
        if mileage % 5000 < 1000 {
            if let service = getService(named: "Oil Change") {
                recommendations.append(ServiceRecommendation(
                    service: service,
                    reason: "Due for regular oil change at \(mileage) miles",
                    priority: .high
                ))
            }
        }
        
        // Tire rotation (every 6-8k miles)
        if mileage % 7500 < 1000 {
            if let service = getService(named: "Tire Rotation") {
                recommendations.append(ServiceRecommendation(
                    service: service,
                    reason: "Tire rotation recommended",
                    priority: .medium
                ))
            }
        }
        
        // Major services
        if mileage >= 29000 && mileage < 31000 {
            if let service = getService(named: "30k Mile Service") {
                recommendations.append(ServiceRecommendation(
                    service: service,
                    reason: "Approaching 30,000 mile service",
                    priority: .high
                ))
            }
        } else if mileage >= 59000 && mileage < 61000 {
            if let service = getService(named: "60k Mile Service") {
                recommendations.append(ServiceRecommendation(
                    service: service,
                    reason: "Approaching 60,000 mile service",
                    priority: .high
                ))
            }
        } else if mileage >= 89000 && mileage < 91000 {
            if let service = getService(named: "90k Mile Service") {
                recommendations.append(ServiceRecommendation(
                    service: service,
                    reason: "Approaching 90,000 mile service",
                    priority: .high
                ))
            }
        }
        
        return recommendations
    }
}

// MARK: - Supporting Types

enum VehicleType {
    case economy
    case standard
    case luxury
    case truck
}

struct CostEstimate {
    let serviceName: String
    let estimatedCost: Double
    let costRange: (low: Double, high: Double)
    let adjustmentFactors: [String]
    let baseService: ServiceInfo
    
    var formattedEstimate: String {
        return String(format: "$%.0f", estimatedCost)
    }
    
    var formattedRange: String {
        return String(format: "$%.0f - $%.0f", costRange.low, costRange.high)
    }
}

struct ServiceRecommendation: Identifiable {
    var id: String { service.id }
    let service: ServiceInfo
    let reason: String
    let priority: Priority
    
    enum Priority {
        case low, medium, high
        
        var color: String {
            switch self {
            case .low: return "gray"
            case .medium: return "blue"
            case .high: return "orange"
            }
        }
    }
}

