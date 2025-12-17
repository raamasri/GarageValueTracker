import SwiftUI

struct MaintenanceInsightsView: View {
    let vehicle: VehicleEntity
    let costEntries: [CostEntryEntity]
    @Environment(\.presentationMode) var presentationMode
    
    @State private var insights: MaintenanceInsights?
    
    var body: some View {
        NavigationView {
            ScrollView {
                if let insights = insights {
                    VStack(spacing: 24) {
                        // Yearly Average Card
                        VStack(spacing: 12) {
                            Text("Yearly Average")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text(formatCurrency(insights.yearlyAverage))
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.blue)
                            
                            Text("per year")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                        
                        // Comparison Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("vs. Typical \(vehicle.make)")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Your Costs")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(formatCurrency(insights.comparison.yourYearly))
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                }
                                
                                Image(systemName: "arrow.left.arrow.right")
                                    .foregroundColor(.secondary)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Typical")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(formatCurrency(insights.comparison.typicalYearly))
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Divider()
                            
                            HStack {
                                Image(systemName: comparisonIcon(insights.comparison.status))
                                    .foregroundColor(comparisonColor(insights.comparison.status))
                                
                                Text(insights.comparison.status.rawValue)
                                    .font(.headline)
                                    .foregroundColor(comparisonColor(insights.comparison.status))
                                
                                Spacer()
                                
                                Text(String(format: "%.0f%%", abs(insights.comparison.percentDifference)))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(comparisonColor(insights.comparison.status))
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                        
                        // 5-Year Predictions
                        VStack(alignment: .leading, spacing: 16) {
                            Text("5-Year Cost Projection")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            ForEach(insights.fiveYearPredictions, id: \.year) { prediction in
                                YearPredictionRow(prediction: prediction)
                            }
                            
                            let totalPredicted = insights.fiveYearPredictions.reduce(0.0) { $0 + $1.predictedCost }
                            Divider()
                            HStack {
                                Text("5-Year Total")
                                    .font(.headline)
                                Spacer()
                                Text(formatCurrency(totalPredicted))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                        
                        // Upcoming Maintenance
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Upcoming Maintenance")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            ForEach(Array(insights.upcomingMaintenance.enumerated()), id: \.offset) { index, item in
                                UpcomingMaintenanceRow(item: item, currentMileage: Int(vehicle.mileage))
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                        
                        // Analytics
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Cost Analytics")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            AnalyticRow(
                                icon: "gauge",
                                title: "Cost per Mile",
                                value: String(format: "$%.3f", insights.analytics.costPerMile)
                            )
                            
                            AnalyticRow(
                                icon: "calendar",
                                title: "Cost per Month",
                                value: formatCurrency(insights.analytics.costPerMonth)
                            )
                            
                            AnalyticRow(
                                icon: "dollarsign.circle",
                                title: "Total Spent",
                                value: formatCurrency(insights.analytics.totalSpent)
                            )
                            
                            AnalyticRow(
                                icon: "chart.bar",
                                title: "Most Expensive",
                                value: insights.analytics.mostExpensiveCategory
                            )
                            
                            HStack {
                                Image(systemName: insights.analytics.trend.icon)
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                
                                Text("Cost Trend")
                                    .font(.subheadline)
                                
                                Spacer()
                                
                                Text(insights.analytics.trend.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(trendColor(insights.analytics.trend))
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    }
                    .padding()
                } else {
                    ProgressView("Calculating insights...")
                        .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Maintenance Insights")
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
                generateInsights()
            }
        }
    }
    
    private func generateInsights() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            insights = MaintenanceInsightService.shared.generateInsights(
                for: vehicle,
                costEntries: costEntries
            )
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }
    
    private func comparisonIcon(_ status: ComparisonStatus) -> String {
        switch status {
        case .muchLower, .lower: return "arrow.down.circle.fill"
        case .average: return "equal.circle.fill"
        case .higher, .muchHigher: return "arrow.up.circle.fill"
        }
    }
    
    private func comparisonColor(_ status: ComparisonStatus) -> Color {
        switch status {
        case .muchLower, .lower: return .green
        case .average: return .blue
        case .higher: return .orange
        case .muchHigher: return .red
        }
    }
    
    private func trendColor(_ trend: CostTrend) -> Color {
        switch trend {
        case .decreasing: return .green
        case .stable: return .blue
        case .increasing: return .orange
        }
    }
}

// MARK: - Year Prediction Row
struct YearPredictionRow: View {
    let prediction: YearlyPrediction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(prediction.year)")
                    .font(.headline)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatCurrency(prediction.predictedCost))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    
                    Text("\(Int(prediction.confidence * 100))% confidence")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if !prediction.majorServices.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(prediction.majorServices, id: \.self) { service in
                        HStack(spacing: 6) {
                            Image(systemName: "wrench.and.screwdriver")
                                .font(.caption)
                                .foregroundColor(.orange)
                            
                            Text(service)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 4)
            }
            
            Text("\(formatMileage(prediction.estimatedMileage)) estimated")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }
    
    private func formatMileage(_ mileage: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: mileage)) ?? "\(mileage)") + " mi"
    }
}

// MARK: - Upcoming Maintenance Row
struct UpcomingMaintenanceRow: View {
    let item: UpcomingMaintenanceItem
    let currentMileage: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: priorityIcon)
                .foregroundColor(priorityColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.service)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Due at \(formatMileage(item.dueAtMileage))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                let remaining = item.dueAtMileage - currentMileage
                if remaining <= 500 {
                    Text("⚠️ Due soon - \(remaining) mi remaining")
                        .font(.caption)
                        .foregroundColor(.red)
                } else {
                    Text("\(remaining) mi remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(formatCurrency(item.estimatedCost))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var priorityIcon: String {
        switch item.priority {
        case .critical: return "exclamationmark.triangle.fill"
        case .recommended: return "checkmark.circle"
        case .optional: return "circle"
        }
    }
    
    private var priorityColor: Color {
        switch item.priority {
        case .critical: return .red
        case .recommended: return .blue
        case .optional: return .gray
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }
    
    private func formatMileage(_ mileage: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: mileage)) ?? "\(mileage)") + " mi"
    }
}

// MARK: - Analytic Row
struct AnalyticRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

