import Foundation

class MarketAPIService {
    static let shared = MarketAPIService()
    
    private init() {}
    
    func getMarketValue(make: String, model: String, year: Int, mileage: Int, completion: @escaping (Result<MarketValue, Error>) -> Void) {
        // This would connect to a real market data API in production
        // For now, return mock data
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let mockValue = MarketValue(
                averagePrice: 25000.0,
                highPrice: 28000.0,
                lowPrice: 22000.0,
                lastUpdated: Date()
            )
            completion(.success(mockValue))
        }
    }
    
    func getValuation(vehicle: VehicleSearchResult, mileage: Int, completion: @escaping (Result<VehicleValuation, Error>) -> Void) {
        getMarketValue(make: vehicle.make, model: vehicle.model, year: vehicle.year, mileage: mileage) { result in
            switch result {
            case .success(let marketValue):
                let valuation = VehicleValuation(vehicle: vehicle, marketValue: marketValue)
                completion(.success(valuation))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
