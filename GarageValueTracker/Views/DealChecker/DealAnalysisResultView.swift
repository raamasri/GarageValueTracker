import SwiftUI

struct DealAnalysisResultView: View {
    let result: DealAnalysisResult
    @Environment(\.presentationMode) var presentationMode
    
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
                        Text(result.recommendation)
                            .font(.body)
                            .multilineTextAlignment(.center)
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
            priceDifference: -15.0,
            expectedMileage: 60000,
            mileageDifference: -10000,
            accidentImpact: nil,
            locationAdjustment: nil
        )
        
        return DealAnalysisResultView(result: sampleResult)
    }
}

