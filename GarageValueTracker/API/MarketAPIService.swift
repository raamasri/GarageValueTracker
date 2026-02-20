import Foundation

class MarketAPIService {
    static let shared = MarketAPIService()
    
    private init() {}
    
    /// Estimate market value using MSRP + depreciation curves + mileage adjustment.
    /// This uses real MSRP data from the trim database when available, and
    /// make-specific depreciation rates based on industry data.
    func getMarketValue(make: String, model: String, year: Int, mileage: Int, trim: String? = nil, msrp: Double? = nil, location: String? = nil, completion: @escaping (Result<MarketValue, Error>) -> Void) {
        
        let baseMSRP = resolveBaseMSRP(make: make, model: model, year: year, trim: trim, providedMSRP: msrp)
        let currentYear = Calendar.current.component(.year, from: Date())
        let age = max(currentYear - year, 0)
        
        let yearlyRate = depreciationRate(for: make, model: model)
        var depreciatedValue = baseMSRP
        for yr in 0..<age {
            let rate = yr == 0 ? yearlyRate.firstYear : yearlyRate.subsequent
            depreciatedValue *= (1.0 - rate)
        }
        
        let expectedMiles = age * 12000
        let mileageDelta = mileage - expectedMiles
        let mileageAdjustment: Double
        if mileageDelta > 0 {
            mileageAdjustment = -Double(mileageDelta) * 0.05 / 1000.0
        } else {
            mileageAdjustment = -Double(mileageDelta) * 0.03 / 1000.0
        }
        depreciatedValue += mileageAdjustment
        
        var averagePrice = max(depreciatedValue, baseMSRP * 0.05)
        
        // Apply location-based adjustment
        if let location = location, !location.isEmpty {
            let locationMultiplier = LocationMarketService.shared.getDemandMultiplier(
                location: location, make: make, model: model
            )
            averagePrice *= locationMultiplier
        }
        
        let spread = averagePrice * 0.12
        
        let result = MarketValue(
            averagePrice: averagePrice,
            highPrice: averagePrice + spread,
            lowPrice: max(averagePrice - spread, 500),
            lastUpdated: Date()
        )
        
        DispatchQueue.main.async { completion(.success(result)) }
    }
    
    func getValuation(vehicle: VehicleSearchResult, mileage: Int, completion: @escaping (Result<VehicleValuation, Error>) -> Void) {
        getMarketValue(make: vehicle.make, model: vehicle.model, year: vehicle.year, mileage: mileage, trim: vehicle.trim) { result in
            switch result {
            case .success(let marketValue):
                let valuation = VehicleValuation(vehicle: vehicle, marketValue: marketValue)
                completion(.success(valuation))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - MSRP Resolution
    
    private func resolveBaseMSRP(make: String, model: String, year: Int, trim: String?, providedMSRP: Double?) -> Double {
        if let msrp = providedMSRP, msrp > 0 { return msrp }
        
        let trims = TrimDatabaseService.shared.getTrims(make: make, model: model, year: year)
        if let trim = trim, let match = trims.first(where: { $0.trimLevel == trim }) {
            return match.msrp
        }
        if let midTrim = trims.sorted(by: { $0.msrp < $1.msrp }).dropFirst(trims.count / 2).first {
            return midTrim.msrp
        }
        
        return estimateMSRP(make: make)
    }
    
    private func estimateMSRP(make: String) -> Double {
        let upperMake = make.uppercased()
        let luxury: Set = ["BMW", "MERCEDES-BENZ", "AUDI", "LEXUS", "PORSCHE", "CADILLAC", "INFINITI", "ACURA", "GENESIS", "VOLVO", "LINCOLN", "LAND ROVER", "JAGUAR", "MASERATI", "ALFA ROMEO"]
        let premium: Set = ["TESLA", "RIVIAN", "LUCID"]
        let exotic: Set = ["FERRARI", "LAMBORGHINI", "MCLAREN", "BENTLEY", "ROLLS-ROYCE", "ASTON MARTIN", "BUGATTI"]
        let truck: Set = ["FORD", "CHEVROLET", "GMC", "RAM", "TOYOTA"]
        
        if exotic.contains(upperMake) { return 250_000 }
        if premium.contains(upperMake) { return 55_000 }
        if luxury.contains(upperMake) { return 48_000 }
        if truck.contains(upperMake) { return 42_000 }
        return 32_000
    }
    
    // MARK: - Depreciation Rates (based on iSeeCars / Edmunds industry data)
    
    private struct DepreciationProfile {
        let firstYear: Double
        let subsequent: Double
    }
    
    private func depreciationRate(for make: String, model: String) -> DepreciationProfile {
        let upperMake = make.uppercased()
        let upperModel = model.uppercased()
        
        if upperModel.contains("WRANGLER") || upperModel.contains("4RUNNER") || upperModel.contains("TACOMA") || upperModel.contains("G-WAGON") || upperModel.contains("BRONCO") {
            return DepreciationProfile(firstYear: 0.08, subsequent: 0.06)
        }
        
        if ["PORSCHE", "FERRARI", "LAMBORGHINI"].contains(upperMake) {
            return DepreciationProfile(firstYear: 0.10, subsequent: 0.07)
        }
        
        let holdValue: Set = ["TOYOTA", "LEXUS", "HONDA", "SUBARU"]
        if holdValue.contains(upperMake) {
            return DepreciationProfile(firstYear: 0.15, subsequent: 0.10)
        }
        
        if upperMake == "TESLA" {
            return DepreciationProfile(firstYear: 0.20, subsequent: 0.12)
        }
        
        let heavyDepreciation: Set = ["BMW", "MERCEDES-BENZ", "AUDI", "MASERATI", "JAGUAR", "ALFA ROMEO", "LINCOLN"]
        if heavyDepreciation.contains(upperMake) {
            return DepreciationProfile(firstYear: 0.25, subsequent: 0.15)
        }
        
        return DepreciationProfile(firstYear: 0.20, subsequent: 0.12)
    }
}
