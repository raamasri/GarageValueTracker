import Foundation

class SellAdvisorService {
    static let shared = SellAdvisorService()

    private init() {}

    // MARK: - Sell Recommendation

    func analyze(
        vehicle: VehicleEntity,
        valuationSnapshots: [ValuationSnapshotEntity],
        monthlyCosts: Double,
        loanBalance: Double?
    ) -> SellAnalysis {
        let currentValue = vehicle.currentValue
        let purchasePrice = vehicle.purchasePrice
        let age = vehicleAgeMonths(vehicle)

        let depreciationVelocity = monthlyDepreciation(vehicle: vehicle, snapshots: valuationSnapshots)
        let retainedPercent = purchasePrice > 0 ? (currentValue / purchasePrice) * 100 : 100
        let costPerMonth = monthlyCosts + depreciationVelocity
        let equity = currentValue - (loanBalance ?? 0)
        let trend = valueTrend(snapshots: valuationSnapshots, currentValue: currentValue)

        let projectedValues = projectValues(
            currentValue: currentValue,
            make: vehicle.make,
            model: vehicle.model,
            months: 24
        )

        let sweetSpot = findSweetSpot(
            currentValue: currentValue,
            projectedValues: projectedValues,
            monthlyCost: costPerMonth,
            vehicleAgeMonths: age
        )

        let score = calculateSellScore(
            retainedPercent: retainedPercent,
            depreciationVelocity: depreciationVelocity,
            currentValue: currentValue,
            trend: trend,
            equity: equity,
            ageMonths: age
        )

        let recommendation = generateRecommendation(
            score: score,
            trend: trend,
            depreciationVelocity: depreciationVelocity,
            equity: equity,
            sweetSpot: sweetSpot
        )

        return SellAnalysis(
            sellScore: score,
            recommendation: recommendation,
            trend: trend,
            monthlyDepreciation: depreciationVelocity,
            retainedValuePercent: retainedPercent,
            equity: equity,
            costPerMonth: costPerMonth,
            sweetSpotMonths: sweetSpot,
            projectedValues: projectedValues
        )
    }

    // MARK: - Depreciation Velocity

    private func monthlyDepreciation(vehicle: VehicleEntity, snapshots: [ValuationSnapshotEntity]) -> Double {
        if snapshots.count >= 2 {
            let sorted = snapshots.sorted { $0.date < $1.date }
            let oldest = sorted.first!
            let newest = sorted.last!
            let months = max(Calendar.current.dateComponents([.month], from: oldest.date, to: newest.date).month ?? 1, 1)
            return (oldest.estimatedValue - newest.estimatedValue) / Double(months)
        }
        let ageMonths = max(vehicleAgeMonths(vehicle), 1)
        let totalDepreciation = vehicle.purchasePrice - vehicle.currentValue
        return max(totalDepreciation / Double(ageMonths), 0)
    }

    private func vehicleAgeMonths(_ vehicle: VehicleEntity) -> Int {
        max(Calendar.current.dateComponents([.month], from: vehicle.purchaseDate, to: Date()).month ?? 1, 1)
    }

    // MARK: - Value Trend

    private func valueTrend(snapshots: [ValuationSnapshotEntity], currentValue: Double) -> ValueTrend {
        guard snapshots.count >= 2 else { return .stable }
        let sorted = snapshots.sorted { $0.date < $1.date }
        let recent = Array(sorted.suffix(3))
        guard recent.count >= 2 else { return .stable }

        let changes = zip(recent.dropFirst(), recent).map { $0.estimatedValue - $1.estimatedValue }
        let avgChange = changes.reduce(0, +) / Double(changes.count)
        let percentChange = (avgChange / currentValue) * 100

        if percentChange > 1 { return .rising }
        if percentChange < -3 { return .declining }
        return .stable
    }

    // MARK: - Value Projection

    func projectValues(currentValue: Double, make: String, model: String, months: Int) -> [ProjectedValue] {
        var values: [ProjectedValue] = []
        let monthlyRate = subsequentDepreciationRate(make: make, model: model) / 12.0
        var value = currentValue

        for m in 0...months {
            let date = Calendar.current.date(byAdding: .month, value: m, to: Date()) ?? Date()
            values.append(ProjectedValue(monthsFromNow: m, date: date, value: value))
            value *= (1.0 - monthlyRate)
        }
        return values
    }

    // MARK: - Sweet Spot (optimal sell window)

    private func findSweetSpot(
        currentValue: Double,
        projectedValues: [ProjectedValue],
        monthlyCost: Double,
        vehicleAgeMonths: Int
    ) -> Int? {
        // The "sweet spot" is when the marginal cost of keeping the car another month
        // (depreciation + running costs) exceeds a threshold relative to current value.
        // For most cars this is around year 3-5.
        let threshold = currentValue * 0.025 // 2.5% of current value per month

        for projected in projectedValues.dropFirst() {
            let monthlyLoss = (currentValue - projected.value) / Double(projected.monthsFromNow)
            let totalMonthlyCost = monthlyLoss + monthlyCost
            if totalMonthlyCost > threshold {
                return projected.monthsFromNow
            }
        }
        return nil
    }

    // MARK: - Sell Score

    private func calculateSellScore(
        retainedPercent: Double,
        depreciationVelocity: Double,
        currentValue: Double,
        trend: ValueTrend,
        equity: Double,
        ageMonths: Int
    ) -> Int {
        var score = 50 // neutral starting point

        // Higher retained value = better time to sell (capture value before it drops more)
        if retainedPercent > 80 { score += 15 }
        else if retainedPercent > 60 { score += 10 }
        else if retainedPercent < 40 { score -= 10 }

        // High depreciation velocity = sell sooner
        let monthlyDepreciationPercent = currentValue > 0 ? (depreciationVelocity / currentValue) * 100 : 0
        if monthlyDepreciationPercent > 2 { score += 15 }
        else if monthlyDepreciationPercent > 1 { score += 10 }
        else if monthlyDepreciationPercent < 0.5 { score -= 5 }

        // Trend adjustments
        switch trend {
        case .rising: score -= 15 // value going up, hold
        case .declining: score += 15 // value dropping, sell
        case .stable: break
        }

        // Negative equity = bad time to sell
        if equity < 0 { score -= 20 }

        // Age sweet spots (3-5 years is often ideal)
        if ageMonths >= 36 && ageMonths <= 60 { score += 10 }
        else if ageMonths > 84 { score -= 5 }

        return max(min(score, 100), 0)
    }

    // MARK: - Recommendation

    private func generateRecommendation(
        score: Int,
        trend: ValueTrend,
        depreciationVelocity: Double,
        equity: Double,
        sweetSpot: Int?
    ) -> SellRecommendation {
        if score >= 75 {
            var reason = "Your vehicle is depreciating at a rate where selling soon would maximize your return."
            if trend == .declining {
                reason += " The value trend is declining, so acting sooner is better."
            }
            return SellRecommendation(
                verdict: .sellSoon,
                title: "Good Time to Sell",
                reason: reason
            )
        } else if score >= 50 {
            var reason = "Your vehicle still holds reasonable value. Monitor the market and consider selling in the next few months."
            if let months = sweetSpot {
                reason += " The optimal window is roughly \(months) months from now."
            }
            return SellRecommendation(
                verdict: .consider,
                title: "Consider Selling",
                reason: reason
            )
        } else if equity < 0 {
            return SellRecommendation(
                verdict: .holdOff,
                title: "Underwater on Loan",
                reason: "Your loan balance exceeds the vehicle's value. Continue making payments to build equity before selling, or consider making extra payments."
            )
        } else {
            var reason = "Your vehicle's value is relatively stable or still holds well."
            if trend == .rising {
                reason = "Your vehicle's value appears to be rising. Hold for now to maximize your return."
            }
            return SellRecommendation(
                verdict: .holdOff,
                title: "Hold For Now",
                reason: reason
            )
        }
    }

    // MARK: - Depreciation Rates

    private func subsequentDepreciationRate(make: String, model: String) -> Double {
        let upperMake = make.uppercased()
        let upperModel = model.uppercased()

        if upperModel.contains("WRANGLER") || upperModel.contains("4RUNNER") || upperModel.contains("TACOMA") || upperModel.contains("BRONCO") {
            return 0.06
        }
        if ["PORSCHE", "FERRARI", "LAMBORGHINI"].contains(upperMake) { return 0.07 }
        if ["TOYOTA", "LEXUS", "HONDA", "SUBARU"].contains(upperMake) { return 0.10 }
        if upperMake == "TESLA" { return 0.12 }
        if ["BMW", "MERCEDES-BENZ", "AUDI", "MASERATI", "JAGUAR"].contains(upperMake) { return 0.15 }
        return 0.12
    }
}

// MARK: - Models

struct SellAnalysis {
    let sellScore: Int
    let recommendation: SellRecommendation
    let trend: ValueTrend
    let monthlyDepreciation: Double
    let retainedValuePercent: Double
    let equity: Double
    let costPerMonth: Double
    let sweetSpotMonths: Int?
    let projectedValues: [ProjectedValue]
}

struct SellRecommendation {
    let verdict: SellVerdict
    let title: String
    let reason: String
}

enum SellVerdict {
    case sellSoon, consider, holdOff
}

enum ValueTrend {
    case rising, stable, declining

    var label: String {
        switch self {
        case .rising: return "Rising"
        case .stable: return "Stable"
        case .declining: return "Declining"
        }
    }

    var icon: String {
        switch self {
        case .rising: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .declining: return "arrow.down.right"
        }
    }

    var color: String {
        switch self {
        case .rising: return "green"
        case .stable: return "blue"
        case .declining: return "red"
        }
    }
}

struct ProjectedValue: Identifiable {
    let id = UUID()
    let monthsFromNow: Int
    let date: Date
    let value: Double
}
