import Foundation
import CoreData

class MaintenanceInsightService {
    static let shared = MaintenanceInsightService()
    
    private init() {}
    
    // MARK: - Main Insights Method
    
    /// Generate comprehensive maintenance insights for a vehicle
    func generateInsights(for vehicle: VehicleEntity, costEntries: [CostEntryEntity]) -> MaintenanceInsights {
        
        let yearlyAverage = calculateYearlyAverage(costEntries: costEntries, vehicle: vehicle)
        let comparison = compareToTypical(vehicle: vehicle, actualYearly: yearlyAverage)
        let predictions = predict5YearCosts(vehicle: vehicle, costEntries: costEntries)
        let upcomingMaintenance = getUpcomingMaintenance(vehicle: vehicle)
        let analytics = calculateAnalytics(costEntries: costEntries, vehicle: vehicle)
        
        return MaintenanceInsights(
            yearlyAverage: yearlyAverage,
            comparison: comparison,
            fiveYearPredictions: predictions,
            upcomingMaintenance: upcomingMaintenance,
            analytics: analytics
        )
    }
    
    // MARK: - Yearly Average
    
    private func calculateYearlyAverage(costEntries: [CostEntryEntity], vehicle: VehicleEntity) -> Double {
        guard !costEntries.isEmpty else { return 0.0 }
        
        let totalCost = costEntries.reduce(0.0) { $0 + $1.amount }
        let monthsOwned = max(Calendar.current.dateComponents([.month], from: vehicle.purchaseDate, to: Date()).month ?? 1, 1)
        
        return (totalCost / Double(monthsOwned)) * 12.0
    }
    
    // MARK: - Comparison to Typical
    
    private func compareToTypical(vehicle: VehicleEntity, actualYearly: Double) -> ComparisonResult {
        // Get typical costs for this make/model (simplified - using make-based averages)
        let typicalYearly = getTypicalYearlyCost(make: vehicle.make, year: Int(vehicle.year))
        
        let difference = actualYearly - typicalYearly
        let percentDifference = (difference / typicalYearly) * 100
        
        let status: ComparisonStatus
        if percentDifference <= -20 {
            status = .muchLower
        } else if percentDifference <= -5 {
            status = .lower
        } else if percentDifference <= 5 {
            status = .average
        } else if percentDifference <= 20 {
            status = .higher
        } else {
            status = .muchHigher
        }
        
        return ComparisonResult(
            typicalYearly: typicalYearly,
            yourYearly: actualYearly,
            difference: difference,
            percentDifference: percentDifference,
            status: status
        )
    }
    
    private func getTypicalYearlyCost(make: String, year: Int) -> Double {
        // Simplified typical costs by make category
        let luxuryMakes = ["BMW", "Mercedes-Benz", "Audi", "Lexus", "Porsche", "Cadillac"]
        let economyMakes = ["Toyota", "Honda", "Mazda", "Hyundai", "Kia"]
        let truckMakes = ["Ford", "Chevrolet", "RAM", "GMC"]
        
        let currentYear = Calendar.current.component(.year, from: Date())
        let age = currentYear - year
        
        var baseCost: Double
        if luxuryMakes.contains(make) {
            baseCost = 2000
        } else if economyMakes.contains(make) {
            baseCost = 1000
        } else if truckMakes.contains(make) {
            baseCost = 1500
        } else {
            baseCost = 1300
        }
        
        // Add age factor (costs increase with age)
        let ageFactor = 1.0 + (Double(age) * 0.08) // 8% increase per year
        
        return baseCost * ageFactor
    }
    
    // MARK: - 5-Year Predictions
    
    private func predict5YearCosts(vehicle: VehicleEntity, costEntries: [CostEntryEntity]) -> [YearlyPrediction] {
        let currentYear = Calendar.current.component(.year, from: Date())
        let vehicleAge = currentYear - Int(vehicle.year)
        let mileage = Int(vehicle.mileage)
        
        var predictions: [YearlyPrediction] = []
        
        for yearOffset in 1...5 {
            let year = currentYear + yearOffset
            let predictedAge = vehicleAge + yearOffset
            let predictedMileage = mileage + (yearOffset * 12000)
            
            // Base prediction on current average with age increase
            let baseYearly = calculateYearlyAverage(costEntries: costEntries, vehicle: vehicle)
            let ageMultiplier = 1.0 + (Double(yearOffset) * 0.10) // 10% increase per year
            var predictedCost = max(baseYearly, 1000.0) * ageMultiplier // Minimum $1000/year
            
            // Major service milestones
            var majorServices: [String] = []
            if predictedMileage >= 60000 && predictedMileage < 72000 {
                majorServices.append("60k service ($800-$1,200)")
                predictedCost += 1000
            } else if predictedMileage >= 90000 && predictedMileage < 102000 {
                majorServices.append("90k service ($1,200-$1,800)")
                predictedCost += 1500
            } else if predictedMileage >= 120000 && predictedMileage < 132000 {
                majorServices.append("120k service ($1,500-$2,500)")
                predictedCost += 2000
            }
            
            // Age-based replacements
            if predictedAge == 6 {
                majorServices.append("Battery replacement")
                predictedCost += 200
            } else if predictedAge == 8 {
                majorServices.append("Brake system overhaul")
                predictedCost += 800
            } else if predictedAge == 10 {
                majorServices.append("Suspension components")
                predictedCost += 1200
            }
            
            predictions.append(YearlyPrediction(
                year: year,
                predictedCost: predictedCost,
                majorServices: majorServices,
                estimatedMileage: predictedMileage,
                confidence: calculateConfidence(yearOffset: yearOffset, dataPoints: costEntries.count)
            ))
        }
        
        return predictions
    }
    
    private func calculateConfidence(yearOffset: Int, dataPoints: Int) -> Double {
        var confidence = 0.8 // Base confidence
        
        // More data = higher confidence
        if dataPoints > 20 {
            confidence += 0.15
        } else if dataPoints > 10 {
            confidence += 0.10
        } else if dataPoints > 5 {
            confidence += 0.05
        } else {
            confidence -= 0.20
        }
        
        // Nearer future = higher confidence
        confidence -= (Double(yearOffset - 1) * 0.10)
        
        return max(min(confidence, 0.95), 0.40)
    }
    
    // MARK: - Upcoming Maintenance (make-specific intervals)
    
    private func getUpcomingMaintenance(vehicle: VehicleEntity) -> [UpcomingMaintenanceItem] {
        let mileage = Int(vehicle.mileage)
        let schedule = maintenanceSchedule(for: vehicle.make)
        var items: [UpcomingMaintenanceItem] = []
        
        if schedule.oilChangeInterval > 0 {
            let nextOilChange = ((mileage / schedule.oilChangeInterval) + 1) * schedule.oilChangeInterval
            items.append(UpcomingMaintenanceItem(
                service: "Oil Change",
                dueAtMileage: nextOilChange,
                estimatedCost: schedule.oilChangeCost,
                priority: nextOilChange - mileage <= 500 ? .critical : .recommended
            ))
        }
        
        let nextTireRotation = ((mileage / schedule.tireRotationInterval) + 1) * schedule.tireRotationInterval
        items.append(UpcomingMaintenanceItem(
            service: "Tire Rotation",
            dueAtMileage: nextTireRotation,
            estimatedCost: 40,
            priority: .recommended
        ))
        
        if schedule.brakeFluidInterval > 0 {
            let nextBrakeFluid = ((mileage / schedule.brakeFluidInterval) + 1) * schedule.brakeFluidInterval
            if nextBrakeFluid - mileage <= 15000 {
                items.append(UpcomingMaintenanceItem(
                    service: "Brake Fluid Change",
                    dueAtMileage: nextBrakeFluid,
                    estimatedCost: 120,
                    priority: .recommended
                ))
            }
        }
        
        if schedule.transmissionFluidInterval > 0 {
            let nextTrans = ((mileage / schedule.transmissionFluidInterval) + 1) * schedule.transmissionFluidInterval
            if nextTrans - mileage <= 15000 {
                items.append(UpcomingMaintenanceItem(
                    service: "Transmission Fluid",
                    dueAtMileage: nextTrans,
                    estimatedCost: schedule.transmissionFluidCost,
                    priority: .recommended
                ))
            }
        }
        
        if schedule.sparkPlugInterval > 0 {
            let nextSpark = ((mileage / schedule.sparkPlugInterval) + 1) * schedule.sparkPlugInterval
            if nextSpark - mileage <= 15000 {
                items.append(UpcomingMaintenanceItem(
                    service: "Spark Plug Replacement",
                    dueAtMileage: nextSpark,
                    estimatedCost: schedule.sparkPlugCost,
                    priority: .recommended
                ))
            }
        }
        
        let majorIntervals: [(Int, String, Double)] = [
            (30000, "30k Service", schedule.majorServiceCost30k),
            (60000, "60k Service", schedule.majorServiceCost60k),
            (90000, "90k Service", schedule.majorServiceCost90k),
            (120000, "120k Service", schedule.majorServiceCost90k * 1.3),
        ]
        for (milestone, name, cost) in majorIntervals {
            if mileage < milestone && milestone - mileage <= 15000 {
                items.append(UpcomingMaintenanceItem(
                    service: name,
                    dueAtMileage: milestone,
                    estimatedCost: cost,
                    priority: .recommended
                ))
                break
            }
        }
        
        return items.sorted { $0.dueAtMileage < $1.dueAtMileage }
    }
    
    // MARK: - Make-Specific Maintenance Schedules
    
    private struct MakeSchedule {
        let oilChangeInterval: Int
        let oilChangeCost: Double
        let tireRotationInterval: Int
        let brakeFluidInterval: Int
        let transmissionFluidInterval: Int
        let transmissionFluidCost: Double
        let sparkPlugInterval: Int
        let sparkPlugCost: Double
        let majorServiceCost30k: Double
        let majorServiceCost60k: Double
        let majorServiceCost90k: Double
    }
    
    private func maintenanceSchedule(for make: String) -> MakeSchedule {
        switch make.uppercased() {
        case "TOYOTA", "LEXUS":
            return MakeSchedule(oilChangeInterval: 10000, oilChangeCost: 65, tireRotationInterval: 5000, brakeFluidInterval: 30000, transmissionFluidInterval: 60000, transmissionFluidCost: 180, sparkPlugInterval: 60000, sparkPlugCost: 200, majorServiceCost30k: 400, majorServiceCost60k: 800, majorServiceCost90k: 1200)
        case "HONDA", "ACURA":
            return MakeSchedule(oilChangeInterval: 7500, oilChangeCost: 55, tireRotationInterval: 7500, brakeFluidInterval: 30000, transmissionFluidInterval: 30000, transmissionFluidCost: 160, sparkPlugInterval: 60000, sparkPlugCost: 180, majorServiceCost30k: 350, majorServiceCost60k: 750, majorServiceCost90k: 1100)
        case "BMW":
            return MakeSchedule(oilChangeInterval: 10000, oilChangeCost: 120, tireRotationInterval: 5000, brakeFluidInterval: 20000, transmissionFluidInterval: 50000, transmissionFluidCost: 350, sparkPlugInterval: 60000, sparkPlugCost: 450, majorServiceCost30k: 600, majorServiceCost60k: 1500, majorServiceCost90k: 2200)
        case "MERCEDES-BENZ":
            return MakeSchedule(oilChangeInterval: 10000, oilChangeCost: 130, tireRotationInterval: 5000, brakeFluidInterval: 20000, transmissionFluidInterval: 40000, transmissionFluidCost: 400, sparkPlugInterval: 60000, sparkPlugCost: 500, majorServiceCost30k: 650, majorServiceCost60k: 1600, majorServiceCost90k: 2500)
        case "AUDI":
            return MakeSchedule(oilChangeInterval: 10000, oilChangeCost: 110, tireRotationInterval: 5000, brakeFluidInterval: 20000, transmissionFluidInterval: 40000, transmissionFluidCost: 350, sparkPlugInterval: 60000, sparkPlugCost: 400, majorServiceCost30k: 550, majorServiceCost60k: 1400, majorServiceCost90k: 2100)
        case "FORD":
            return MakeSchedule(oilChangeInterval: 7500, oilChangeCost: 60, tireRotationInterval: 7500, brakeFluidInterval: 30000, transmissionFluidInterval: 60000, transmissionFluidCost: 200, sparkPlugInterval: 60000, sparkPlugCost: 250, majorServiceCost30k: 400, majorServiceCost60k: 900, majorServiceCost90k: 1400)
        case "CHEVROLET", "GMC":
            return MakeSchedule(oilChangeInterval: 7500, oilChangeCost: 60, tireRotationInterval: 7500, brakeFluidInterval: 30000, transmissionFluidInterval: 45000, transmissionFluidCost: 200, sparkPlugInterval: 60000, sparkPlugCost: 250, majorServiceCost30k: 400, majorServiceCost60k: 900, majorServiceCost90k: 1400)
        case "HYUNDAI", "KIA", "GENESIS":
            return MakeSchedule(oilChangeInterval: 7500, oilChangeCost: 55, tireRotationInterval: 7500, brakeFluidInterval: 30000, transmissionFluidInterval: 60000, transmissionFluidCost: 170, sparkPlugInterval: 45000, sparkPlugCost: 200, majorServiceCost30k: 350, majorServiceCost60k: 750, majorServiceCost90k: 1100)
        case "SUBARU":
            return MakeSchedule(oilChangeInterval: 6000, oilChangeCost: 60, tireRotationInterval: 7500, brakeFluidInterval: 30000, transmissionFluidInterval: 60000, transmissionFluidCost: 180, sparkPlugInterval: 60000, sparkPlugCost: 250, majorServiceCost30k: 400, majorServiceCost60k: 850, majorServiceCost90k: 1300)
        case "TESLA":
            return MakeSchedule(oilChangeInterval: 0, oilChangeCost: 0, tireRotationInterval: 6250, brakeFluidInterval: 25000, transmissionFluidInterval: 0, transmissionFluidCost: 0, sparkPlugInterval: 0, sparkPlugCost: 0, majorServiceCost30k: 200, majorServiceCost60k: 400, majorServiceCost90k: 600)
        case "PORSCHE":
            return MakeSchedule(oilChangeInterval: 10000, oilChangeCost: 180, tireRotationInterval: 5000, brakeFluidInterval: 20000, transmissionFluidInterval: 40000, transmissionFluidCost: 500, sparkPlugInterval: 40000, sparkPlugCost: 600, majorServiceCost30k: 800, majorServiceCost60k: 2000, majorServiceCost90k: 3000)
        default:
            return MakeSchedule(oilChangeInterval: 5000, oilChangeCost: 60, tireRotationInterval: 7500, brakeFluidInterval: 30000, transmissionFluidInterval: 60000, transmissionFluidCost: 200, sparkPlugInterval: 60000, sparkPlugCost: 220, majorServiceCost30k: 450, majorServiceCost60k: 900, majorServiceCost90k: 1400)
        }
    }
    
    // MARK: - Analytics
    
    private func calculateAnalytics(costEntries: [CostEntryEntity], vehicle: VehicleEntity) -> MaintenanceAnalytics {
        guard !costEntries.isEmpty else {
            return MaintenanceAnalytics(
                costPerMile: 0,
                costPerMonth: 0,
                totalSpent: 0,
                mostExpensiveCategory: "N/A",
                trend: .stable
            )
        }
        
        let totalCost = costEntries.reduce(0.0) { $0 + $1.amount }
        let monthsOwned = max(Calendar.current.dateComponents([.month], from: vehicle.purchaseDate, to: Date()).month ?? 1, 1)
        let estimatedMilesDriven = max(monthsOwned * 1000, 1)
        let costPerMile = totalCost / Double(estimatedMilesDriven)
        let costPerMonth = totalCost / Double(monthsOwned)
        
        // Find most expensive category
        var categoryTotals: [String: Double] = [:]
        for entry in costEntries {
            categoryTotals[entry.category, default: 0] += entry.amount
        }
        let mostExpensive = categoryTotals.max { $0.value < $1.value }?.key ?? "N/A"
        
        let trend: CostTrend
        if costEntries.count >= 4 {
            let sorted = costEntries.sorted { $0.date < $1.date }
            let midpoint = sorted.count / 2
            let olderAvg = sorted[..<midpoint].reduce(0.0) { $0 + $1.amount } / Double(midpoint)
            let newerAvg = sorted[midpoint...].reduce(0.0) { $0 + $1.amount } / Double(sorted.count - midpoint)
            
            let difference = (newerAvg - olderAvg) / max(olderAvg, 1.0)
            if difference > 0.15 {
                trend = .increasing
            } else if difference < -0.15 {
                trend = .decreasing
            } else {
                trend = .stable
            }
        } else {
            trend = .stable
        }
        
        return MaintenanceAnalytics(
            costPerMile: costPerMile,
            costPerMonth: costPerMonth,
            totalSpent: totalCost,
            mostExpensiveCategory: mostExpensive,
            trend: trend
        )
    }
}

// MARK: - Result Structures

struct MaintenanceInsights {
    let yearlyAverage: Double
    let comparison: ComparisonResult
    let fiveYearPredictions: [YearlyPrediction]
    let upcomingMaintenance: [UpcomingMaintenanceItem]
    let analytics: MaintenanceAnalytics
}

struct ComparisonResult {
    let typicalYearly: Double
    let yourYearly: Double
    let difference: Double
    let percentDifference: Double
    let status: ComparisonStatus
}

enum ComparisonStatus: String {
    case muchLower = "Much Lower Than Average"
    case lower = "Below Average"
    case average = "Average"
    case higher = "Above Average"
    case muchHigher = "Much Higher Than Average"
    
    var color: String {
        switch self {
        case .muchLower, .lower: return "green"
        case .average: return "blue"
        case .higher: return "orange"
        case .muchHigher: return "red"
        }
    }
}

struct YearlyPrediction {
    let year: Int
    let predictedCost: Double
    let majorServices: [String]
    let estimatedMileage: Int
    let confidence: Double // 0.0-1.0
}

struct UpcomingMaintenanceItem {
    let service: String
    let dueAtMileage: Int
    let estimatedCost: Double
    let priority: MaintenancePriority
}

enum MaintenancePriority: String {
    case critical = "Critical"
    case recommended = "Recommended"
    case optional = "Optional"
    
    var color: String {
        switch self {
        case .critical: return "red"
        case .recommended: return "blue"
        case .optional: return "gray"
        }
    }
}

struct MaintenanceAnalytics {
    let costPerMile: Double
    let costPerMonth: Double
    let totalSpent: Double
    let mostExpensiveCategory: String
    let trend: CostTrend
}

enum CostTrend: String {
    case increasing = "Increasing"
    case stable = "Stable"
    case decreasing = "Decreasing"
    
    var icon: String {
        switch self {
        case .increasing: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .decreasing: return "arrow.down.right"
        }
    }
}

