import Foundation

class MarketCheckService {
    static let shared = MarketCheckService()

    private let baseURL = "https://mc-api.marketcheck.com/v2"
    private var cache: [String: CachedListings] = [:]
    private let cacheTTL: TimeInterval = 3600 // 1 hour

    private struct CachedListings {
        let listings: [MarketCheckListing]
        let totalFound: Int
        let fetchedAt: Date
    }

    private init() {}

    var isConfigured: Bool { APIKeyManager.shared.hasMarketcheck }

    // MARK: - Search Active Listings

    func searchActiveListings(
        make: String,
        model: String,
        year: Int,
        zipCode: String? = nil,
        radius: Int = 100,
        maxResults: Int = 10
    ) async throws -> MarketCheckSearchResult {
        guard let apiKey = APIKeyManager.shared.getKey(for: .marketcheck) else {
            throw MarketCheckError.noAPIKey
        }

        let cacheKey = "\(make)-\(model)-\(year)-\(zipCode ?? "any")-\(radius)".lowercased()

        if let cached = cache[cacheKey], Date().timeIntervalSince(cached.fetchedAt) < cacheTTL {
            return MarketCheckSearchResult(
                listings: cached.listings,
                totalFound: cached.totalFound,
                source: .cache
            )
        }

        var components = URLComponents(string: "\(baseURL)/search/car/active")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "make", value: make),
            URLQueryItem(name: "model", value: model),
            URLQueryItem(name: "year", value: "\(year)"),
            URLQueryItem(name: "rows", value: "\(maxResults)"),
            URLQueryItem(name: "sort_by", value: "price"),
            URLQueryItem(name: "sort_order", value: "asc")
        ]

        if let zip = zipCode, !zip.isEmpty {
            queryItems.append(URLQueryItem(name: "zip", value: zip))
            queryItems.append(URLQueryItem(name: "radius", value: "\(radius)"))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw MarketCheckError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MarketCheckError.serverError("No HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw MarketCheckError.invalidAPIKey
            }
            if httpResponse.statusCode == 429 {
                throw MarketCheckError.rateLimited
            }
            throw MarketCheckError.serverError("HTTP \(httpResponse.statusCode)")
        }

        let decoded = try JSONDecoder().decode(MarketCheckAPIResponse.self, from: data)
        let listings = decoded.listings ?? []
        let totalFound = decoded.num_found ?? listings.count

        cache[cacheKey] = CachedListings(listings: listings, totalFound: totalFound, fetchedAt: Date())

        return MarketCheckSearchResult(
            listings: listings,
            totalFound: totalFound,
            source: .live
        )
    }

    // MARK: - Market Statistics

    func getMarketStats(make: String, model: String, year: Int) async -> MarketStats? {
        guard let result = try? await searchActiveListings(make: make, model: model, year: year, maxResults: 50) else {
            return nil
        }

        let listings = result.listings
        guard !listings.isEmpty else { return nil }

        let prices = listings.compactMap { $0.price }.filter { $0 > 0 }
        let miles = listings.compactMap { $0.miles }.filter { $0 > 0 }
        let doms = listings.compactMap { $0.dom }.filter { $0 >= 0 }

        guard !prices.isEmpty else { return nil }

        let sortedPrices = prices.sorted()
        let medianPrice = sortedPrices[sortedPrices.count / 2]
        let avgPrice = prices.reduce(0.0, +) / Double(prices.count)
        let lowPrice = sortedPrices[max(0, Int(Double(sortedPrices.count) * 0.1))]
        let highPrice = sortedPrices[min(sortedPrices.count - 1, Int(Double(sortedPrices.count) * 0.9))]

        let avgMiles = miles.isEmpty ? nil : miles.reduce(0, +) / miles.count
        let avgDOM = doms.isEmpty ? nil : doms.reduce(0, +) / doms.count

        return MarketStats(
            listingCount: result.totalFound,
            medianPrice: medianPrice,
            averagePrice: avgPrice,
            lowPrice: lowPrice,
            highPrice: highPrice,
            averageMiles: avgMiles,
            averageDaysOnMarket: avgDOM,
            fetchedAt: Date()
        )
    }

    func clearCache() {
        cache.removeAll()
    }
}

// MARK: - Models

struct MarketCheckSearchResult {
    let listings: [MarketCheckListing]
    let totalFound: Int
    let source: DataSource

    enum DataSource {
        case live, cache
    }
}

struct MarketCheckListing: Codable, Identifiable {
    var id: String { vin ?? UUID().uuidString }
    let price: Double?
    let miles: Int?
    let dealer: MarketCheckDealer?
    let dom: Int?
    let exterior_color: String?
    let interior_color: String?
    let vdp_url: String?
    let source: String?
    let heading: String?
    let vin: String?
    let year: Int?
    let make: String?
    let model: String?
    let trim: String?
    let body_type: String?

    var formattedPrice: String {
        guard let p = price else { return "N/A" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: p)) ?? "$\(Int(p))"
    }

    var formattedMiles: String {
        guard let m = miles else { return "N/A" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: m)) ?? "\(m)") + " mi"
    }
}

struct MarketCheckDealer: Codable {
    let id: Int?
    let name: String?
    let city: String?
    let state: String?
    let zip: String?

    var locationString: String {
        [city, state].compactMap { $0 }.joined(separator: ", ")
    }
}

struct MarketStats {
    let listingCount: Int
    let medianPrice: Double
    let averagePrice: Double
    let lowPrice: Double
    let highPrice: Double
    let averageMiles: Int?
    let averageDaysOnMarket: Int?
    let fetchedAt: Date
}

// MARK: - API Response

private struct MarketCheckAPIResponse: Codable {
    let num_found: Int?
    let listings: [MarketCheckListing]?
}

// MARK: - Errors

enum MarketCheckError: LocalizedError {
    case noAPIKey
    case invalidAPIKey
    case invalidURL
    case rateLimited
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "Marketcheck API key not configured. Add it in Settings > API Keys."
        case .invalidAPIKey: return "Marketcheck API key is invalid. Check your key in Settings > API Keys."
        case .invalidURL: return "Could not build Marketcheck request URL."
        case .rateLimited: return "Marketcheck rate limit reached. Free tier allows ~1,000 calls/month."
        case .serverError(let detail): return "Marketcheck error: \(detail)"
        }
    }
}
