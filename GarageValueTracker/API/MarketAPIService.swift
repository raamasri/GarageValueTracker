import Foundation

class MarketAPIService {
    static let shared = MarketAPIService()
    
    // TODO: Replace with actual backend URL when ready
    private let baseURL = "https://api.yourapp.com"
    private let useMockData = true // Toggle for MVP development
    
    private init() {}
    
    // MARK: - Vehicle Normalization
    
    func normalizeVehicle(_ request: VehicleNormalizeRequest) async throws -> VehicleNormalizeResponse {
        if useMockData {
            return mockNormalizeVehicle(request)
        }
        
        let url = URL(string: "\(baseURL)/v1/vehicles/normalize")!
        return try await post(url: url, body: request)
    }
    
    // MARK: - Valuation Estimate
    
    func getValuationEstimate(_ request: ValuationEstimateRequest) async throws -> ValuationEstimateResponse {
        if useMockData {
            return mockValuationEstimate(request)
        }
        
        let url = URL(string: "\(baseURL)/v1/valuation/estimate")!
        return try await post(url: url, body: request)
    }
    
    // MARK: - P&L Compute
    
    func computePnL(_ request: PnLComputeRequest) async throws -> PnLComputeResponse {
        if useMockData {
            return mockPnLCompute(request)
        }
        
        let url = URL(string: "\(baseURL)/v1/pnl/compute")!
        return try await post(url: url, body: request)
    }
    
    // MARK: - Deal Checker
    
    func checkDeal(_ request: DealCheckRequest) async throws -> DealCheckResponse {
        if useMockData {
            return mockDealCheck(request)
        }
        
        let url = URL(string: "\(baseURL)/v1/deal/check")!
        return try await post(url: url, body: request)
    }
    
    // MARK: - Swap Insight
    
    func getSwapInsight(_ request: SwapInsightRequest) async throws -> SwapInsightResponse {
        if useMockData {
            return mockSwapInsight(request)
        }
        
        let url = URL(string: "\(baseURL)/v1/swap/insight")!
        return try await post(url: url, body: request)
    }
    
    // MARK: - Upgrade Path
    
    func getUpgradePath(_ request: UpgradePathRequest) async throws -> UpgradePathResponse {
        if useMockData {
            return mockUpgradePath(request)
        }
        
        let url = URL(string: "\(baseURL)/v1/upgrade/path")!
        return try await post(url: url, body: request)
    }
    
    // MARK: - Generic POST Helper
    
    private func post<T: Encodable, R: Decodable>(url: URL, body: T) async throws -> R {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(R.self, from: data)
    }
}

// MARK: - Mock Data for MVP Development

extension MarketAPIService {
    private func mockNormalizeVehicle(_ request: VehicleNormalizeRequest) -> VehicleNormalizeResponse {
        // Simulate network delay
        return VehicleNormalizeResponse(
            vehicleId: UUID().uuidString,
            segment: determineSegment(make: request.make, model: request.model),
            mileageBand: determineMileageBand(mileage: request.mileage),
            regionBucket: determineRegionBucket(zip: request.zip)
        )
    }
    
    private func mockValuationEstimate(_ request: ValuationEstimateRequest) -> ValuationEstimateResponse {
        // Generate realistic mock data based on mileage
        let baseMid = 29000.0
        let mileageAdjustment = Double(request.mileage - 30000) * -0.15
        let mid = baseMid + mileageAdjustment
        
        return ValuationEstimateResponse(
            low: mid * 0.93,
            mid: mid,
            high: mid * 1.08,
            confidence: "medium",
            sampleSize: 18,
            momentum90d: -4.1,
            liquidityScore: 0.62,
            recommendation: "hold"
        )
    }
    
    private func mockPnLCompute(_ request: PnLComputeRequest) -> PnLComputeResponse {
        let totalCosts = request.costEntries.reduce(0) { $0 + $1.amount }
        let basis = request.purchasePrice + totalCosts
        let depreciation = request.purchasePrice - request.currentMarketMid
        let unrealizedPnL = request.currentMarketMid - basis
        
        // Calculate months held
        let formatter = ISO8601DateFormatter()
        let purchaseDate = formatter.date(from: request.purchaseDate) ?? Date()
        let monthsHeld = max(1, Calendar.current.dateComponents([.month], from: purchaseDate, to: Date()).month ?? 1)
        
        let avgMonthlyCost = (request.purchasePrice - request.currentMarketMid + totalCosts) / Double(monthsHeld)
        
        return PnLComputeResponse(
            totalCosts: totalCosts,
            basis: basis,
            currentValue: request.currentMarketMid,
            cumulativeDepreciation: depreciation,
            unrealizedPnL: unrealizedPnL,
            avgMonthlyCost: avgMonthlyCost
        )
    }
    
    private func mockDealCheck(_ request: DealCheckRequest) -> DealCheckResponse {
        let mid = 29000.0
        let low = mid * 0.93
        let high = mid * 1.08
        let priceVsMidPct = ((request.askPrice - mid) / mid) * 100
        
        let rating: String
        if request.askPrice < low {
            rating = "under_market"
        } else if request.askPrice > high {
            rating = "over_market"
        } else {
            rating = "fair"
        }
        
        let expectedDOM = priceVsMidPct > 5 ? 28 : (priceVsMidPct > 0 ? 14 : 7)
        let prob7Days = priceVsMidPct > 5 ? 0.12 : (priceVsMidPct > 0 ? 0.35 : 0.72)
        
        let scenarios = [
            PricingScenario(
                label: "Price at -5% vs mid",
                price: mid * 0.95,
                expectedDaysOnMarket: 6,
                probabilityUnder7Days: 0.72,
                estimatedHassleHours: 2,
                hassleHoursSaved: 8
            ),
            PricingScenario(
                label: "Price at mid",
                price: mid,
                expectedDaysOnMarket: 14,
                probabilityUnder7Days: 0.45,
                estimatedHassleHours: 5,
                hassleHoursSaved: 5
            )
        ]
        
        return DealCheckResponse(
            fairValue: FairValueBand(low: low, mid: mid, high: high),
            currentPricing: CurrentPricing(
                askPrice: request.askPrice,
                priceVsMidPct: priceVsMidPct,
                rating: rating
            ),
            sellOutlook: SellOutlook(
                expectedDaysOnMarket: expectedDOM,
                probabilityUnder7Days: prob7Days,
                estimatedHassleHours: Double(expectedDOM) / 7 * request.hassleModel.hoursPerWeekActiveListing
            ),
            scenarios: scenarios
        )
    }
    
    private func mockSwapInsight(_ request: SwapInsightRequest) -> SwapInsightResponse {
        return SwapInsightResponse(
            current: VehicleDepreciationInfo(
                expected3yrDeprPct: 22,
                expected3yrDeprUsd: 6400,
                monthlyCost: 420
            ),
            alt: VehicleDepreciationInfo(
                expected3yrDeprPct: 14,
                expected3yrDeprUsd: 4100,
                monthlyCost: 400
            ),
            verdict: SwapVerdict(
                deprDropPctPoints: 8,
                expectedSavings3yr: 2300,
                monthlyCostDelta: -20
            )
        )
    }
    
    private func mockUpgradePath(_ request: UpgradePathRequest) -> UpgradePathResponse {
        let moves = [
            UpgradeMove(
                targetVehicle: TargetVehicle(
                    year: 2024,
                    make: "Mazda",
                    model: "MX-5 Miata",
                    trim: "Club",
                    msrp: 33770,
                    expectedPrice: 31500
                ),
                netCost12Months: 4200,
                expectedDepreciation: 3100,
                taxAndFees: 2500,
                expectedDiscount: 2270,
                netOutOfPocket: 3700,
                costPerMonthDelta: -45,
                reasoning: "Lower depreciation rate, similar performance class. Expected 12-month cost savings of $540."
            ),
            UpgradeMove(
                targetVehicle: TargetVehicle(
                    year: 2023,
                    make: "Toyota",
                    model: "GR86",
                    trim: "Premium",
                    msrp: 32500,
                    expectedPrice: 29800
                ),
                netCost12Months: 3800,
                expectedDepreciation: 2400,
                taxAndFees: 2350,
                expectedDiscount: 700,
                netOutOfPocket: 2950,
                costPerMonthDelta: -70,
                reasoning: "Best cost optimization. Strong resale value and lower insurance costs."
            ),
            UpgradeMove(
                targetVehicle: TargetVehicle(
                    year: 2024,
                    make: "Volkswagen",
                    model: "Golf R",
                    trim: "Base",
                    msrp: 45000,
                    expectedPrice: 43200
                ),
                netCost12Months: 8900,
                expectedDepreciation: 5200,
                taxAndFees: 3400,
                expectedDiscount: 1800,
                netOutOfPocket: 15700,
                costPerMonthDelta: 155,
                reasoning: "Performance upgrade with practical daily usability. Higher depreciation but strong enthusiast market."
            )
        ]
        
        return UpgradePathResponse(recommendedMoves: moves)
    }
    
    // Helper functions
    private func determineSegment(make: String, model: String) -> String {
        let sportsCars = ["Miata", "MX-5", "GR86", "BRZ", "370Z", "M2"]
        if sportsCars.contains(where: { model.contains($0) }) {
            return "modern_sports_coupe"
        }
        return "general"
    }
    
    private func determineMileageBand(mileage: Int) -> String {
        switch mileage {
        case 0..<15000: return "0-15k"
        case 15000..<30000: return "15k-30k"
        case 30000..<50000: return "30k-50k"
        case 50000..<75000: return "50k-75k"
        default: return "75k+"
        }
    }
    
    private func determineRegionBucket(zip: String) -> String {
        // Simple mock logic - in production would use zip database
        let firstDigit = zip.prefix(1)
        switch firstDigit {
        case "9": return "west_coast"
        case "0", "1", "2": return "northeast"
        case "3", "4": return "southeast"
        default: return "midwest"
        }
    }
}



