import Foundation

class NHTSAComplaintsService {
    static let shared = NHTSAComplaintsService()

    private let baseURL = "https://api.nhtsa.gov/complaints/complaintsByVehicle"
    private var cache: [String: CachedComplaints] = [:]
    private let cacheTTL: TimeInterval = 86400 // 24 hours

    private struct CachedComplaints {
        let complaints: [NHTSAComplaint]
        let fetchedAt: Date
    }

    private init() {}

    func getComplaints(make: String, model: String, modelYear: Int) async throws -> [NHTSAComplaint] {
        let cacheKey = "\(make)-\(model)-\(modelYear)".lowercased()

        if let cached = cache[cacheKey], Date().timeIntervalSince(cached.fetchedAt) < cacheTTL {
            return cached.complaints
        }

        let cleanMake = make.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? make
        let cleanModel = model.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? model

        guard let url = URL(string: "\(baseURL)?make=\(cleanMake)&model=\(cleanModel)&modelYear=\(modelYear)") else {
            throw NHTSAComplaintsError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NHTSAComplaintsError.serverError
        }

        let decoded = try JSONDecoder().decode(NHTSAComplaintsAPIResponse.self, from: data)

        let complaints = decoded.results.compactMap { item -> NHTSAComplaint? in
            guard let component = item.Component, !component.isEmpty else { return nil }
            return NHTSAComplaint(
                odiNumber: item.ODINumber ?? "",
                component: component,
                summary: item.Summary ?? "",
                dateOfIncident: item.DateOfIncident ?? "",
                dateComplaintFiled: item.DateComplaintFiled ?? "",
                crash: item.Crash?.lowercased() == "yes",
                fire: item.Fire?.lowercased() == "yes",
                injuries: item.NumberOfInjuries ?? 0,
                deaths: item.NumberOfDeaths ?? 0
            )
        }

        cache[cacheKey] = CachedComplaints(complaints: complaints, fetchedAt: Date())
        return complaints
    }

    func getComplaintSummary(make: String, model: String, modelYear: Int) async -> ComplaintSummary? {
        guard let complaints = try? await getComplaints(make: make, model: model, modelYear: modelYear) else {
            return nil
        }
        guard !complaints.isEmpty else { return nil }

        var componentCounts: [String: Int] = [:]
        var crashCount = 0
        var fireCount = 0
        var totalInjuries = 0
        var totalDeaths = 0

        for c in complaints {
            let normalized = c.component.components(separatedBy: ":").first?.trimmingCharacters(in: .whitespaces).uppercased() ?? c.component.uppercased()
            componentCounts[normalized, default: 0] += 1
            if c.crash { crashCount += 1 }
            if c.fire { fireCount += 1 }
            totalInjuries += c.injuries
            totalDeaths += c.deaths
        }

        let topComponents = componentCounts.sorted { $0.value > $1.value }.prefix(5).map {
            ComponentComplaintCount(component: $0.key, count: $0.value)
        }

        return ComplaintSummary(
            totalComplaints: complaints.count,
            crashRelated: crashCount,
            fireRelated: fireCount,
            totalInjuries: totalInjuries,
            totalDeaths: totalDeaths,
            topComponents: Array(topComponents)
        )
    }
}

// MARK: - Models

struct NHTSAComplaint: Identifiable {
    var id: String { odiNumber }
    let odiNumber: String
    let component: String
    let summary: String
    let dateOfIncident: String
    let dateComplaintFiled: String
    let crash: Bool
    let fire: Bool
    let injuries: Int
    let deaths: Int

    var severityLevel: String {
        if deaths > 0 { return "critical" }
        if crash || fire { return "severe" }
        if injuries > 0 { return "moderate" }
        return "minor"
    }
}

struct ComplaintSummary {
    let totalComplaints: Int
    let crashRelated: Int
    let fireRelated: Int
    let totalInjuries: Int
    let totalDeaths: Int
    let topComponents: [ComponentComplaintCount]
}

struct ComponentComplaintCount: Identifiable {
    var id: String { component }
    let component: String
    let count: Int
}

// MARK: - API Response

private struct NHTSAComplaintsAPIResponse: Codable {
    let Count: Int
    let results: [NHTSAComplaintItem]
}

private struct NHTSAComplaintItem: Codable {
    let ODINumber: String?
    let Manufacturer: String?
    let Crash: String?
    let Fire: String?
    let NumberOfInjuries: Int?
    let NumberOfDeaths: Int?
    let DateOfIncident: String?
    let DateComplaintFiled: String?
    let VehicleMake: String?
    let VehicleModel: String?
    let VehicleYear: Int?
    let Component: String?
    let Summary: String?
    let ProductType: String?
}

// MARK: - Errors

enum NHTSAComplaintsError: LocalizedError {
    case invalidURL
    case serverError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Could not build complaints request URL."
        case .serverError: return "NHTSA service returned an error."
        }
    }
}
