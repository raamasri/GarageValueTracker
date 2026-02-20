import Foundation

// MARK: - Vehicle Search / VIN Decode

struct VehicleSearchResult: Codable {
    let make: String
    let model: String
    let year: Int
    let trim: String?
}

struct VINDecodeResult {
    let vin: String
    let make: String
    let model: String
    let year: Int
    let trim: String?
    let bodyClass: String?
    let driveType: String?
    let engineCylinders: String?
    let engineHP: String?
    let displacementL: String?
    let fuelType: String?
    let transmission: String?
    let doors: String?
    let plantCity: String?
    let plantCountry: String?
    let errorCode: String?
    let errorText: String?
    
    var isValid: Bool {
        return !make.isEmpty && !model.isEmpty && year > 0
    }
    
    var engineDescription: String? {
        var parts: [String] = []
        if let liters = displacementL, !liters.isEmpty { parts.append("\(liters)L") }
        if let cyl = engineCylinders, !cyl.isEmpty { parts.append("\(cyl)-cyl") }
        if let hp = engineHP, !hp.isEmpty { parts.append("\(hp) HP") }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}

// MARK: - Market Value

struct MarketValue: Codable {
    let averagePrice: Double
    let highPrice: Double
    let lowPrice: Double
    let lastUpdated: Date
}

struct VehicleValuation: Codable {
    let vehicle: VehicleSearchResult
    let marketValue: MarketValue
}

// MARK: - Recall

struct RecallResult {
    let campaignNumber: String
    let reportDate: String
    let component: String
    let summary: String
    let consequence: String
    let remedy: String
    let make: String
    let model: String
    let modelYear: String
    let parkIt: Bool
}

// MARK: - NHTSA VIN Decode JSON Response

struct NHTSAVINResponse: Codable {
    let Count: Int
    let Message: String
    let Results: [[String: String]]
}

// MARK: - NHTSA Recalls JSON Response

struct NHTSARecallsResponse: Codable {
    let Count: Int
    let results: [NHTSARecallItem]
}

struct NHTSARecallItem: Codable {
    let NHTSACampaignNumber: String?
    let ReportReceivedDate: String?
    let Component: String?
    let Summary: String?
    let Consequence: String?
    let Remedy: String?
    let Make: String?
    let Model: String?
    let ModelYear: String?
    let parkIt: Bool?
}
