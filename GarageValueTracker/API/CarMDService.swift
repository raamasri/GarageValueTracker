import Foundation

class CarMDService {
    static let shared = CarMDService()

    private let baseURL = "https://api.carmd.com/v3.0"
    private var maintenanceCache: [String: CachedMaintenance] = [:]
    private let cacheTTL: TimeInterval = 86400 * 7 // 7 days

    private struct CachedMaintenance {
        let items: [CarMDMaintenanceItem]
        let fetchedAt: Date
    }

    private init() {}

    var isConfigured: Bool { APIKeyManager.shared.hasCarMD }

    // MARK: - Build Authenticated Request

    private func makeRequest(url: URL) -> URLRequest? {
        guard let apiKey = APIKeyManager.shared.getKey(for: .carmd),
              let partnerToken = APIKeyManager.shared.getKey(for: .carmdPartner) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("Basic \(apiKey)", forHTTPHeaderField: "authorization")
        request.setValue(partnerToken, forHTTPHeaderField: "partner-token")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    // MARK: - Maintenance Schedule

    func getMaintenanceSchedule(
        year: Int,
        make: String,
        model: String,
        mileage: Int
    ) async throws -> [CarMDMaintenanceItem] {
        let cacheKey = "\(year)-\(make)-\(model)-\(mileage / 5000 * 5000)".lowercased()

        if let cached = maintenanceCache[cacheKey], Date().timeIntervalSince(cached.fetchedAt) < cacheTTL {
            return cached.items
        }

        let cleanMake = make.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? make
        let cleanModel = model.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? model

        guard let url = URL(string: "\(baseURL)/maint?year=\(year)&make=\(cleanMake)&model=\(cleanModel)&mileage=\(mileage)") else {
            throw CarMDError.invalidURL
        }

        guard let request = makeRequest(url: url) else {
            throw CarMDError.noAPIKey
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CarMDError.serverError("No HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw CarMDError.invalidAPIKey
            }
            if httpResponse.statusCode == 429 {
                throw CarMDError.rateLimited
            }
            throw CarMDError.serverError("HTTP \(httpResponse.statusCode)")
        }

        let decoded = try JSONDecoder().decode(CarMDListResponse.self, from: data)

        guard decoded.message.code == 0, let items = decoded.data else {
            throw CarMDError.serverError(decoded.message.message)
        }

        maintenanceCache[cacheKey] = CachedMaintenance(items: items, fetchedAt: Date())
        return items
    }

    // MARK: - Repair Costs by DTC (Diagnostic Trouble Code)

    func getRepairCost(vin: String, mileage: Int, dtc: String) async throws -> [CarMDRepairItem] {
        let cleanDTC = dtc.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? dtc

        guard let url = URL(string: "\(baseURL)/repair?vin=\(vin)&mileage=\(mileage)&dtc=\(cleanDTC)") else {
            throw CarMDError.invalidURL
        }

        guard let request = makeRequest(url: url) else {
            throw CarMDError.noAPIKey
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CarMDError.serverError("Repair lookup failed")
        }

        let decoded = try JSONDecoder().decode(CarMDRepairResponse.self, from: data)
        return decoded.data ?? []
    }

    // MARK: - Upcoming Maintenance Summary

    func getUpcomingMaintenanceSummary(
        year: Int,
        make: String,
        model: String,
        mileage: Int
    ) async -> CarMDMaintenanceSummary? {
        guard let items = try? await getMaintenanceSchedule(year: year, make: make, model: model, mileage: mileage) else {
            return nil
        }
        guard !items.isEmpty else { return nil }

        let totalEstimatedCost = items.compactMap { parseCost($0.total_cost) }.reduce(0, +)
        let upcoming = items.filter { ($0.due_mileage ?? 0) > mileage }.prefix(5)
        let overdue = items.filter { ($0.due_mileage ?? 0) <= mileage && ($0.due_mileage ?? 0) > 0 }

        return CarMDMaintenanceSummary(
            totalItems: items.count,
            upcomingItems: Array(upcoming),
            overdueItems: Array(overdue),
            estimatedTotalCost: totalEstimatedCost,
            fetchedAt: Date()
        )
    }

    private func parseCost(_ costStr: String?) -> Double? {
        guard let str = costStr else { return nil }
        let cleaned = str.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleaned)
    }

    func clearCache() {
        maintenanceCache.removeAll()
    }
}

// MARK: - Models

struct CarMDMaintenanceItem: Codable, Identifiable {
    var id: String { desc ?? UUID().uuidString }
    let desc: String?
    let due_mileage: Int?
    let is_oem: Bool?
    let repair_difficulty: Int?
    let part_cost: String?
    let labor_cost: String?
    let misc_cost: String?
    let total_cost: String?

    var formattedTotalCost: String {
        total_cost ?? "N/A"
    }

    var difficultyLabel: String {
        switch repair_difficulty {
        case 1: return "Easy"
        case 2: return "Moderate"
        case 3: return "Hard"
        default: return "Unknown"
        }
    }
}

struct CarMDRepairItem: Codable, Identifiable {
    var id: String { desc ?? UUID().uuidString }
    let desc: String?
    let labor_cost: Double?
    let part_cost: Double?
    let misc_cost: Double?
    let total_cost: Double?
}

struct CarMDMaintenanceSummary {
    let totalItems: Int
    let upcomingItems: [CarMDMaintenanceItem]
    let overdueItems: [CarMDMaintenanceItem]
    let estimatedTotalCost: Double
    let fetchedAt: Date
}

// MARK: - API Responses

private struct CarMDListResponse: Codable {
    let message: CarMDMessage
    let data: [CarMDMaintenanceItem]?
}

private struct CarMDRepairResponse: Codable {
    let message: CarMDMessage
    let data: [CarMDRepairItem]?
}

private struct CarMDMessage: Codable {
    let code: Int
    let message: String
    let credentials: String?
    let version: String?
}

// MARK: - Errors

enum CarMDError: LocalizedError {
    case noAPIKey
    case invalidAPIKey
    case invalidURL
    case rateLimited
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "CarMD API key not configured. Add it in Settings > API Keys."
        case .invalidAPIKey: return "CarMD API key is invalid. Check your key in Settings > API Keys."
        case .invalidURL: return "Could not build CarMD request URL."
        case .rateLimited: return "CarMD rate limit reached."
        case .serverError(let detail): return "CarMD error: \(detail)"
        }
    }
}
