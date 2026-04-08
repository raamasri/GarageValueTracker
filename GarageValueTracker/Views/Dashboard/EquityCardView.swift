import SwiftUI

struct EquityCardView: View {
    let vehicle: VehicleEntity
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var valuation: ValuationResult?
    @State private var holdSignal: Signal?
    @State private var costProjections: [CostToHoldProjection] = []
    @State private var selectedProjection: Int = 1
    
    private var costBasis: Double {
        vehicle.purchasePrice
    }
    
    private var gainLoss: Double {
        guard let val = valuation else {
            return vehicle.currentValue - costBasis
        }
        return val.mid - costBasis
    }
    
    private var gainLossPercent: Double {
        guard costBasis > 0 else { return 0 }
        return (gainLoss / costBasis) * 100
    }
    
    private var isPositive: Bool { gainLoss >= 0 }
    
    var body: some View {
        VStack(spacing: 16) {
            // Equity Header
            HStack {
                Text("Equity & Valuation")
                    .font(.headline)
                Spacer()
                if let val = valuation {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(confidenceColor(val.confidence))
                            .frame(width: 8, height: 8)
                        Text("\(val.confidenceLabel) confidence")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Value Range
            if let val = valuation {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Estimated Value")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatCurrency(val.mid))
                            .font(.title)
                            .fontWeight(.bold)
                        
                        HStack(spacing: 4) {
                            Text(formatCurrency(val.low))
                                .foregroundColor(.secondary)
                            Text("-")
                                .foregroundColor(.secondary)
                            Text(formatCurrency(val.high))
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 8) {
                        Text("Gain / Loss")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption)
                            Text(formatCurrency(abs(gainLoss)))
                                .fontWeight(.bold)
                        }
                        .font(.title3)
                        .foregroundColor(isPositive ? .green : .red)
                        
                        Text("\(isPositive ? "+" : "")\(gainLossPercent, specifier: "%.1f")%")
                            .font(.caption)
                            .foregroundColor(isPositive ? .green : .red)
                    }
                }
            }
            
            Divider()
            
            // Hold/Sell Signal
            if let signal = holdSignal {
                HStack(spacing: 12) {
                    Image(systemName: signalIcon(signal))
                        .font(.title3)
                        .foregroundColor(signalColor(signal))
                        .frame(width: 40, height: 40)
                        .background(signalColor(signal).opacity(0.15))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(signal.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(signal.body)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            
            // Cost-to-Hold
            if !costProjections.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cost to Hold")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 8) {
                        ForEach(costProjections) { proj in
                            Button(action: {
                                selectedProjection = costProjections.firstIndex(where: { $0.months == proj.months }) ?? 0
                            }) {
                                VStack(spacing: 4) {
                                    Text("\(proj.months)mo")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                    Text(proj.formattedTotal)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                    Text(proj.formattedMonthly + "/mo")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    costProjections.firstIndex(where: { $0.months == proj.months }) == selectedProjection
                                    ? Color.blue.opacity(0.15) : Color.secondary.opacity(0.08)
                                )
                                .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
        .onAppear { loadData() }
    }
    
    private func loadData() {
        valuation = ValuationEngine.shared.valuate(
            make: vehicle.make, model: vehicle.model,
            year: Int(vehicle.year), mileage: Int(vehicle.mileage),
            trim: vehicle.trim, msrp: vehicle.trimMSRP > 0 ? vehicle.trimMSRP : nil,
            location: vehicle.location, condition: vehicle.conditionTier
        )
        
        holdSignal = SignalEngine.shared.holdSellSignal(vehicle: vehicle, context: viewContext)
        costProjections = CostToHoldService.shared.projectMultiple(vehicle: vehicle, context: viewContext)
    }
    
    private func signalIcon(_ signal: Signal) -> String {
        switch signal.actionType {
        case .sell: return "arrow.up.forward.circle.fill"
        case .hold: return "pause.circle.fill"
        case .wait: return "clock.fill"
        default: return "info.circle.fill"
        }
    }
    
    private func signalColor(_ signal: Signal) -> Color {
        switch signal.actionType {
        case .sell: return .orange
        case .hold: return .blue
        case .wait: return .purple
        default: return .gray
        }
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.80 { return .green }
        if confidence >= 0.60 { return .yellow }
        return .red
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$\(Int(value))"
    }
}
