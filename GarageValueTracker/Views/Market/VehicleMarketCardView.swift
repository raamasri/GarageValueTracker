import SwiftUI

struct VehicleMarketCardView: View {
    let make: String
    let model: String
    let year: Int
    let mileage: Int
    let trim: String?
    
    @State private var valuations: [ValuationEngine.ConditionTier: ValuationResult] = [:]
    @State private var riskScore: RiskScore?
    @State private var daysOnMarket: ClosedRange<Int>?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                priceByConditionSection
                marketMetricsSection
                trendSection
            }
            .padding()
        }
        .navigationTitle("\(year) \(make) \(model)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadData() }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("\(year) \(make) \(model)")
                .font(.title2)
                .fontWeight(.bold)
            if let trim = trim {
                Text(trim)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            if let goodVal = valuations[.good] {
                Text(goodVal.segment.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
    }
    
    private var priceByConditionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Price by Condition")
                .font(.headline)
            
            let sortedTiers = ValuationEngine.ConditionTier.allCases.sorted { $0.sortOrder < $1.sortOrder }
            
            ForEach(sortedTiers, id: \.rawValue) { tier in
                if let val = valuations[tier] {
                    HStack {
                        Text(tier.displayName)
                            .font(.subheadline)
                            .frame(width: 80, alignment: .leading)
                        
                        GeometryReader { geo in
                            let maxVal = valuations[.concours]?.high ?? val.high
                            let width = maxVal > 0 ? CGFloat(val.mid / maxVal) * geo.size.width : 0
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(tierColor(tier).opacity(0.6))
                                .frame(width: max(width, 20), height: 24)
                                .overlay(alignment: .trailing) {
                                    Text(formatCurrency(val.mid))
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .padding(.trailing, 4)
                                }
                        }
                        .frame(height: 24)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    private var marketMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Market Metrics")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if let risk = riskScore {
                    MetricCard(title: "Liquidity", value: "\(risk.liquidity)/100", subtitle: risk.liquidity > 60 ? "High" : risk.liquidity > 30 ? "Medium" : "Low", color: risk.liquidity > 60 ? .green : .orange)
                    
                    MetricCard(title: "Volatility", value: "\(risk.volatility)/100", subtitle: risk.volatility > 60 ? "High" : risk.volatility > 30 ? "Medium" : "Low", color: risk.volatility > 60 ? .red : .green)
                }
                
                if let dom = daysOnMarket {
                    MetricCard(title: "Days on Market", value: "\(dom.lowerBound)-\(dom.upperBound)", subtitle: "Estimated", color: .blue)
                }
                
                if let good = valuations[.good] {
                    MetricCard(title: "Confidence", value: good.confidenceLabel, subtitle: "\(Int(good.confidence * 100))%", color: good.confidence > 0.7 ? .green : .yellow)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Value Trend Estimate")
                .font(.headline)
            
            if let goodVal = valuations[.good] {
                let projected = ValuationEngine.shared.projectValue(
                    currentValue: goodVal.mid, make: make, model: model,
                    segment: goodVal.segment, months: 36
                )
                
                HStack(spacing: 16) {
                    TrendPill(label: "3 mo", value: projected.count > 3 ? projected[3].value : goodVal.mid, reference: goodVal.mid)
                    TrendPill(label: "12 mo", value: projected.count > 12 ? projected[12].value : goodVal.mid, reference: goodVal.mid)
                    TrendPill(label: "36 mo", value: projected.last?.value ?? goodVal.mid, reference: goodVal.mid)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    private func loadData() {
        valuations = ValuationEngine.shared.valuateAllConditions(
            make: make, model: model, year: year, mileage: mileage, trim: trim
        )
        
        let segment = LocationMarketService.shared.classifyVehicle(make: make, model: model)
        riskScore = RiskScoringEngine.shared.score(make: make, model: model, year: year, mileage: mileage, segment: segment)
        
        if let goodVal = valuations[.good] {
            let priceVsMarket = 0.0
            daysOnMarket = ValuationEngine.shared.estimatedDaysOnMarket(segment: goodVal.segment, priceVsMarket: priceVsMarket)
        }
    }
    
    private func tierColor(_ tier: ValuationEngine.ConditionTier) -> Color {
        switch tier {
        case .concours: return .purple
        case .excellent: return .blue
        case .good: return .green
        case .driver: return .orange
        case .project: return .red
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$\(Int(value))"
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.08))
        .cornerRadius(12)
    }
}

struct TrendPill: View {
    let label: String
    let value: Double
    let reference: Double
    
    private var change: Double {
        guard reference > 0 else { return 0 }
        return ((value - reference) / reference) * 100
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            let formatter = NumberFormatter()
            Text({
                formatter.numberStyle = .currency
                formatter.maximumFractionDigits = 0
                return formatter.string(from: NSNumber(value: value)) ?? ""
            }())
                .font(.caption)
                .fontWeight(.bold)
            
            Text("\(change >= 0 ? "+" : "")\(change, specifier: "%.1f")%")
                .font(.caption2)
                .foregroundColor(change >= 0 ? .green : .red)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(8)
    }
}
