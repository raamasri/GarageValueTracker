import Foundation

class KnownIssuesService {
    static let shared = KnownIssuesService()
    
    private var database: KnownIssuesDatabase?
    
    private init() {
        loadDatabase()
    }
    
    private func loadDatabase() {
        guard let url = Bundle.main.url(forResource: "known_issues", withExtension: "json") else {
            print("Could not find known_issues.json")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            database = try JSONDecoder().decode(KnownIssuesDatabase.self, from: data)
        } catch {
            print("Error loading known issues: \(error.localizedDescription)")
        }
    }
    
    func getIssues(make: String, model: String, year: Int) -> [KnownIssue] {
        guard let database = database else { return [] }
        
        let upperMake = make.lowercased()
        let upperModel = model.lowercased()
        
        for entry in database.vehicles {
            if entry.make.lowercased() == upperMake && entry.model.lowercased() == upperModel {
                if year >= entry.yearRange[0] && year <= entry.yearRange[1] {
                    return entry.issues.filter { $0.affectedYears.contains(year) }
                }
            }
        }
        
        return []
    }
    
    func getIssuesByMake(make: String) -> [VehicleKnownIssues] {
        guard let database = database else { return [] }
        return database.vehicles.filter { $0.make.lowercased() == make.lowercased() }
    }
    
    func hasIssues(make: String, model: String, year: Int) -> Bool {
        return !getIssues(make: make, model: model, year: year).isEmpty
    }
    
    func criticalIssueCount(make: String, model: String, year: Int) -> Int {
        return getIssues(make: make, model: model, year: year)
            .filter { $0.severity == "critical" || $0.severity == "severe" }
            .count
    }
}

// MARK: - Data Models

struct KnownIssuesDatabase: Codable {
    let vehicles: [VehicleKnownIssues]
}

struct VehicleKnownIssues: Codable, Identifiable {
    var id: String { "\(make)-\(model)" }
    let make: String
    let model: String
    let yearRange: [Int]
    let issues: [KnownIssue]
}

struct KnownIssue: Codable, Identifiable {
    var id: String { title }
    let title: String
    let severity: String
    let affectedYears: [Int]
    let description: String
    let commonFix: String
    let estimatedCost: String
    let source: String
    
    var severityColor: String {
        switch severity {
        case "critical": return "red"
        case "severe": return "red"
        case "moderate": return "orange"
        case "minor": return "yellow"
        default: return "gray"
        }
    }
}
