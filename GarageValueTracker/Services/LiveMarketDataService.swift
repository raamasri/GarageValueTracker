import Foundation

class LiveMarketDataService {
    static let shared = LiveMarketDataService()

    private var calibrationCache: [String: CalibrationResult] = [:]
    private let calibrationTTL: TimeInterval = 3600 * 6 // 6 hours

    private init() {}

    // MARK: - Market-Calibrated Valuation

    /// Fetches real listings from Marketcheck and produces a calibration factor
    /// that adjusts the local ValuationEngine estimate toward real market prices.
    func getCalibration(
        make: String,
        model: String,
        year: Int,
        mileage: Int,
        localEstimate: Double
    ) async -> CalibrationResult {
        let cacheKey = "\(make)-\(model)-\(year)".lowercased()

        if let cached = calibrationCache[cacheKey], Date().timeIntervalSince(cached.fetchedAt) < calibrationTTL {
            return cached
        }

        guard MarketCheckService.shared.isConfigured else {
            return CalibrationResult.uncalibrated(localEstimate: localEstimate)
        }

        guard let stats = await MarketCheckService.shared.getMarketStats(make: make, model: model, year: year) else {
            return CalibrationResult.uncalibrated(localEstimate: localEstimate)
        }

        guard stats.medianPrice > 0, localEstimate > 0 else {
            return CalibrationResult.uncalibrated(localEstimate: localEstimate)
        }

        let calibrationFactor = stats.medianPrice / localEstimate

        // Clamp to ±40% to avoid extreme corrections from bad data
        let clamped = max(0.6, min(1.4, calibrationFactor))

        let result = CalibrationResult(
            localEstimate: localEstimate,
            marketMedian: stats.medianPrice,
            marketLow: stats.lowPrice,
            marketHigh: stats.highPrice,
            calibrationFactor: clamped,
            calibratedValue: localEstimate * clamped,
            listingCount: stats.listingCount,
            averageDaysOnMarket: stats.averageDaysOnMarket,
            averageMiles: stats.averageMiles,
            isCalibrated: true,
            fetchedAt: Date()
        )

        calibrationCache[cacheKey] = result
        return result
    }

    // MARK: - Full Market Report

    func getFullMarketReport(
        make: String,
        model: String,
        year: Int,
        mileage: Int,
        trim: String? = nil,
        location: String? = nil
    ) async -> MarketReport {
        let localVal = ValuationEngine.shared.valuate(
            make: make, model: model, year: year,
            mileage: mileage, trim: trim, location: location
        )

        let calibration = await getCalibration(
            make: make, model: model, year: year,
            mileage: mileage, localEstimate: localVal.mid
        )

        var realListings: [MarketCheckListing] = []
        if MarketCheckService.shared.isConfigured {
            realListings = (try? await MarketCheckService.shared.searchActiveListings(
                make: make, model: model, year: year, maxResults: 10
            ).listings) ?? []
        }

        let complaintSummary = await NHTSAComplaintsService.shared.getComplaintSummary(
            make: make, model: model, modelYear: year
        )

        var maintenanceSummary: CarMDMaintenanceSummary? = nil
        if CarMDService.shared.isConfigured {
            maintenanceSummary = await CarMDService.shared.getUpcomingMaintenanceSummary(
                year: year, make: make, model: model, mileage: mileage
            )
        }

        return MarketReport(
            localValuation: localVal,
            calibration: calibration,
            realListings: realListings,
            complaintSummary: complaintSummary,
            maintenanceSummary: maintenanceSummary,
            generatedAt: Date()
        )
    }

    // MARK: - Real Comps for Deal Analysis

    func getRealComps(
        make: String,
        model: String,
        year: Int,
        mileage: Int,
        askingPrice: Double
    ) async -> RealCompsResult {
        guard MarketCheckService.shared.isConfigured else {
            return RealCompsResult(listings: [], stats: nil, isAvailable: false)
        }

        let listings = (try? await MarketCheckService.shared.searchActiveListings(
            make: make, model: model, year: year, maxResults: 15
        ).listings) ?? []

        let stats = await MarketCheckService.shared.getMarketStats(make: make, model: model, year: year)

        return RealCompsResult(
            listings: listings,
            stats: stats,
            isAvailable: true
        )
    }

    func clearAllCaches() {
        calibrationCache.removeAll()
        MarketCheckService.shared.clearCache()
        CarMDService.shared.clearCache()
    }
}

// MARK: - Models

struct CalibrationResult {
    let localEstimate: Double
    let marketMedian: Double?
    let marketLow: Double?
    let marketHigh: Double?
    let calibrationFactor: Double
    let calibratedValue: Double
    let listingCount: Int?
    let averageDaysOnMarket: Int?
    let averageMiles: Int?
    let isCalibrated: Bool
    let fetchedAt: Date

    static func uncalibrated(localEstimate: Double) -> CalibrationResult {
        CalibrationResult(
            localEstimate: localEstimate,
            marketMedian: nil,
            marketLow: nil,
            marketHigh: nil,
            calibrationFactor: 1.0,
            calibratedValue: localEstimate,
            listingCount: nil,
            averageDaysOnMarket: nil,
            averageMiles: nil,
            isCalibrated: false,
            fetchedAt: Date()
        )
    }

    var adjustmentPercent: Double {
        (calibrationFactor - 1.0) * 100
    }
}

struct MarketReport {
    let localValuation: ValuationResult
    let calibration: CalibrationResult
    let realListings: [MarketCheckListing]
    let complaintSummary: ComplaintSummary?
    let maintenanceSummary: CarMDMaintenanceSummary?
    let generatedAt: Date

    var bestEstimate: Double {
        calibration.isCalibrated ? calibration.calibratedValue : localValuation.mid
    }
}

struct RealCompsResult {
    let listings: [MarketCheckListing]
    let stats: MarketStats?
    let isAvailable: Bool
}
