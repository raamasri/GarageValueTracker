import SwiftUI

struct DealAnalysisResultView: View {
    let result: DealAnalysisResult
    var make: String = ""
    var model: String = ""
    var year: Int = 0
    var mileage: Int = 0
    @Environment(\.presentationMode) var presentationMode
    @State private var aiInsight: String?
    @State private var isGeneratingAI = false
    @State private var realListings: [MarketCheckListing] = []
    @State private var realMarketStats: MarketStats?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Overall Score Card
                    VStack(spacing: 16) {
                        // Grade badge
                        Text(result.grade.emoji)
                            .font(.system(size: 60))
                        
                        Text(result.grade.rawValue)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        // Score gauge
                        ZStack {
                            Circle()
                                .stroke(Color(.systemGray5), lineWidth: 20)
                                .frame(width: 200, height: 200)
                            
                            Circle()
                                .trim(from: 0, to: CGFloat(result.overallScore) / 100)
                                .stroke(scoreColor, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                                .frame(width: 200, height: 200)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 1.0), value: result.overallScore)
                            
                            VStack(spacing: 4) {
                                Text("\(result.overallScore)")
                                    .font(.system(size: 60, weight: .bold))
                                    .foregroundColor(scoreColor)
                                
                                Text("out of 100")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        
                        // Recommendation
                        VStack(spacing: 8) {
                            if isGeneratingAI {
                                HStack(spacing: 6) {
                                    ProgressView().scaleEffect(0.7)
                                    Text("AI analyzing deal...").font(.caption).foregroundColor(.secondary)
                                }
                            }
                            Text(aiInsight ?? result.recommendation)
                                .font(.body)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(scoreColor.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    
                    // Score Breakdown
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Score Breakdown")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        ScoreBarView(
                            title: "Price",
                            score: result.priceScore,
                            color: .blue,
                            weight: "30%"
                        )
                        
                        ScoreBarView(
                            title: "Mileage",
                            score: result.mileageScore,
                            color: .green,
                            weight: "25%"
                        )
                        
                        ScoreBarView(
                            title: "Condition",
                            score: result.conditionScore,
                            color: .orange,
                            weight: "25%"
                        )
                        
                        ScoreBarView(
                            title: "Market",
                            score: result.marketScore,
                            color: .purple,
                            weight: "20%"
                        )
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    
                    // Key Insights
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                            Text("Key Insights")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        ForEach(Array(result.insights.enumerated()), id: \.offset) { index, insight in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: insightIcon(for: insight))
                                    .foregroundColor(insightColor(for: insight))
                                    .frame(width: 24)
                                
                                Text(insight)
                                    .font(.body)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    
                    // Fair Value Band
                    if let low = result.fairValueLow, let mid = result.fairValueMid, let high = result.fairValueHigh {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Fair Value Range")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Spacer()
                                if let verdict = result.verdict {
                                    Text(verdict.rawValue)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(verdictColor(verdict).opacity(0.15))
                                        .foregroundColor(verdictColor(verdict))
                                        .clipShape(Capsule())
                                }
                            }
                            
                            HStack {
                                VStack(spacing: 2) {
                                    Text("Low")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(formatCurrency(low))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                Spacer()
                                VStack(spacing: 2) {
                                    Text("Mid")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(formatCurrency(mid))
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                }
                                Spacer()
                                VStack(spacing: 2) {
                                    Text("High")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(formatCurrency(high))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                            }
                            
                            if let conf = result.confidence {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(conf >= 0.7 ? Color.green : Color.orange)
                                        .frame(width: 8, height: 8)
                                    Text("\(conf >= 0.8 ? "High" : conf >= 0.6 ? "Medium" : "Low") confidence estimate")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    }
                    
                    // Days on Market + Regional Context
                    if result.daysOnMarketEstimate != nil || result.regionalContext != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Market Context")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            if let dom = result.daysOnMarketEstimate {
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundColor(.blue)
                                        .frame(width: 30)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Estimated Days on Market")
                                            .font(.subheadline)
                                        Text("\(dom.lowerBound)-\(dom.upperBound) days at this price")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                            
                            if let regional = result.regionalContext {
                                HStack(alignment: .top) {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(.blue)
                                        .frame(width: 30)
                                    Text(regional)
                                        .font(.subheadline)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    }
                    
                    // Real Market Listings (from Marketcheck)
                    if !realListings.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .foregroundColor(.green)
                                Text("Live Market Listings")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }

                            HStack(spacing: 4) {
                                Circle().fill(Color.green).frame(width: 6, height: 6)
                                Text("Real active listings from Marketcheck")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            if let stats = realMarketStats {
                                HStack(spacing: 16) {
                                    VStack(spacing: 2) {
                                        Text("Median")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text(formatCurrency(stats.medianPrice))
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                    }
                                    VStack(spacing: 2) {
                                        Text("Listings")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text("\(stats.listingCount)")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                    }
                                    if let dom = stats.averageDaysOnMarket {
                                        VStack(spacing: 2) {
                                            Text("Avg DOM")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Text("\(dom) days")
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green.opacity(0.08))
                                .cornerRadius(10)
                            }

                            ForEach(realListings.prefix(8)) { listing in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(listing.formattedPrice)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        if let trim = listing.trim {
                                            Text(trim)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(listing.formattedMiles)
                                            .font(.caption)
                                        if let dealer = listing.dealer {
                                            Text(dealer.locationString)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        if let dom = listing.dom {
                                            Text("\(dom)d on market")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    }

                    // Comparable Sales (Synthetic fallback)
                    if let comps = result.syntheticComps, !comps.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(realListings.isEmpty ? "Estimated Comparables" : "Model-Based Estimates")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Spacer()
                            }
                            
                            Text("Based on valuation model estimates, not actual sales")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ForEach(comps) { comp in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(formatCurrency(comp.price))
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        Text("\(comp.condition.displayName) condition")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(formatMileage(comp.mileage))
                                            .font(.caption)
                                        Text(comp.source)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text(comp.soldDate, style: .relative)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    }
                    
                    // Detailed Metrics
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Detailed Metrics")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        MetricRow(
                            icon: "dollarsign.circle",
                            title: "Price vs Market",
                            value: String(format: "%.1f%%", result.priceDifference),
                            valueColor: result.priceDifference <= 0 ? .green : .red
                        )
                            
                            if result.expectedMileage > 0 {
                                MetricRow(
                                    icon: "gauge",
                                    title: "Expected Mileage",
                                    value: formatMileage(result.expectedMileage),
                                    valueColor: .primary
                                )
                                
                                MetricRow(
                                    icon: "arrow.up.arrow.down",
                                    title: "Mileage Difference",
                                    value: formatMileageDifference(result.mileageDifference),
                                    valueColor: result.mileageDifference <= 0 ? .green : .orange
                                )
                            }
                            
                            if let accidentImpact = result.accidentImpact {
                                MetricRow(
                                    icon: "exclamationmark.triangle",
                                    title: "Accident Impact",
                                    value: String(format: "-%.1f%%", accidentImpact * 100),
                                    valueColor: .red
                                )
                            }
                            
                        if let locationAdj = result.locationAdjustment {
                            MetricRow(
                                icon: "location.circle",
                                title: "Location Adjustment",
                                value: String(format: "+%.1f%%", locationAdj * 100),
                                valueColor: .green
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Deal Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                generateAIDealInsight()
                loadRealListings()
            }
        }
    }
    
    private func loadRealListings() {
        guard MarketCheckService.shared.isConfigured, !make.isEmpty, year > 0 else { return }
        Task {
            let comps = await LiveMarketDataService.shared.getRealComps(
                make: make, model: model, year: year,
                mileage: mileage, askingPrice: result.fairValueMid ?? 0
            )
            await MainActor.run {
                realListings = comps.listings
                realMarketStats = comps.stats
            }
        }
    }

    private func generateAIDealInsight() {
        guard aiInsight == nil else { return }
        guard AIServiceWrapper.shared.isAvailable else { return }
        guard let mid = result.fairValueMid else { return }
        isGeneratingAI = true
        let domStr = result.daysOnMarketEstimate.map { "\($0.lowerBound)-\($0.upperBound) days" } ?? "Unknown"
        Task {
            let insight = await AIServiceWrapper.shared.generateDealInsight(
                vehicleDescription: "\(year > 0 ? "\(year) " : "")\(make) \(model) — Score \(result.overallScore)/100, Grade: \(result.grade.rawValue)",
                askingPrice: result.askingPrice,
                fairValueLow: result.fairValueLow ?? 0,
                fairValueMid: mid,
                fairValueHigh: result.fairValueHigh ?? 0,
                verdict: result.verdict?.rawValue ?? "FAIR",
                overallScore: result.overallScore,
                daysOnMarketEstimate: domStr,
                regionalContext: result.regionalContext
            )
            await MainActor.run {
                aiInsight = insight
                isGeneratingAI = false
            }
        }
    }
    
    private var scoreColor: Color {
        switch result.overallScore {
        case 90...100: return .green
        case 75..<90: return .blue
        case 60..<75: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }
    
    private func insightIcon(for insight: String) -> String {
        let lower = insight.lowercased()
        if lower.contains("price") || lower.contains("market") {
            return "dollarsign.circle.fill"
        } else if lower.contains("mileage") {
            return "gauge.badge.plus"
        } else if lower.contains("accident") || lower.contains("history") {
            return "exclamationmark.triangle.fill"
        } else if lower.contains("resale") || lower.contains("brand") {
            return "chart.line.uptrend.xyaxis"
        } else if lower.contains("region") || lower.contains("demand") {
            return "location.fill"
        } else {
            return "info.circle.fill"
        }
    }
    
    private func insightColor(for insight: String) -> Color {
        let lower = insight.lowercased()
        if lower.contains("below market") || lower.contains("excellent") || lower.contains("great") || lower.contains("clean") {
            return .green
        } else if lower.contains("above market") || lower.contains("accident") || lower.contains("high mileage") {
            return .orange
        } else if lower.contains("overpriced") || lower.contains("major") || lower.contains("structural") {
            return .red
        } else {
            return .blue
        }
    }
    
    private func formatMileage(_ mileage: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: mileage)) ?? "\(mileage)") + " mi"
    }
    
    private func formatMileageDifference(_ diff: Int) -> String {
        let sign = diff >= 0 ? "+" : ""
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return sign + (formatter.string(from: NSNumber(value: abs(diff))) ?? "\(abs(diff))") + " mi"
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$\(Int(value))"
    }
    
    private func verdictColor(_ verdict: DealVerdict) -> Color {
        switch verdict {
        case .underpriced: return .green
        case .fair: return .blue
        case .rich: return .red
        }
    }
}

// MARK: - Score Bar Component
struct ScoreBarView: View {
    let title: String
    let score: Int
    let color: Color
    let weight: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(weight)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(score)/100")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(score) / 100, height: 8)
                        .cornerRadius(4)
                        .animation(.easeInOut(duration: 0.8), value: score)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Metric Row Component
struct MetricRow: View {
    let icon: String
    let title: String
    let value: String
    let valueColor: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(valueColor)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Preview
struct DealAnalysisResultView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleResult = DealAnalysisResult(
            overallScore: 85,
            priceScore: 90,
            mileageScore: 80,
            conditionScore: 100,
            marketScore: 75,
            insights: [
                "Great price - 15% below market",
                "Below average mileage",
                "Clean history - no reported accidents",
                "Toyota has excellent resale value"
            ],
            recommendation: "Great Deal! This vehicle offers excellent value.",
            grade: .good,
            askingPrice: 25000,
            priceDifference: -15.0,
            expectedMileage: 60000,
            mileageDifference: -10000,
            accidentImpact: nil,
            locationAdjustment: nil
        )
        
        return DealAnalysisResultView(result: sampleResult)
    }
}

