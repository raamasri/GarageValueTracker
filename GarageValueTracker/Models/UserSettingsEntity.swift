import Foundation
import SwiftData

@Model
final class UserSettingsEntity {
    var id: UUID
    var hoursPerWeekActiveListing: Double
    var hoursPerTestDrive: Double
    var hoursPerPriceChange: Double
    var defaultZipCode: String
    var currencySymbol: String
    
    init(
        id: UUID = UUID(),
        hoursPerWeekActiveListing: Double = 1.5,
        hoursPerTestDrive: Double = 1.0,
        hoursPerPriceChange: Double = 0.5,
        defaultZipCode: String = "",
        currencySymbol: String = "$"
    ) {
        self.id = id
        self.hoursPerWeekActiveListing = hoursPerWeekActiveListing
        self.hoursPerTestDrive = hoursPerTestDrive
        self.hoursPerPriceChange = hoursPerPriceChange
        self.defaultZipCode = defaultZipCode
        self.currencySymbol = currencySymbol
    }
}



