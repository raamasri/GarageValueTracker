import Foundation

class VehicleAPIService {
    static let shared = VehicleAPIService()
    
    private let baseURL = "https://vpic.nhtsa.dot.gov/api/vehicles"
    
    private init() {}
    
    func decodeVIN(_ vin: String) async throws -> NHTSAVehicleResult? {
        let urlString = "\(baseURL)/DecodeVinValues/\(vin)?format=json"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError
        }
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(NHTSAVINDecodeResponse.self, from: data)
        
        return result.results.first
    }
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case serverError
    case decodingError
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .serverError:
            return "Server returned an error"
        case .decodingError:
            return "Failed to decode response"
        case .networkError:
            return "Network connection error"
        }
    }
}



