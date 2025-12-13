import Foundation

// MARK: - API Models

struct VehicleSearchResult: Codable {
    let make: String
    let model: String
    let year: Int
    let trim: String?
}

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
