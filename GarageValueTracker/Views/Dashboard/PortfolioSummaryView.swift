import SwiftUI
import CoreData

struct PortfolioSummaryView: View {
    let vehicles: [VehicleEntity]
    
    private var totalEstimatedValue: Double {
        vehicles.reduce(0) { $0 + $1.currentValue }
    }
    
    private var totalCostBasis: Double {
        vehicles.reduce(0) { $0 + $1.purchasePrice }
    }
    
    private var totalGainLoss: Double {
        totalEstimatedValue - totalCostBasis
    }
    
    private var gainLossPercent: Double {
        guard totalCostBasis > 0 else { return 0 }
        return (totalGainLoss / totalCostBasis) * 100
    }
    
    private var isPositive: Bool {
        totalGainLoss >= 0
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Portfolio")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(vehicles.count) vehicle\(vehicles.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Value")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(totalEstimatedValue))
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Gain / Loss")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption)
                        Text(formatCurrency(abs(totalGainLoss)))
                            .fontWeight(.bold)
                    }
                    .font(.title3)
                    .foregroundColor(isPositive ? .green : .red)
                    
                    Text("\(isPositive ? "+" : "")\(gainLossPercent, specifier: "%.1f")%")
                        .font(.caption)
                        .foregroundColor(isPositive ? .green : .red)
                }
            }
            
            HStack(spacing: 16) {
                StatPill(label: "Cost Basis", value: formatCurrency(totalCostBasis))
                
                if let segmentBreakdown = segmentBreakdown, let topSegment = segmentBreakdown.first {
                    StatPill(label: "Top Segment", value: topSegment.key.capitalized)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
    
    private var segmentBreakdown: [(key: String, value: Int)]? {
        guard vehicles.count > 1 else { return nil }
        var counts: [String: Int] = [:]
        for v in vehicles {
            counts[v.resolvedSegment, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$\(Int(value))"
    }
}

struct StatPill: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.1))
        .clipShape(Capsule())
    }
}
