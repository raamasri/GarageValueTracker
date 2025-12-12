import Foundation
import SwiftData

@Model
final class CostEntryEntity {
    var id: UUID
    var date: Date
    var category: CostCategory
    var amount: Double
    var notes: String
    var vehicle: VehicleEntity?
    
    init(
        id: UUID = UUID(),
        date: Date,
        category: CostCategory,
        amount: Double,
        notes: String = ""
    ) {
        self.id = id
        self.date = date
        self.category = category
        self.amount = amount
        self.notes = notes
    }
}

enum CostCategory: String, Codable, CaseIterable {
    case maintenance = "Maintenance"
    case repairs = "Repairs"
    case insurance = "Insurance"
    case registration = "Registration/Tax"
    case mods = "Modifications"
    case fuel = "Fuel"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .maintenance: return "wrench.and.screwdriver"
        case .repairs: return "hammer"
        case .insurance: return "shield"
        case .registration: return "doc.text"
        case .mods: return "sparkles"
        case .fuel: return "fuelpump"
        case .other: return "ellipsis.circle"
        }
    }
}



