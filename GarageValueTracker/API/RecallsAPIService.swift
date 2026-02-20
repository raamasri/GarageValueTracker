import Foundation

class RecallsAPIService {
    static let shared = RecallsAPIService()
    
    private let baseURL = "https://api.nhtsa.gov/recalls/recallsByVehicle"
    
    private init() {}
    
    func getRecalls(make: String, model: String, modelYear: Int, completion: @escaping (Result<[RecallResult], Error>) -> Void) {
        let cleanMake = make.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? make
        let cleanModel = model.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? model
        
        let urlString = "\(baseURL)?make=\(cleanMake)&model=\(cleanModel)&modelYear=\(modelYear)"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(RecallsAPIError.invalidURL))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(RecallsAPIError.noData)) }
                return
            }
            
            do {
                let response = try JSONDecoder().decode(NHTSARecallsResponse.self, from: data)
                
                let recalls = response.results.map { item in
                    RecallResult(
                        campaignNumber: item.NHTSACampaignNumber ?? "",
                        reportDate: item.ReportReceivedDate ?? "",
                        component: item.Component ?? "",
                        summary: item.Summary ?? "",
                        consequence: item.Consequence ?? "",
                        remedy: item.Remedy ?? "",
                        make: item.Make ?? "",
                        model: item.Model ?? "",
                        modelYear: item.ModelYear ?? "",
                        parkIt: item.parkIt ?? false
                    )
                }
                
                DispatchQueue.main.async { completion(.success(recalls)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }
}

enum RecallsAPIError: LocalizedError {
    case invalidURL
    case noData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Could not build recalls request URL."
        case .noData: return "No data received from NHTSA."
        }
    }
}
