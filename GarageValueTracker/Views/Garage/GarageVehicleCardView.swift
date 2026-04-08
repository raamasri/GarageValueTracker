import SwiftUI

struct GarageVehicleCardView: View {
    let vehicle: VehicleEntity
    @Environment(\.managedObjectContext) private var viewContext

    @State private var valuation: ValuationResult?
    @State private var signal: Signal?
    @State private var projectedValues: [Double] = []
    @State private var trend3m: Double = 0
    @State private var trend12m: Double = 0
    @State private var trend36m: Double = 0

    private var colorDot: Color {
        let segment = vehicle.resolvedSegment
        switch segment {
        case "sports": return .red
        case "sedan": return .blue
        case "suv": return .green
        case "truck": return .brown
        case "ev": return .teal
        case "luxury": return .purple
        case "exotic": return .orange
        default: return .gray
        }
    }

    private var currentValue: Double {
        valuation?.mid ?? vehicle.currentValue
    }

    private var gainLoss: Double {
        currentValue - vehicle.purchasePrice
    }

    private var gainLossPercent: Double {
        guard vehicle.purchasePrice > 0 else { return 0 }
        return (gainLoss / vehicle.purchasePrice) * 100
    }

    private var isPositive: Bool { gainLoss >= 0 }

    private var sparklineColor: Color {
        if trend12m > 0 { return GIQ.gain }
        if trend12m < -5 { return GIQ.loss }
        return GIQ.secondaryText
    }

    private var badgeView: SignalBadge {
        guard let s = signal, let action = s.actionType else {
            return .hold()
        }
        switch action {
        case .sell: return .sell()
        case .wait: return .hold()
        case .hold: return .hold()
        default:
            if s.severity == .action { return .sellWindow() }
            return .hold()
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: dot + year + mileage + badge | price + gain/loss
            HStack(alignment: .top) {
                HStack(spacing: 8) {
                    Circle().fill(colorDot).frame(width: 8, height: 8)
                    Text("\(String(vehicle.year))")
                        .font(.mono(12, weight: .medium))
                        .foregroundColor(GIQ.secondaryText)
                    Text("\u{00B7}")
                        .foregroundColor(GIQ.tertiaryText)
                    Text("\(vehicle.mileage.formatted())mi")
                        .font(.mono(12, weight: .medium))
                        .foregroundColor(GIQ.secondaryText)
                    badgeView
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(giqCurrency(currentValue))
                        .font(.mono(22, weight: .bold))
                        .foregroundColor(.white)

                    HStack(spacing: 3) {
                        Image(systemName: isPositive ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                            .font(.system(size: 8))
                        Text(giqCurrency(abs(gainLoss)))
                            .font(.mono(12, weight: .semibold))
                        Text("(\(isPositive ? "+" : "")\(gainLossPercent, specifier: "%.1f")%)")
                            .font(.mono(11, weight: .medium))
                    }
                    .foregroundColor(isPositive ? GIQ.gain : GIQ.loss)
                }
            }

            // Vehicle name + trim
            VStack(alignment: .leading, spacing: 2) {
                Text("\(vehicle.make) \(vehicle.model)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)

                if let trim = vehicle.trim {
                    Text(trim)
                        .font(.mono(13, weight: .regular))
                        .foregroundColor(GIQ.secondaryText)
                }
            }

            // Trend row + sparkline
            HStack(alignment: .bottom) {
                HStack(spacing: 16) {
                    TrendLabel(period: "3m", value: trend3m)
                    TrendLabel(period: "12m", value: trend12m)
                    TrendLabel(period: "36m", value: trend36m)
                }

                Spacer()

                Sparkline(values: projectedValues, color: sparklineColor, height: 28)
                    .frame(width: 80)
            }
        }
        .themeCard()
        .onAppear { compute() }
    }

    private func compute() {
        let val = ValuationEngine.shared.valuate(
            make: vehicle.make, model: vehicle.model,
            year: Int(vehicle.year), mileage: Int(vehicle.mileage),
            trim: vehicle.trim, msrp: vehicle.trimMSRP > 0 ? vehicle.trimMSRP : nil,
            location: vehicle.location, condition: vehicle.conditionTier
        )
        valuation = val

        let segment = vehicle.resolvedSegment
        let projected = ValuationEngine.shared.projectValue(
            currentValue: val.mid, make: vehicle.make,
            model: vehicle.model, segment: segment, months: 36
        )
        projectedValues = projected.map(\.value)

        if projected.count > 3 {
            trend3m = val.mid > 0 ? ((projected[3].value - val.mid) / val.mid) * 100 : 0
        }
        if projected.count > 12 {
            trend12m = val.mid > 0 ? ((projected[12].value - val.mid) / val.mid) * 100 : 0
        }
        if let last = projected.last {
            trend36m = val.mid > 0 ? ((last.value - val.mid) / val.mid) * 100 : 0
        }

        signal = SignalEngine.shared.holdSellSignal(vehicle: vehicle, context: viewContext)
    }
}

struct TrendLabel: View {
    let period: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(period)
                .font(.mono(10, weight: .medium))
                .foregroundColor(GIQ.tertiaryText)
            Text("\(value >= 0 ? "+" : "")\(value, specifier: "%.1f")%")
                .font(.mono(13, weight: .bold))
                .foregroundColor(value >= 0 ? GIQ.gain : GIQ.loss)
        }
    }
}
