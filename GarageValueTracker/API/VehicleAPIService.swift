import Foundation

class VehicleAPIService {
    static let shared = VehicleAPIService()
    
    private let vinDecodeBaseURL = "https://vpic.nhtsa.dot.gov/api/vehicles/decodevinvalues"
    
    private init() {}
    
    // MARK: - VIN Decode (NHTSA vPIC API -- free, no key required)
    
    func decodeVIN(_ vin: String, completion: @escaping (Result<VINDecodeResult, Error>) -> Void) {
        let cleaned = vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        guard cleaned.count == 17 else {
            completion(.failure(VehicleAPIError.invalidVIN))
            return
        }
        
        guard let url = URL(string: "\(vinDecodeBaseURL)/\(cleaned)?format=json") else {
            completion(.failure(VehicleAPIError.invalidURL))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(VehicleAPIError.noData)) }
                return
            }
            
            do {
                let response = try JSONDecoder().decode(NHTSAVINResponse.self, from: data)
                
                guard let result = response.Results.first else {
                    DispatchQueue.main.async { completion(.failure(VehicleAPIError.noResults)) }
                    return
                }
                
                let make = result["Make"] ?? ""
                let model = result["Model"] ?? ""
                let yearStr = result["ModelYear"] ?? "0"
                let year = Int(yearStr) ?? 0
                
                guard !make.isEmpty, !model.isEmpty, year > 0 else {
                    let errorText = result["ErrorText"] ?? "Could not decode VIN"
                    DispatchQueue.main.async {
                        completion(.failure(VehicleAPIError.decodeFailed(errorText)))
                    }
                    return
                }
                
                let decoded = VINDecodeResult(
                    vin: cleaned,
                    make: make,
                    model: model,
                    year: year,
                    trim: Self.nonEmpty(result["Trim"]),
                    bodyClass: Self.nonEmpty(result["BodyClass"]),
                    driveType: Self.nonEmpty(result["DriveType"]),
                    engineCylinders: Self.nonEmpty(result["EngineCylinders"]),
                    engineHP: Self.nonEmpty(result["EngineHP"]),
                    displacementL: Self.nonEmpty(result["DisplacementL"]),
                    fuelType: Self.nonEmpty(result["FuelTypePrimary"]),
                    transmission: Self.nonEmpty(result["TransmissionStyle"]),
                    doors: Self.nonEmpty(result["Doors"]),
                    plantCity: Self.nonEmpty(result["PlantCity"]),
                    plantCountry: Self.nonEmpty(result["PlantCountry"]),
                    errorCode: Self.nonEmpty(result["ErrorCode"]),
                    errorText: Self.nonEmpty(result["ErrorText"])
                )
                
                DispatchQueue.main.async { completion(.success(decoded)) }
                
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }
    
    // MARK: - Search (uses local trim DB, keeps existing interface)
    
    func searchVehicles(make: String, model: String, year: Int, completion: @escaping (Result<[VehicleSearchResult], Error>) -> Void) {
        let trims = TrimDatabaseService.shared.getTrims(make: make, model: model, year: year)
        
        if !trims.isEmpty {
            let results = trims.map { trim in
                VehicleSearchResult(make: make, model: model, year: year, trim: trim.trimLevel)
            }
            completion(.success(results))
        } else {
            let results = [
                VehicleSearchResult(make: make, model: model, year: year, trim: nil)
            ]
            completion(.success(results))
        }
    }
    
    // MARK: - Helpers
    
    private static func nonEmpty(_ value: String?) -> String? {
        guard let value = value, !value.isEmpty else { return nil }
        return value
    }
}

// MARK: - Errors

enum VehicleAPIError: LocalizedError {
    case invalidVIN
    case invalidURL
    case noData
    case noResults
    case decodeFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidVIN:
            return "VIN must be exactly 17 characters."
        case .invalidURL:
            return "Could not build request URL."
        case .noData:
            return "No data received from NHTSA."
        case .noResults:
            return "No vehicle found for this VIN."
        case .decodeFailed(let detail):
            return "VIN decode failed: \(detail)"
        }
    }
}
