import Foundation

class LicensePlateService {
    static let shared = LicensePlateService()
    
    private init() {}
    
    struct PlateResult {
        let vin: String
        let make: String?
        let model: String?
        let year: Int?
    }
    
    enum PlateError: LocalizedError {
        case invalidPlate
        case stateRequired
        case lookupFailed
        case serviceUnavailable
        
        var errorDescription: String? {
            switch self {
            case .invalidPlate:
                return "Please enter a valid license plate number."
            case .stateRequired:
                return "Please select the state of registration."
            case .lookupFailed:
                return "Could not find a vehicle with this plate. Please enter the VIN manually instead."
            case .serviceUnavailable:
                return "Plate lookup is not available. Please use VIN lookup instead."
            }
        }
    }
    
    /// Attempts to look up a vehicle by license plate and state.
    /// Falls back to prompting for VIN if plate lookup isn't available.
    func lookupPlate(_ plate: String, state: String, completion: @escaping (Result<PlateResult, PlateError>) -> Void) {
        let cleaned = plate.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        guard !cleaned.isEmpty, cleaned.count >= 2, cleaned.count <= 8 else {
            completion(.failure(.invalidPlate))
            return
        }
        
        guard !state.isEmpty else {
            completion(.failure(.stateRequired))
            return
        }
        
        // Plate-to-VIN lookup requires a commercial API (e.g., ClearVIN, AutoCheck, Plate2VIN).
        // The infrastructure is ready — swap this block with a real API call when a key is available.
        //
        // Example integration point:
        //   let url = URL(string: "https://api.plate2vin.com/lookup?plate=\(cleaned)&state=\(state)&key=YOUR_KEY")!
        //   URLSession.shared.dataTask(with: url) { ... }.resume()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(.failure(.lookupFailed))
        }
    }
    
    /// Validates a US license plate format (basic validation).
    func isValidPlate(_ plate: String) -> Bool {
        let cleaned = plate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count >= 2, cleaned.count <= 8 else { return false }
        
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -"))
        return cleaned.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
    
    static let usStates: [(code: String, name: String)] = [
        ("AL", "Alabama"), ("AK", "Alaska"), ("AZ", "Arizona"), ("AR", "Arkansas"),
        ("CA", "California"), ("CO", "Colorado"), ("CT", "Connecticut"), ("DE", "Delaware"),
        ("FL", "Florida"), ("GA", "Georgia"), ("HI", "Hawaii"), ("ID", "Idaho"),
        ("IL", "Illinois"), ("IN", "Indiana"), ("IA", "Iowa"), ("KS", "Kansas"),
        ("KY", "Kentucky"), ("LA", "Louisiana"), ("ME", "Maine"), ("MD", "Maryland"),
        ("MA", "Massachusetts"), ("MI", "Michigan"), ("MN", "Minnesota"), ("MS", "Mississippi"),
        ("MO", "Missouri"), ("MT", "Montana"), ("NE", "Nebraska"), ("NV", "Nevada"),
        ("NH", "New Hampshire"), ("NJ", "New Jersey"), ("NM", "New Mexico"), ("NY", "New York"),
        ("NC", "North Carolina"), ("ND", "North Dakota"), ("OH", "Ohio"), ("OK", "Oklahoma"),
        ("OR", "Oregon"), ("PA", "Pennsylvania"), ("RI", "Rhode Island"), ("SC", "South Carolina"),
        ("SD", "South Dakota"), ("TN", "Tennessee"), ("TX", "Texas"), ("UT", "Utah"),
        ("VT", "Vermont"), ("VA", "Virginia"), ("WA", "Washington"), ("WV", "West Virginia"),
        ("WI", "Wisconsin"), ("WY", "Wyoming"), ("DC", "Washington D.C.")
    ]
}
