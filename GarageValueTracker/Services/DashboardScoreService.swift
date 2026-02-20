import Foundation
import CoreData

// MARK: - Dashboard Score Calculator
class DashboardScoreService {
    static let shared = DashboardScoreService()
    
    private init() {}
    
    func calculateDashboardScore(for vehicle: VehicleEntity, costEntryCount: Int = -1, reminderCount: Int = -1) -> DashboardScore {
        var completedItems = 0
        let totalItems = 11
        
        var missingItems: [String] = []
        
        // 1. Basic Info (always complete if vehicle exists)
        completedItems += 1
        
        // 2. Photo
        if vehicle.imageData != nil {
            completedItems += 1
        } else {
            missingItems.append("Add vehicle photo")
        }
        
        // 3. VIN
        if vehicle.vin != nil && !vehicle.vin!.isEmpty {
            completedItems += 1
        } else {
            missingItems.append("Add VIN number")
        }
        
        // 4. Current mileage
        if vehicle.mileage > 0 {
            completedItems += 1
        } else {
            missingItems.append("Update current mileage")
        }
        
        // 5. Location
        if vehicle.location != nil && !vehicle.location!.isEmpty {
            completedItems += 1
        } else {
            missingItems.append("Set vehicle location")
        }
        
        // 6. Trim info
        if vehicle.trim != nil || vehicle.selectedTrimID != nil {
            completedItems += 1
        } else {
            missingItems.append("Select trim level")
        }
        
        // 7. Insurance info
        if vehicle.insuranceProvider != nil && !vehicle.insuranceProvider!.isEmpty {
            completedItems += 1
        } else {
            missingItems.append("Add insurance information")
        }
        
        // 8. Insurance premium
        if vehicle.insurancePremium > 0 {
            completedItems += 1
        } else {
            missingItems.append("Add insurance premium amount")
        }
        
        // 9. Current value updated
        if vehicle.lastValuationUpdate != nil {
            completedItems += 1
        } else {
            missingItems.append("Update current market value")
        }
        
        // 10. Has maintenance records
        if costEntryCount > 0 {
            completedItems += 1
        } else if costEntryCount == 0 {
            missingItems.append("Add a maintenance or cost record")
        } else {
            missingItems.append("Add a maintenance or cost record")
        }
        
        // 11. Notes/documentation
        if vehicle.notes != nil && !vehicle.notes!.isEmpty {
            completedItems += 1
        } else {
            missingItems.append("Add notes or documentation")
        }
        
        let percentage = Int((Double(completedItems) / Double(totalItems)) * 100)
        
        return DashboardScore(
            percentage: percentage,
            completedItems: completedItems,
            totalItems: totalItems,
            missingItems: missingItems,
            message: messageForScore(percentage)
        )
    }
    
    private func messageForScore(_ percentage: Int) -> String {
        switch percentage {
        case 100:
            return "Perfect! Your dashboard is complete."
        case 80..<100:
            return "Great work! Just a few items left."
        case 60..<80:
            return "Good progress! Keep adding information."
        case 40..<60:
            return "You're halfway there! Add more details."
        default:
            return "Let's complete your vehicle profile."
        }
    }
}

// MARK: - Dashboard Score Result
struct DashboardScore {
    let percentage: Int
    let completedItems: Int
    let totalItems: Int
    let missingItems: [String]
    let message: String
    
    var color: String {
        switch percentage {
        case 80...100: return "green"
        case 60..<80: return "blue"
        case 40..<60: return "orange"
        default: return "red"
        }
    }
}

