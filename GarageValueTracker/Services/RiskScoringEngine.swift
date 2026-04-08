import Foundation

class RiskScoringEngine {
    static let shared = RiskScoringEngine()
    
    private var segmentProfiles: [String: SegmentProfile] = [:]
    
    private init() {
        loadProfiles()
    }
    
    // MARK: - Risk Score for a Vehicle
    
    func score(make: String, model: String, year: Int, mileage: Int, segment: String, condition: ValuationEngine.ConditionTier = .good) -> RiskScore {
        let profile = segmentProfiles[segment]
        let valuation = ValuationEngine.shared.valuateAllConditions(
            make: make, model: model, year: year, mileage: mileage
        )
        
        let volatility = calculateVolatility(valuation: valuation, profile: profile, segment: segment)
        let liquidity = calculateLiquidity(profile: profile, segment: segment, year: year)
        let cyclicality = profile?.cyclicalityScore ?? 40
        let provenance = profile?.provenancePremium ?? 30
        
        let overallRisk = Int(Double(volatility + liquidity + cyclicality + provenance) / 4.0)
        
        return RiskScore(
            volatility: volatility,
            liquidity: liquidity,
            cyclicality: cyclicality,
            provenancePremium: provenance,
            overallRisk: overallRisk,
            segment: segment
        )
    }
    
    func scoreVehicle(_ vehicle: VehicleEntity) -> RiskScore {
        score(
            make: vehicle.make, model: vehicle.model,
            year: Int(vehicle.year), mileage: Int(vehicle.mileage),
            segment: vehicle.resolvedSegment, condition: vehicle.conditionTier
        )
    }
    
    // MARK: - Portfolio Risk
    
    func portfolioRisk(vehicles: [VehicleEntity]) -> PortfolioRisk {
        guard !vehicles.isEmpty else {
            return PortfolioRisk(
                averageRisk: RiskScore(volatility: 0, liquidity: 0, cyclicality: 0, provenancePremium: 0, overallRisk: 0, segment: ""),
                concentrationRisk: 0,
                segmentBreakdown: [:],
                diversificationScore: 0
            )
        }
        
        let scores = vehicles.map { scoreVehicle($0) }
        
        let avgVolatility = scores.map(\.volatility).reduce(0, +) / scores.count
        let avgLiquidity = scores.map(\.liquidity).reduce(0, +) / scores.count
        let avgCyclicality = scores.map(\.cyclicality).reduce(0, +) / scores.count
        let avgProvenance = scores.map(\.provenancePremium).reduce(0, +) / scores.count
        let avgOverall = (avgVolatility + avgLiquidity + avgCyclicality + avgProvenance) / 4
        
        var segmentBreakdown: [String: Int] = [:]
        for v in vehicles {
            segmentBreakdown[v.resolvedSegment, default: 0] += 1
        }
        
        let maxConcentration = segmentBreakdown.values.max() ?? 0
        let concentrationRisk = vehicles.count > 1 ? Int(Double(maxConcentration) / Double(vehicles.count) * 100) : 100
        
        let uniqueSegments = segmentBreakdown.keys.count
        let diversificationScore = min(uniqueSegments * 20, 100)
        
        return PortfolioRisk(
            averageRisk: RiskScore(
                volatility: avgVolatility, liquidity: avgLiquidity,
                cyclicality: avgCyclicality, provenancePremium: avgProvenance,
                overallRisk: avgOverall, segment: "portfolio"
            ),
            concentrationRisk: concentrationRisk,
            segmentBreakdown: segmentBreakdown,
            diversificationScore: diversificationScore
        )
    }
    
    // MARK: - Scenario Modeling
    
    func runScenario(vehicle: VehicleEntity, type: ScenarioType, parameters: ScenarioParameters) -> ScenarioResult {
        let segment = vehicle.resolvedSegment
        let profile = segmentProfiles[segment]
        let currentValue = vehicle.currentValue > 0 ? vehicle.currentValue :
            ValuationEngine.shared.valuate(
                make: vehicle.make, model: vehicle.model,
                year: Int(vehicle.year), mileage: Int(vehicle.mileage)
            ).mid
        
        let annualRate: Double
        switch type {
        case .bull:
            let peakMultiplier = profile?.peakMultiplier ?? 1.20
            annualRate = (peakMultiplier - 1.0) / 2.0
        case .bear:
            let troughMultiplier = profile?.troughMultiplier ?? 0.80
            annualRate = (troughMultiplier - 1.0) / 2.0
        case .hold:
            let projected = ValuationEngine.shared.projectValue(
                currentValue: currentValue, make: vehicle.make,
                model: vehicle.model, segment: segment, months: 12
            )
            let oneYearValue = projected.last?.value ?? currentValue
            annualRate = (oneYearValue - currentValue) / currentValue
        case .custom:
            if let appreciation = parameters.annualAppreciationRate {
                annualRate = appreciation / 100.0
            } else if let depreciation = parameters.annualDepreciationRate {
                annualRate = -(depreciation / 100.0)
            } else {
                annualRate = -0.10
            }
        }
        
        var projectedValues: [ScenarioProjectedValue] = []
        var value = currentValue
        var cumulativeCosts = 0.0
        let purchasePrice = vehicle.purchasePrice
        
        for year in 0...parameters.yearsToProject {
            let yearCosts = Double(year) > 0 ?
                parameters.annualMaintenanceCost + parameters.annualInsuranceCost : 0
            cumulativeCosts += yearCosts
            
            projectedValues.append(ScenarioProjectedValue(
                year: year,
                projectedValue: value,
                cumulativeCosts: cumulativeCosts,
                netEquity: value - purchasePrice - cumulativeCosts
            ))
            
            value *= (1.0 + annualRate)
        }
        
        let finalValue = projectedValues.last?.projectedValue ?? currentValue
        let netEquityChange = finalValue - currentValue - cumulativeCosts
        let years = Double(parameters.yearsToProject)
        let annualizedReturn = years > 0 ? (pow(finalValue / currentValue, 1.0 / years) - 1.0) * 100 : 0
        
        return ScenarioResult(
            projectedValues: projectedValues,
            totalCostOfOwnership: cumulativeCosts,
            netEquityChange: netEquityChange,
            annualizedReturn: annualizedReturn
        )
    }
    
    // MARK: - Private
    
    private func calculateVolatility(valuation: [ValuationEngine.ConditionTier: ValuationResult], profile: SegmentProfile?, segment: String) -> Int {
        guard let best = valuation[.concours]?.mid, let worst = valuation[.project]?.mid, best > 0 else {
            return profile.map { Int($0.peakMultiplier * 40) } ?? 40
        }
        let spread = (best - worst) / best * 100
        return min(Int(spread), 100)
    }
    
    private func calculateLiquidity(profile: SegmentProfile?, segment: String, year: Int) -> Int {
        let basePopularity = profile?.basePopularity ?? 50
        let currentYear = Calendar.current.component(.year, from: Date())
        let age = currentYear - year
        
        var liquidity = basePopularity
        if age <= 5 { liquidity += 15 }
        else if age <= 10 { liquidity += 5 }
        else { liquidity -= 10 }
        
        return max(min(liquidity, 100), 5)
    }
    
    private func loadProfiles() {
        guard let url = Bundle.main.url(forResource: "segment_profiles", withExtension: "json") else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(SegmentProfilesFile2.self, from: data)
            self.segmentProfiles = decoded.segments
        } catch {
            print("Error loading segment profiles: \(error)")
        }
    }
}

// MARK: - Result Types

struct RiskScore {
    let volatility: Int
    let liquidity: Int
    let cyclicality: Int
    let provenancePremium: Int
    let overallRisk: Int
    let segment: String
    
    var riskLevel: String {
        if overallRisk >= 70 { return "High" }
        if overallRisk >= 40 { return "Medium" }
        return "Low"
    }
}

struct PortfolioRisk {
    let averageRisk: RiskScore
    let concentrationRisk: Int
    let segmentBreakdown: [String: Int]
    let diversificationScore: Int
}

private struct SegmentProfilesFile2: Codable {
    let segments: [String: SegmentProfile]
}
