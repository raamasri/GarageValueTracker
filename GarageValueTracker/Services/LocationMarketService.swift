import Foundation

class LocationMarketService {
    static let shared = LocationMarketService()
    
    private var regions: [MarketRegion] = []
    
    private init() {
        loadRegions()
    }
    
    // MARK: - Data Loading
    
    private func loadRegions() {
        guard let url = Bundle.main.url(forResource: "market_regions", withExtension: "json") else {
            print("Could not find market_regions.json")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(MarketRegionsDatabase.self, from: data)
            regions = decoded.regions
        } catch {
            print("Error loading market regions: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Public API
    
    func getRegion(for stateCode: String) -> MarketRegion? {
        let upper = stateCode.uppercased().trimmingCharacters(in: .whitespaces)
        return regions.first { $0.states.contains(upper) }
    }
    
    func getRegionFromLocation(_ location: String) -> MarketRegion? {
        let stateCode = extractStateCode(from: location)
        guard let code = stateCode else { return nil }
        return getRegion(for: code)
    }
    
    func getDemandMultiplier(location: String, make: String, model: String) -> Double {
        guard let region = getRegionFromLocation(location) else { return 1.0 }
        
        let vehicleCategory = classifyVehicle(make: make, model: model)
        let demandMultiplier = region.demandMultipliers[vehicleCategory] ?? region.demandMultipliers["default"] ?? 1.0
        
        return demandMultiplier * region.costOfLivingMultiplier
    }
    
    func getLocationAdjustedValue(baseValue: Double, location: String, make: String, model: String) -> LocationAdjustedValue {
        let multiplier = getDemandMultiplier(location: location, make: make, model: model)
        let adjustedValue = baseValue * multiplier
        let region = getRegionFromLocation(location)
        
        return LocationAdjustedValue(
            baseValue: baseValue,
            adjustedValue: adjustedValue,
            multiplier: multiplier,
            regionName: region?.name ?? "Unknown",
            vehicleCategory: classifyVehicle(make: make, model: model)
        )
    }
    
    func getAllRegions() -> [MarketRegion] {
        return regions
    }
    
    // MARK: - Vehicle Classification
    
    func classifyVehicle(make: String, model: String) -> String {
        let upperMake = make.uppercased()
        let upperModel = model.uppercased()
        
        let evModels: Set = ["MODEL 3", "MODEL Y", "MODEL S", "MODEL X", "BOLT", "BOLT EV", "BOLT EUV",
                             "LEAF", "ID.4", "IONIQ 5", "IONIQ 6", "EV6", "MACH-E", "MUSTANG MACH-E",
                             "RIVIAN", "LUCID", "LIGHTNING", "F-150 LIGHTNING", "HUMMER EV"]
        let evMakes: Set = ["TESLA", "RIVIAN", "LUCID", "POLESTAR"]
        
        if evMakes.contains(upperMake) || evModels.contains(upperModel) {
            return "ev"
        }
        
        let luxuryMakes: Set = ["BMW", "MERCEDES-BENZ", "AUDI", "LEXUS", "PORSCHE", "CADILLAC",
                                "INFINITI", "ACURA", "GENESIS", "VOLVO", "LINCOLN", "LAND ROVER",
                                "JAGUAR", "MASERATI", "BENTLEY", "ROLLS-ROYCE", "FERRARI",
                                "LAMBORGHINI", "MCLAREN", "ASTON MARTIN", "ALFA ROMEO"]
        if luxuryMakes.contains(upperMake) {
            return "luxury"
        }
        
        let truckModels: Set = ["F-150", "SILVERADO", "RAM 1500", "RAM 2500", "RAM 3500",
                                "TUNDRA", "TACOMA", "RANGER", "COLORADO", "FRONTIER",
                                "CANYON", "GLADIATOR", "SIERRA", "TITAN"]
        if truckModels.contains(where: { upperModel.contains($0) }) {
            return "truck"
        }
        
        let suvIndicators = ["SUV", "4RUNNER", "WRANGLER", "BRONCO", "EXPLORER", "TAHOE",
                             "SUBURBAN", "EXPEDITION", "SEQUOIA", "HIGHLANDER", "PILOT",
                             "PATHFINDER", "TELLURIDE", "PALISADE", "TRAVERSE", "DURANGO"]
        if suvIndicators.contains(where: { upperModel.contains($0) }) {
            return "suv"
        }
        
        let sportsModels = ["MUSTANG", "CAMARO", "CORVETTE", "SUPRA", "GR86", "BRZ",
                            "370Z", "400Z", "MIATA", "MX-5", "WRX", "STI", "TYPE R",
                            "GT-R", "911", "CAYMAN", "BOXSTER", "M3", "M4", "M5",
                            "AMG", "RS", "TT", "CHALLENGER", "CHARGER"]
        if sportsModels.contains(where: { upperModel.contains($0) }) {
            return "sports"
        }
        
        return "sedan"
    }
    
    // MARK: - State Code Extraction
    
    private static let stateAbbreviations: Set<String> = [
        "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
        "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
        "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
        "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
        "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY", "DC"
    ]
    
    private static let stateNames: [String: String] = [
        "ALABAMA": "AL", "ALASKA": "AK", "ARIZONA": "AZ", "ARKANSAS": "AR",
        "CALIFORNIA": "CA", "COLORADO": "CO", "CONNECTICUT": "CT", "DELAWARE": "DE",
        "FLORIDA": "FL", "GEORGIA": "GA", "HAWAII": "HI", "IDAHO": "ID",
        "ILLINOIS": "IL", "INDIANA": "IN", "IOWA": "IA", "KANSAS": "KS",
        "KENTUCKY": "KY", "LOUISIANA": "LA", "MAINE": "ME", "MARYLAND": "MD",
        "MASSACHUSETTS": "MA", "MICHIGAN": "MI", "MINNESOTA": "MN", "MISSISSIPPI": "MS",
        "MISSOURI": "MO", "MONTANA": "MT", "NEBRASKA": "NE", "NEVADA": "NV",
        "NEW HAMPSHIRE": "NH", "NEW JERSEY": "NJ", "NEW MEXICO": "NM", "NEW YORK": "NY",
        "NORTH CAROLINA": "NC", "NORTH DAKOTA": "ND", "OHIO": "OH", "OKLAHOMA": "OK",
        "OREGON": "OR", "PENNSYLVANIA": "PA", "RHODE ISLAND": "RI", "SOUTH CAROLINA": "SC",
        "SOUTH DAKOTA": "SD", "TENNESSEE": "TN", "TEXAS": "TX", "UTAH": "UT",
        "VERMONT": "VT", "VIRGINIA": "VA", "WASHINGTON": "WA", "WEST VIRGINIA": "WV",
        "WISCONSIN": "WI", "WYOMING": "WY"
    ]
    
    private func extractStateCode(from location: String) -> String? {
        let components = location.uppercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        
        // Try direct abbreviation match (e.g., "Dallas, TX")
        for component in components.reversed() {
            if Self.stateAbbreviations.contains(component) {
                return component
            }
        }
        
        // Try full state name match (e.g., "Dallas, Texas")
        let fullString = location.uppercased()
        for (name, code) in Self.stateNames {
            if fullString.contains(name) {
                return code
            }
        }
        
        return nil
    }
}

// MARK: - Data Models

struct MarketRegionsDatabase: Codable {
    let regions: [MarketRegion]
}

struct MarketRegion: Codable {
    let name: String
    let states: [String]
    let demandMultipliers: [String: Double]
    let costOfLivingMultiplier: Double
}

struct LocationAdjustedValue {
    let baseValue: Double
    let adjustedValue: Double
    let multiplier: Double
    let regionName: String
    let vehicleCategory: String
    
    var adjustmentPercent: Double {
        return (multiplier - 1.0) * 100
    }
    
    var isHigherThanBase: Bool {
        return adjustedValue > baseValue
    }
}
