import SwiftUI

struct VehicleDetailInlineSection: View {
    let vehicle: VehicleEntity
    @Environment(\.managedObjectContext) private var viewContext

    @State private var valuation: ValuationResult?
    @State private var signal: Signal?
    @State private var riskScore: RiskScore?
    @State private var costProjection: CostToHoldProjection?
    @State private var aiSignalText: String?
    @State private var isGeneratingAI = false
    @State private var calibration: CalibrationResult?
    @State private var isCalibrating = false

    var body: some View {
        VStack(spacing: 16) {
            aiSignalCard
            marketValueRange
            riskProfile
            costToHoldRow
        }
        .padding(.horizontal)
        .onAppear { load() }
    }

    // MARK: - AI Signal Card

    private var aiSignalCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("AI SIGNAL")
                    .font(.mono(10, weight: .semibold))
                    .foregroundColor(GIQ.accent)
                    .tracking(1.2)
                if isGeneratingAI {
                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(GIQ.accent)
                }
            }

            if let aiText = aiSignalText {
                Text(aiText)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            } else if let s = signal {
                Text(s.body)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Analyzing market conditions...")
                    .font(.system(size: 15))
                    .foregroundColor(GIQ.secondaryText)
            }
        }
        .themeCard(border: GIQ.accent.opacity(0.4))
    }

    // MARK: - Market Value Range

    @ViewBuilder
    private var marketValueRange: some View {
        if let val = valuation {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Market Value Range")
                        .font(.mono(13, weight: .semibold))
                        .foregroundColor(GIQ.secondaryText)
                    Spacer()
                    if isCalibrating {
                        HStack(spacing: 4) {
                            ProgressView().scaleEffect(0.5).tint(GIQ.accent)
                            Text("Calibrating...")
                                .font(.mono(9))
                                .foregroundColor(GIQ.tertiaryText)
                        }
                    } else if let cal = calibration, cal.isCalibrated {
                        HStack(spacing: 3) {
                            Circle().fill(Color.green).frame(width: 5, height: 5)
                            Text("LIVE")
                                .font(.mono(9, weight: .bold))
                                .foregroundColor(.green)
                        }
                    }
                }

                HStack {
                    VStack(spacing: 2) {
                        Text("Low")
                            .font(.mono(10, weight: .medium))
                            .foregroundColor(GIQ.tertiaryText)
                        Text(giqCurrency(displayLow(val)))
                            .font(.mono(16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("Mid")
                            .font(.mono(10, weight: .medium))
                            .foregroundColor(GIQ.tertiaryText)
                        Text(giqCurrency(displayMid(val)))
                            .font(.mono(20, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("High")
                            .font(.mono(10, weight: .medium))
                            .foregroundColor(GIQ.tertiaryText)
                        Text(giqCurrency(displayHigh(val)))
                            .font(.mono(16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                GeometryReader { geo in
                    let low = displayLow(val)
                    let mid = displayMid(val)
                    let high = displayHigh(val)
                    let range = high - low
                    let midPos = range > 0 ? (mid - low) / range : 0.5
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.08))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [GIQ.accent.opacity(0.6), GIQ.accent],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(midPos))
                    }
                }
                .frame(height: 6)

                if let cal = calibration, cal.isCalibrated, let count = cal.listingCount {
                    HStack(spacing: 4) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 8))
                            .foregroundColor(.green.opacity(0.7))
                        Text("Calibrated against \(count) live listing\(count == 1 ? "" : "s")")
                            .font(.mono(9))
                            .foregroundColor(GIQ.tertiaryText)
                        if let adj = calibration?.adjustmentPercent, abs(adj) >= 1 {
                            Text("(\(adj >= 0 ? "+" : "")\(String(format: "%.0f", adj))%)")
                                .font(.mono(9, weight: .bold))
                                .foregroundColor(adj >= 0 ? .green.opacity(0.8) : .red.opacity(0.8))
                        }
                    }
                }
            }
            .themeCard()
        }
    }

    private func displayLow(_ val: ValuationResult) -> Double {
        guard let cal = calibration, cal.isCalibrated else { return val.low }
        return val.low * cal.calibrationFactor
    }

    private func displayMid(_ val: ValuationResult) -> Double {
        guard let cal = calibration, cal.isCalibrated else { return val.mid }
        return cal.calibratedValue
    }

    private func displayHigh(_ val: ValuationResult) -> Double {
        guard let cal = calibration, cal.isCalibrated else { return val.high }
        return val.high * cal.calibrationFactor
    }

    // MARK: - Risk Profile

    @ViewBuilder
    private var riskProfile: some View {
        if let risk = riskScore {
            VStack(alignment: .leading, spacing: 12) {
                Text("Risk Profile")
                    .font(.mono(13, weight: .semibold))
                    .foregroundColor(GIQ.secondaryText)

                RiskBarRow(label: "Liquidity", value: Double(risk.liquidity), color: GIQ.liquidityBar)
                RiskBarRow(label: "Volatility", value: Double(risk.volatility), color: GIQ.volatilityBar)
                RiskBarRow(label: "Cyclicality", value: Double(risk.cyclicality), color: GIQ.cyclicalityBar)
            }
            .themeCard()
        }
    }

    // MARK: - Cost to Hold

    @ViewBuilder
    private var costToHoldRow: some View {
        if let proj = costProjection {
            VStack(alignment: .leading, spacing: 10) {
                Text("Cost to Hold \(proj.months) More Months")
                    .font(.mono(13, weight: .semibold))
                    .foregroundColor(GIQ.secondaryText)

                HStack {
                    CostColumn(label: "Insurance", value: proj.projectedInsurance)
                    CostColumn(label: "Loan", value: proj.projectedLoanInterest)
                    CostColumn(label: "Maint.", value: proj.projectedMaintenance)
                    CostColumn(label: "Total", value: proj.totalProjectedCost, highlight: true)
                }
            }
            .themeCard()
        }
    }

    private func load() {
        let val = ValuationEngine.shared.valuate(
            make: vehicle.make, model: vehicle.model,
            year: Int(vehicle.year), mileage: Int(vehicle.mileage),
            trim: vehicle.trim, msrp: vehicle.trimMSRP > 0 ? vehicle.trimMSRP : nil,
            location: vehicle.location, condition: vehicle.conditionTier
        )
        valuation = val

        signal = SignalEngine.shared.holdSellSignal(vehicle: vehicle, context: viewContext)

        let risk = RiskScoringEngine.shared.scoreVehicle(vehicle)
        riskScore = risk

        let cost = CostToHoldService.shared.project(vehicle: vehicle, months: 12, context: viewContext)
        costProjection = cost

        if MarketCheckService.shared.isConfigured {
            isCalibrating = true
            Task {
                let cal = await LiveMarketDataService.shared.getCalibration(
                    make: vehicle.make, model: vehicle.model,
                    year: Int(vehicle.year), mileage: Int(vehicle.mileage),
                    localEstimate: val.mid
                )
                await MainActor.run {
                    calibration = cal
                    isCalibrating = false
                }
            }
        }

        guard aiSignalText == nil, AIServiceWrapper.shared.isAvailable else { return }
        isGeneratingAI = true
        
        let segment = vehicle.resolvedSegment
        let projected = ValuationEngine.shared.projectValue(
            currentValue: val.mid, make: vehicle.make,
            model: vehicle.model, segment: segment, months: 36
        )
        let t3 = projected.count > 3 && val.mid > 0 ? ((projected[3].value - val.mid) / val.mid) * 100 : 0
        let t12 = projected.count > 12 && val.mid > 0 ? ((projected[12].value - val.mid) / val.mid) * 100 : 0
        let t36 = projected.last.map { val.mid > 0 ? (($0.value - val.mid) / val.mid) * 100 : 0 } ?? 0
        
        Task {
            let result = await AIServiceWrapper.shared.generateVehicleSignal(
                vehicleName: vehicle.displayName,
                make: vehicle.make, model: vehicle.model,
                year: Int(vehicle.year), mileage: Int(vehicle.mileage),
                trim: vehicle.trim, segment: segment,
                currentValue: val.mid, purchasePrice: vehicle.purchasePrice,
                conditionTier: vehicle.conditionTier.rawValue,
                trend3m: t3, trend12m: t12, trend36m: t36,
                riskVolatility: risk.volatility, riskLiquidity: risk.liquidity,
                costToHold12m: cost.totalProjectedCost
            )
            await MainActor.run {
                aiSignalText = result
                isGeneratingAI = false
            }
        }
    }
}

// MARK: - Sub-components

struct RiskBarRow: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.mono(12, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))

            HStack(spacing: 8) {
                HProgressBar(value: value, maxValue: 100, color: color)
                Text(String(format: "%.1f", value / 10.0))
                    .font(.mono(13, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 30, alignment: .trailing)
            }
        }
    }
}

struct CostColumn: View {
    let label: String
    let value: Double
    var highlight: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.mono(10, weight: .medium))
                .foregroundColor(GIQ.tertiaryText)
            Text(giqCurrency(value))
                .font(.mono(14, weight: .bold))
                .foregroundColor(highlight ? GIQ.loss : .white)
        }
        .frame(maxWidth: .infinity)
    }
}
