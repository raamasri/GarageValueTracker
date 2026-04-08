import Foundation
import CoreData

class CostToHoldService {
    static let shared = CostToHoldService()
    
    private init() {}
    
    func project(vehicle: VehicleEntity, months: Int, context: NSManagedObjectContext) -> CostToHoldProjection {
        let segment = vehicle.resolvedSegment
        let currentValuation = ValuationEngine.shared.valuate(
            make: vehicle.make, model: vehicle.model,
            year: Int(vehicle.year), mileage: Int(vehicle.mileage),
            trim: vehicle.trim, msrp: vehicle.trimMSRP > 0 ? vehicle.trimMSRP : nil,
            location: vehicle.location, condition: vehicle.conditionTier
        )
        
        let projectedValues = ValuationEngine.shared.projectValue(
            currentValue: currentValuation.mid,
            make: vehicle.make, model: vehicle.model,
            segment: segment, months: months
        )
        let futureValue = projectedValues.last?.value ?? currentValuation.mid
        let projectedDepreciation = max(currentValuation.mid - futureValue, 0)
        
        let annualInsurance = vehicle.insurancePremium
        let projectedInsurance = annualInsurance * (Double(months) / 12.0)
        
        let loanRequest = LoanEntity.fetchRequest()
        loanRequest.predicate = NSPredicate(format: "vehicleID == %@ AND isActive == YES", vehicle.id as CVarArg)
        let loans = (try? context.fetch(loanRequest)) ?? []
        var projectedLoanInterest = 0.0
        if let loan = loans.first {
            let monthlyRate = loan.interestRate / 100.0 / 12.0
            let remainingBalance = loan.loanAmount
            projectedLoanInterest = remainingBalance * monthlyRate * Double(months)
        }
        
        let costRequest = CostEntryEntity.fetchRequest()
        costRequest.predicate = NSPredicate(format: "vehicleID == %@ AND category == %@", vehicle.id as CVarArg, "Maintenance")
        let maintenanceCosts = (try? context.fetch(costRequest)) ?? []
        let monthsOwned = max(Calendar.current.dateComponents([.month], from: vehicle.purchaseDate, to: Date()).month ?? 1, 1)
        let monthlyMaintenance: Double
        if !maintenanceCosts.isEmpty {
            let totalMaintenance = maintenanceCosts.reduce(0.0) { $0 + $1.amount }
            monthlyMaintenance = totalMaintenance / Double(monthsOwned)
        } else {
            monthlyMaintenance = MaintenanceInsightService.shared.generateInsights(
                for: vehicle, costEntries: []
            ).comparison.typicalYearly / 12.0
        }
        let projectedMaintenance = monthlyMaintenance * Double(months)
        
        let totalCost = projectedDepreciation + projectedInsurance + projectedLoanInterest + projectedMaintenance
        let monthlyCost = months > 0 ? totalCost / Double(months) : 0
        
        return CostToHoldProjection(
            months: months,
            currentValue: currentValuation.mid,
            projectedFutureValue: futureValue,
            projectedDepreciation: projectedDepreciation,
            projectedInsurance: projectedInsurance,
            projectedLoanInterest: projectedLoanInterest,
            projectedMaintenance: projectedMaintenance,
            totalProjectedCost: totalCost,
            monthlyCost: monthlyCost
        )
    }
    
    func projectMultiple(vehicle: VehicleEntity, context: NSManagedObjectContext) -> [CostToHoldProjection] {
        [6, 12, 24].map { project(vehicle: vehicle, months: $0, context: context) }
    }
}

struct CostToHoldProjection: Identifiable {
    var id: Int { months }
    let months: Int
    let currentValue: Double
    let projectedFutureValue: Double
    let projectedDepreciation: Double
    let projectedInsurance: Double
    let projectedLoanInterest: Double
    let projectedMaintenance: Double
    let totalProjectedCost: Double
    let monthlyCost: Double
    
    var formattedTotal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: totalProjectedCost)) ?? "$\(Int(totalProjectedCost))"
    }
    
    var formattedMonthly: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: monthlyCost)) ?? "$\(Int(monthlyCost))"
    }
}
