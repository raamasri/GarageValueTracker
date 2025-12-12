import Foundation

// MARK: - NHTSA VIN Decode Response
struct NHTSAVINDecodeResponse: Codable {
    let results: [NHTSAVehicleResult]
    
    enum CodingKeys: String, CodingKey {
        case results = "Results"
    }
}

struct NHTSAVehicleResult: Codable {
    let make: String?
    let model: String?
    let modelYear: String?
    let trim: String?
    let vehicleType: String?
    let bodyClass: String?
    let errorCode: String?
    
    enum CodingKeys: String, CodingKey {
        case make = "Make"
        case model = "Model"
        case modelYear = "ModelYear"
        case trim = "Trim"
        case vehicleType = "VehicleType"
        case bodyClass = "BodyClass"
        case errorCode = "ErrorCode"
    }
}

// MARK: - Market API Models

struct VehicleNormalizeRequest: Codable {
    let vin: String?
    let year: Int
    let make: String
    let model: String
    let trim: String
    let transmission: String
    let mileage: Int
    let zip: String
}

struct VehicleNormalizeResponse: Codable {
    let vehicleId: String
    let segment: String
    let mileageBand: String
    let regionBucket: String
    
    enum CodingKeys: String, CodingKey {
        case vehicleId = "vehicle_id"
        case segment
        case mileageBand = "mileage_band"
        case regionBucket = "region_bucket"
    }
}

struct ValuationEstimateRequest: Codable {
    let vehicleId: String
    let mileage: Int
    let zip: String
    
    enum CodingKeys: String, CodingKey {
        case vehicleId = "vehicle_id"
        case mileage
        case zip
    }
}

struct ValuationEstimateResponse: Codable {
    let low: Double
    let mid: Double
    let high: Double
    let confidence: String
    let sampleSize: Int
    let momentum90d: Double
    let liquidityScore: Double
    let recommendation: String
    
    enum CodingKeys: String, CodingKey {
        case low, mid, high, confidence
        case sampleSize = "sample_size"
        case momentum90d = "momentum_90d"
        case liquidityScore = "liquidity_score"
        case recommendation
    }
}

struct CostEntryData: Codable {
    let date: String
    let category: String
    let amount: Double
}

struct PnLComputeRequest: Codable {
    let vehicleId: String
    let purchasePrice: Double
    let purchaseDate: String
    let costEntries: [CostEntryData]
    let currentMarketMid: Double
    
    enum CodingKeys: String, CodingKey {
        case vehicleId = "vehicle_id"
        case purchasePrice = "purchase_price"
        case purchaseDate = "purchase_date"
        case costEntries = "cost_entries"
        case currentMarketMid = "current_market_mid"
    }
}

struct PnLComputeResponse: Codable {
    let totalCosts: Double
    let basis: Double
    let currentValue: Double
    let cumulativeDepreciation: Double
    let unrealizedPnL: Double
    let avgMonthlyCost: Double
    
    enum CodingKeys: String, CodingKey {
        case totalCosts = "total_costs"
        case basis
        case currentValue = "current_value"
        case cumulativeDepreciation = "cumulative_depreciation"
        case unrealizedPnL = "unrealized_pnl"
        case avgMonthlyCost = "avg_monthly_cost"
    }
}

struct HassleModel: Codable {
    let hoursPerWeekActiveListing: Double
    let hoursPerTestDrive: Double
    let hoursPerPriceChange: Double
    
    enum CodingKeys: String, CodingKey {
        case hoursPerWeekActiveListing = "hours_per_week_active_listing"
        case hoursPerTestDrive = "hours_per_test_drive"
        case hoursPerPriceChange = "hours_per_price_change"
    }
}

struct DealCheckRequest: Codable {
    let vehicleId: String
    let mileage: Int
    let zip: String
    let askPrice: Double
    let hassleModel: HassleModel
    
    enum CodingKeys: String, CodingKey {
        case vehicleId = "vehicle_id"
        case mileage
        case zip
        case askPrice = "ask_price"
        case hassleModel = "hassle_model"
    }
}

struct DealCheckResponse: Codable {
    let fairValue: FairValueBand
    let currentPricing: CurrentPricing
    let sellOutlook: SellOutlook
    let scenarios: [PricingScenario]
    
    enum CodingKeys: String, CodingKey {
        case fairValue = "fair_value"
        case currentPricing = "current_pricing"
        case sellOutlook = "sell_outlook"
        case scenarios
    }
}

struct FairValueBand: Codable {
    let low: Double
    let mid: Double
    let high: Double
}

struct CurrentPricing: Codable {
    let askPrice: Double
    let priceVsMidPct: Double
    let rating: String
    
    enum CodingKeys: String, CodingKey {
        case askPrice = "ask_price"
        case priceVsMidPct = "price_vs_mid_pct"
        case rating
    }
}

struct SellOutlook: Codable {
    let expectedDaysOnMarket: Int
    let probabilityUnder7Days: Double
    let estimatedHassleHours: Double
    
    enum CodingKeys: String, CodingKey {
        case expectedDaysOnMarket = "expected_days_on_market"
        case probabilityUnder7Days = "probability_under_7_days"
        case estimatedHassleHours = "estimated_hassle_hours"
    }
}

struct PricingScenario: Codable {
    let label: String
    let price: Double
    let expectedDaysOnMarket: Int
    let probabilityUnder7Days: Double
    let estimatedHassleHours: Double
    let hassleHoursSaved: Double
    
    enum CodingKeys: String, CodingKey {
        case label
        case price
        case expectedDaysOnMarket = "expected_days_on_market"
        case probabilityUnder7Days = "probability_under_7_days"
        case estimatedHassleHours = "estimated_hassle_hours"
        case hassleHoursSaved = "hassle_hours_saved"
    }
}

struct SwapInsightRequest: Codable {
    let currentVehicleId: String
    let altVehicleId: String
    let currentMarketMid: Double
    let altEntryPrice: Double
    let regionBucket: String
    
    enum CodingKeys: String, CodingKey {
        case currentVehicleId = "current_vehicle_id"
        case altVehicleId = "alt_vehicle_id"
        case currentMarketMid = "current_market_mid"
        case altEntryPrice = "alt_entry_price"
        case regionBucket = "region_bucket"
    }
}

struct SwapInsightResponse: Codable {
    let current: VehicleDepreciationInfo
    let alt: VehicleDepreciationInfo
    let verdict: SwapVerdict
}

struct VehicleDepreciationInfo: Codable {
    let expected3yrDeprPct: Double
    let expected3yrDeprUsd: Double
    let monthlyCost: Double
    
    enum CodingKeys: String, CodingKey {
        case expected3yrDeprPct = "expected_3yr_depr_pct"
        case expected3yrDeprUsd = "expected_3yr_depr_usd"
        case monthlyCost = "monthly_cost"
    }
}

struct SwapVerdict: Codable {
    let deprDropPctPoints: Double
    let expectedSavings3yr: Double
    let monthlyCostDelta: Double
    
    enum CodingKeys: String, CodingKey {
        case deprDropPctPoints = "depr_drop_pct_points"
        case expectedSavings3yr = "expected_savings_3yr"
        case monthlyCostDelta = "monthly_cost_delta"
    }
}

// MARK: - Upgrade Path Models
struct UpgradePathRequest: Codable {
    let currentVehicleId: String
    let currentMarketMid: Double
    let targetBudget: Double?
    let timeframe: Int // months
    let annualMileage: Int
    let regionBucket: String
    
    enum CodingKeys: String, CodingKey {
        case currentVehicleId = "current_vehicle_id"
        case currentMarketMid = "current_market_mid"
        case targetBudget = "target_budget"
        case timeframe
        case annualMileage = "annual_mileage"
        case regionBucket = "region_bucket"
    }
}

struct UpgradePathResponse: Codable {
    let recommendedMoves: [UpgradeMove]
}

struct UpgradeMove: Codable {
    let targetVehicle: TargetVehicle
    let netCost12Months: Double
    let expectedDepreciation: Double
    let taxAndFees: Double
    let expectedDiscount: Double
    let netOutOfPocket: Double
    let costPerMonthDelta: Double
    let reasoning: String
    
    enum CodingKeys: String, CodingKey {
        case targetVehicle = "target_vehicle"
        case netCost12Months = "net_cost_12_months"
        case expectedDepreciation = "expected_depreciation"
        case taxAndFees = "tax_and_fees"
        case expectedDiscount = "expected_discount"
        case netOutOfPocket = "net_out_of_pocket"
        case costPerMonthDelta = "cost_per_month_delta"
        case reasoning
    }
}

struct TargetVehicle: Codable {
    let year: Int
    let make: String
    let model: String
    let trim: String
    let msrp: Double
    let expectedPrice: Double
}



