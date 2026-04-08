import Foundation

class ValuationEngine {
    static let shared = ValuationEngine()
    
    private var segmentCurves: [String: SegmentCurveData] = [:]
    private var holdValueModels: [String] = []
    private var holdValueMultiplier: Double = 0.70
    
    private init() {
        loadCurves()
    }
    
    // MARK: - Condition Tiers
    
    enum ConditionTier: String, CaseIterable, Codable {
        case concours = "concours"
        case excellent = "excellent"
        case good = "good"
        case driver = "driver"
        case project = "project"
        
        var displayName: String {
            switch self {
            case .concours: return "Concours"
            case .excellent: return "Excellent"
            case .good: return "Good"
            case .driver: return "Driver"
            case .project: return "Project"
            }
        }
        
        var sortOrder: Int {
            switch self {
            case .concours: return 0
            case .excellent: return 1
            case .good: return 2
            case .driver: return 3
            case .project: return 4
            }
        }
    }
    
    // MARK: - Main Valuation
    
    func valuate(make: String, model: String, year: Int, mileage: Int, trim: String? = nil, msrp: Double? = nil, location: String? = nil, condition: ConditionTier = .good) -> ValuationResult {
        let baseMSRP = resolveBaseMSRP(make: make, model: model, year: year, trim: trim, providedMSRP: msrp)
        let segment = LocationMarketService.shared.classifyVehicle(make: make, model: model)
        let curveData = segmentCurves[segment] ?? segmentCurves["sedan"]!
        
        let currentYear = Calendar.current.component(.year, from: Date())
        let age = max(currentYear - year, 0)
        
        var depreciatedValue = baseMSRP
        for yr in 0..<age {
            let rate = depreciationRate(forYear: yr + 1, curve: curveData.depreciationCurve)
            let adjustedRate = isHoldValueModel(model) ? rate * holdValueMultiplier : rate
            depreciatedValue *= (1.0 - adjustedRate)
        }
        
        let mileagePenalty = curveData.mileagePenalty
        let expectedMiles = age * mileagePenalty.averageAnnualMiles
        let mileageDelta = mileage - expectedMiles
        let mileageAdjustment: Double
        if mileageDelta > 0 {
            mileageAdjustment = -Double(mileageDelta) / 1000.0 * mileagePenalty.perThousandOver * baseMSRP
        } else {
            mileageAdjustment = -Double(mileageDelta) / 1000.0 * mileagePenalty.perThousandUnder * baseMSRP
        }
        depreciatedValue += mileageAdjustment
        depreciatedValue = max(depreciatedValue, baseMSRP * 0.03)
        
        let conditionMultiplier = curveData.conditionMultipliers[condition.rawValue] ?? 1.0
        let conditionedValue = depreciatedValue * conditionMultiplier
        
        let seasonalFactor = currentSeasonalFactor(curve: curveData)
        let seasonalValue = conditionedValue * seasonalFactor
        
        var finalValue = seasonalValue
        if let location = location, !location.isEmpty {
            let locationMultiplier = LocationMarketService.shared.getDemandMultiplier(
                location: location, make: make, model: model
            )
            finalValue *= locationMultiplier
        }
        
        let spread = curveData.volatilityBase / 100.0
        let midValue = max(finalValue, 500)
        let lowValue = max(midValue * (1.0 - spread * 0.6), 500)
        let highValue = midValue * (1.0 + spread * 0.6)
        
        let confidence = calculateConfidence(age: age, segment: segment, mileage: mileage, threshold: mileagePenalty.highMileageThreshold)
        
        return ValuationResult(
            low: lowValue,
            mid: midValue,
            high: highValue,
            confidence: confidence,
            segment: segment,
            condition: condition,
            seasonalFactor: seasonalFactor,
            mileageAdjustmentPercent: baseMSRP > 0 ? (mileageAdjustment / baseMSRP) * 100 : 0,
            baseMSRP: baseMSRP,
            lastUpdated: Date()
        )
    }
    
    func valuateAllConditions(make: String, model: String, year: Int, mileage: Int, trim: String? = nil, msrp: Double? = nil, location: String? = nil) -> [ConditionTier: ValuationResult] {
        var results: [ConditionTier: ValuationResult] = [:]
        for tier in ConditionTier.allCases {
            results[tier] = valuate(make: make, model: model, year: year, mileage: mileage, trim: trim, msrp: msrp, location: location, condition: tier)
        }
        return results
    }
    
    func estimatedDaysOnMarket(segment: String, priceVsMarket: Double) -> ClosedRange<Int> {
        let curveData = segmentCurves[segment] ?? segmentCurves["sedan"]!
        let baseDays = curveData.averageDaysOnMarket
        
        let multiplier: Double
        if priceVsMarket < -10 {
            multiplier = 0.5
        } else if priceVsMarket < -5 {
            multiplier = 0.7
        } else if priceVsMarket < 5 {
            multiplier = 1.0
        } else if priceVsMarket < 10 {
            multiplier = 1.4
        } else {
            multiplier = 2.0
        }
        
        let estimated = Int(Double(baseDays) * multiplier)
        let low = max(estimated - Int(Double(estimated) * 0.3), 3)
        let high = estimated + Int(Double(estimated) * 0.3)
        return low...high
    }
    
    func projectValue(currentValue: Double, make: String, model: String, segment: String, months: Int) -> [ProjectedValue] {
        let curveData = segmentCurves[segment] ?? segmentCurves["sedan"]!
        let monthlyRate = depreciationRate(forYear: 3, curve: curveData.depreciationCurve) / 12.0
        let adjustedRate = isHoldValueModel(model) ? monthlyRate * holdValueMultiplier : monthlyRate
        
        var values: [ProjectedValue] = []
        var value = currentValue
        
        for m in 0...months {
            let date = Calendar.current.date(byAdding: .month, value: m, to: Date()) ?? Date()
            values.append(ProjectedValue(monthsFromNow: m, date: date, value: value))
            value *= (1.0 - adjustedRate)
        }
        return values
    }
    
    func generateSyntheticComps(make: String, model: String, year: Int, mileage: Int, trim: String? = nil, msrp: Double? = nil, location: String? = nil, count: Int = 5) -> [SyntheticComp] {
        var comps: [SyntheticComp] = []
        let conditions: [ConditionTier] = [.excellent, .good, .good, .driver, .driver]
        let mileageVariations = [-15000, -5000, 2000, 10000, 20000]
        
        let seedBase = "\(make)-\(model)-\(year)-\(mileage)".hashValue
        var rng = SeededRandomNumberGenerator(seed: UInt64(bitPattern: Int64(seedBase)))
        
        for i in 0..<min(count, conditions.count) {
            let compMileage = max(mileage + mileageVariations[i], 1000)
            let result = valuate(make: make, model: model, year: year, mileage: compMileage, trim: trim, msrp: msrp, location: location, condition: conditions[i])
            
            let daysAgo = Int.random(in: 7...90, using: &rng)
            let soldDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            
            comps.append(SyntheticComp(
                price: result.mid * Double.random(in: 0.95...1.05, using: &rng),
                mileage: compMileage,
                condition: conditions[i],
                soldDate: soldDate,
                source: ["Private Party", "Dealer", "Auction"][Int.random(in: 0...2, using: &rng)]
            ))
        }
        
        return comps.sorted { $0.soldDate > $1.soldDate }
    }
    
    // MARK: - Private Helpers
    
    private func depreciationRate(forYear year: Int, curve: DepreciationCurve) -> Double {
        switch year {
        case 1: return curve.year1
        case 2: return curve.year2
        case 3: return curve.year3
        case 4: return curve.year4
        case 5: return curve.year5
        case 6: return curve.year6
        case 7: return curve.year7
        case 8: return curve.year8
        case 9: return curve.year9
        default: return curve.year10plus
        }
    }
    
    private func isHoldValueModel(_ model: String) -> Bool {
        let upper = model.uppercased()
        return holdValueModels.contains { upper.contains($0.uppercased()) }
    }
    
    private func currentSeasonalFactor(curve: SegmentCurveData) -> Double {
        let month = Calendar.current.component(.month, from: Date())
        let keys = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        guard month >= 1 && month <= 12 else { return 1.0 }
        return curve.seasonalFactors[keys[month - 1]] ?? 1.0
    }
    
    private func calculateConfidence(age: Int, segment: String, mileage: Int, threshold: Int) -> Double {
        var confidence = 0.75
        
        if age <= 5 { confidence += 0.10 }
        else if age <= 10 { confidence += 0.05 }
        else { confidence -= 0.10 }
        
        if ["sedan", "suv", "truck"].contains(segment) { confidence += 0.05 }
        if segment == "exotic" { confidence -= 0.15 }
        
        if mileage > threshold { confidence -= 0.05 }
        
        return max(min(confidence, 0.95), 0.30)
    }
    
    private func resolveBaseMSRP(make: String, model: String, year: Int, trim: String?, providedMSRP: Double?) -> Double {
        if let msrp = providedMSRP, msrp > 0 { return msrp }
        
        let trims = TrimDatabaseService.shared.getTrims(make: make, model: model, year: year)
        if let trim = trim, let match = trims.first(where: { $0.trimLevel == trim }) {
            return match.msrp
        }
        if let midTrim = trims.sorted(by: { $0.msrp < $1.msrp }).dropFirst(trims.count / 2).first {
            return midTrim.msrp
        }
        
        return MarketAPIService.shared.estimateMSRPForMake(make)
    }
    
    // MARK: - Data Loading
    
    private func loadCurves() {
        guard let url = Bundle.main.url(forResource: "valuation_curves", withExtension: "json") else {
            loadDefaults()
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(ValuationCurvesFile.self, from: data)
            self.segmentCurves = decoded.segments
            self.holdValueModels = decoded.holdValueModels
            self.holdValueMultiplier = decoded.holdValueMultiplier
        } catch {
            print("Error loading valuation curves: \(error)")
            loadDefaults()
        }
    }
    
    private func loadDefaults() {
        let defaultCurve = DepreciationCurve(year1: 0.20, year2: 0.14, year3: 0.12, year4: 0.10, year5: 0.09, year6: 0.08, year7: 0.07, year8: 0.06, year9: 0.05, year10plus: 0.04)
        let defaultMileage = MileagePenaltyData(perThousandOver: 0.006, perThousandUnder: 0.003, averageAnnualMiles: 12000, highMileageThreshold: 100000)
        let defaultSeasonal: [String: Double] = ["jan": 1.0, "feb": 1.0, "mar": 1.0, "apr": 1.0, "may": 1.0, "jun": 1.0, "jul": 1.0, "aug": 1.0, "sep": 1.0, "oct": 1.0, "nov": 1.0, "dec": 1.0]
        let defaultCondition: [String: Double] = ["concours": 1.25, "excellent": 1.12, "good": 1.0, "driver": 0.85, "project": 0.50]
        
        let defaultSegment = SegmentCurveData(depreciationCurve: defaultCurve, mileagePenalty: defaultMileage, seasonalFactors: defaultSeasonal, conditionMultipliers: defaultCondition, averageDaysOnMarket: 30, volatilityBase: 35)
        
        segmentCurves = ["sedan": defaultSegment, "suv": defaultSegment, "truck": defaultSegment, "sports": defaultSegment, "ev": defaultSegment, "luxury": defaultSegment, "exotic": defaultSegment]
    }
}

// MARK: - Result Types

struct ValuationResult {
    let low: Double
    let mid: Double
    let high: Double
    let confidence: Double
    let segment: String
    let condition: ValuationEngine.ConditionTier
    let seasonalFactor: Double
    let mileageAdjustmentPercent: Double
    let baseMSRP: Double
    let lastUpdated: Date
    
    var spreadPercent: Double {
        guard mid > 0 else { return 0 }
        return ((high - low) / mid) * 100
    }
    
    var confidenceLabel: String {
        if confidence >= 0.80 { return "High" }
        if confidence >= 0.60 { return "Medium" }
        return "Low"
    }
}

struct SyntheticComp: Identifiable {
    let id = UUID()
    let price: Double
    let mileage: Int
    let condition: ValuationEngine.ConditionTier
    let soldDate: Date
    let source: String
}

// MARK: - JSON Decodable Structures

private struct ValuationCurvesFile: Codable {
    let segments: [String: SegmentCurveData]
    let holdValueModels: [String]
    let holdValueMultiplier: Double
}

struct SegmentCurveData: Codable {
    let depreciationCurve: DepreciationCurve
    let mileagePenalty: MileagePenaltyData
    let seasonalFactors: [String: Double]
    let conditionMultipliers: [String: Double]
    let averageDaysOnMarket: Int
    let volatilityBase: Double
}

struct DepreciationCurve: Codable {
    let year1: Double
    let year2: Double
    let year3: Double
    let year4: Double
    let year5: Double
    let year6: Double
    let year7: Double
    let year8: Double
    let year9: Double
    let year10plus: Double
}

struct MileagePenaltyData: Codable {
    let perThousandOver: Double
    let perThousandUnder: Double
    let averageAnnualMiles: Int
    let highMileageThreshold: Int
}

struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: UInt64) {
        state = seed == 0 ? 1 : seed
    }
    
    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}
