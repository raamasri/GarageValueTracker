import SwiftUI
import Charts
import CoreData

struct SellAdvisorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    let vehicle: VehicleEntity

    @FetchRequest private var valuationSnapshots: FetchedResults<ValuationSnapshotEntity>
    @FetchRequest private var costEntries: FetchedResults<CostEntryEntity>
    @FetchRequest private var loans: FetchedResults<LoanEntity>

    @State private var analysis: SellAnalysis?
    @State private var selectedChartPoint: ChartPoint?

    init(vehicle: VehicleEntity) {
        self.vehicle = vehicle

        _valuationSnapshots = FetchRequest<ValuationSnapshotEntity>(
            sortDescriptors: [NSSortDescriptor(keyPath: \ValuationSnapshotEntity.date, ascending: true)],
            predicate: NSPredicate(format: "vehicleID == %@", vehicle.id as CVarArg),
            animation: .default
        )

        _costEntries = FetchRequest<CostEntryEntity>(
            sortDescriptors: [NSSortDescriptor(keyPath: \CostEntryEntity.date, ascending: false)],
            predicate: NSPredicate(format: "vehicleID == %@", vehicle.id as CVarArg),
            animation: .default
        )

        _loans = FetchRequest<LoanEntity>(
            sortDescriptors: [NSSortDescriptor(keyPath: \LoanEntity.startDate, ascending: false)],
            predicate: NSPredicate(format: "vehicleID == %@ AND isActive == YES", vehicle.id as CVarArg),
            animation: .default
        )
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let analysis = analysis {
                        verdictCard(analysis)
                        statsRow(analysis)
                        priceHistoryChart(analysis)
                        insightsCard(analysis)
                        tipsCard(analysis)
                    } else {
                        ProgressView("Analyzing...")
                            .padding(.top, 60)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Sell Advisor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .onAppear { runAnalysis() }
        }
    }

    // MARK: - Verdict Card

    private func verdictCard(_ analysis: SellAnalysis) -> some View {
        let rec = analysis.recommendation

        return VStack(spacing: 16) {
            HStack {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                        .frame(width: 90, height: 90)

                    Circle()
                        .trim(from: 0, to: CGFloat(analysis.sellScore) / 100.0)
                        .stroke(verdictColor(rec.verdict), lineWidth: 10)
                        .frame(width: 90, height: 90)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: analysis.sellScore)

                    VStack(spacing: 2) {
                        Text("\(analysis.sellScore)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(verdictColor(rec.verdict))
                        Text("/ 100")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label(rec.title, systemImage: verdictIcon(rec.verdict))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(verdictColor(rec.verdict))

                    Text(rec.reason)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 4)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }

    // MARK: - Stats Row

    private func statsRow(_ analysis: SellAnalysis) -> some View {
        HStack(spacing: 12) {
            QuickStatCard(
                title: "Monthly Loss",
                value: formatCurrency(analysis.monthlyDepreciation),
                icon: "arrow.down.right",
                color: .red
            )
            QuickStatCard(
                title: "Value Retained",
                value: "\(Int(analysis.retainedValuePercent))%",
                icon: "chart.line.uptrend.xyaxis",
                color: analysis.retainedValuePercent > 60 ? .green : .orange
            )
            QuickStatCard(
                title: "Trend",
                value: analysis.trend.label,
                icon: analysis.trend.icon,
                color: trendColor(analysis.trend)
            )
        }
        .padding(.horizontal)
    }

    // MARK: - Price History Chart

    private func priceHistoryChart(_ analysis: SellAnalysis) -> some View {
        let historicalPoints = buildHistoricalPoints()
        let projectedPoints = analysis.projectedValues

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Value Over Time")
                    .font(.headline)
                Spacer()
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle().fill(.blue).frame(width: 8, height: 8)
                        Text("Actual").font(.caption2).foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(.orange.opacity(0.6)).frame(width: 8, height: 8)
                        Text("Projected").font(.caption2).foregroundColor(.secondary)
                    }
                }
            }

            Chart {
                // Historical data
                ForEach(historicalPoints) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 3))

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(.blue)
                    .symbolSize(30)
                }

                // Projected data
                ForEach(projectedPoints.filter { $0.monthsFromNow > 0 }) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(.orange.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                }

                // Sell zone highlight
                if let sweetSpot = analysis.sweetSpotMonths {
                    let sweetDate = Calendar.current.date(byAdding: .month, value: sweetSpot, to: Date()) ?? Date()
                    RuleMark(x: .value("Date", sweetDate))
                        .foregroundStyle(.green.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                        .annotation(position: .top) {
                            Text("Sell Window")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                                .padding(4)
                                .background(.ultraThinMaterial)
                                .cornerRadius(4)
                        }
                }

                // Today marker
                RuleMark(x: .value("Date", Date()))
                    .foregroundStyle(.gray.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .bottom) {
                        Text("Today")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(2)
                    }

                // Selected point annotation
                if let selected = selectedChartPoint {
                    RuleMark(x: .value("Date", selected.date))
                        .foregroundStyle(.gray.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .top) {
                            VStack(spacing: 2) {
                                Text(formatCurrency(selected.value))
                                    .font(.caption)
                                    .fontWeight(.bold)
                                Text(shortDate(selected.date))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(6)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                        }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text("$\(Int(amount / 1000))k")
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.year())
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let x = value.location.x
                                    if let date: Date = proxy.value(atX: x) {
                                        let allPoints = historicalPoints.map { ChartPoint(date: $0.date, value: $0.value) }
                                            + projectedPoints.map { ChartPoint(date: $0.date, value: $0.value) }
                                        selectedChartPoint = allPoints.min(by: {
                                            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                        })
                                    }
                                }
                                .onEnded { _ in selectedChartPoint = nil }
                        )
                }
            }
            .frame(height: 280)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }

    // MARK: - Insights Card

    private func insightsCard(_ analysis: SellAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Insights")
                .font(.headline)

            insightRow(
                icon: "dollarsign.circle.fill",
                color: .green,
                title: "Current Value",
                detail: "\(formatCurrency(vehicle.currentValue)) (\(Int(analysis.retainedValuePercent))% of purchase price)"
            )

            insightRow(
                icon: "arrow.down.right.circle.fill",
                color: .red,
                title: "Depreciation Rate",
                detail: "\(formatCurrency(analysis.monthlyDepreciation))/month"
            )

            if analysis.equity != vehicle.currentValue {
                insightRow(
                    icon: analysis.equity >= 0 ? "checkmark.circle.fill" : "xmark.circle.fill",
                    color: analysis.equity >= 0 ? .green : .red,
                    title: "Loan Equity",
                    detail: analysis.equity >= 0
                        ? "\(formatCurrency(analysis.equity)) positive equity"
                        : "\(formatCurrency(abs(analysis.equity))) underwater"
                )
            }

            insightRow(
                icon: "calendar.circle.fill",
                color: .blue,
                title: "Ownership Cost",
                detail: "\(formatCurrency(analysis.costPerMonth))/month (depreciation + maintenance)"
            )

            if let sweetSpot = analysis.sweetSpotMonths {
                insightRow(
                    icon: "star.circle.fill",
                    color: .orange,
                    title: "Optimal Sell Window",
                    detail: "Within the next \(sweetSpot) months for best return"
                )
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }

    // MARK: - Tips Card

    private func tipsCard(_ analysis: SellAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Maximize Your Sale Price")
                .font(.headline)

            tipRow("Get a professional detail before listing")
            tipRow("Fix minor cosmetic issues (dents, scratches)")
            tipRow("Gather all service records and receipts")
            tipRow("List during peak season (spring/summer)")
            tipRow("Get valuations from multiple sources")

            if analysis.retainedValuePercent > 70 {
                tipRow("Your vehicle holds value well — consider private sale over trade-in for best return")
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }

    // MARK: - Helper Views

    private func insightRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.caption)
                .foregroundColor(.yellow)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Data

    private func runAnalysis() {
        let monthlyCosts: Double = {
            guard !costEntries.isEmpty else { return 0 }
            let total = costEntries.reduce(0.0) { $0 + $1.amount }
            let months = max(
                Calendar.current.dateComponents([.month], from: vehicle.purchaseDate, to: Date()).month ?? 1, 1
            )
            return total / Double(months)
        }()

        let loanBalance: Double? = loans.first?.currentBalance

        analysis = SellAdvisorService.shared.analyze(
            vehicle: vehicle,
            valuationSnapshots: Array(valuationSnapshots),
            monthlyCosts: monthlyCosts,
            loanBalance: loanBalance
        )
    }

    private func buildHistoricalPoints() -> [ChartPoint] {
        var points: [ChartPoint] = []

        points.append(ChartPoint(date: vehicle.purchaseDate, value: vehicle.purchasePrice))

        for snapshot in valuationSnapshots {
            points.append(ChartPoint(date: snapshot.date, value: snapshot.estimatedValue))
        }

        if let last = points.last, !Calendar.current.isDateInToday(last.date) {
            points.append(ChartPoint(date: Date(), value: vehicle.currentValue))
        }

        return points
    }

    // MARK: - Formatting

    private func verdictColor(_ verdict: SellVerdict) -> Color {
        switch verdict {
        case .sellSoon: return .green
        case .consider: return .orange
        case .holdOff: return .blue
        }
    }

    private func verdictIcon(_ verdict: SellVerdict) -> String {
        switch verdict {
        case .sellSoon: return "checkmark.seal.fill"
        case .consider: return "exclamationmark.triangle.fill"
        case .holdOff: return "hand.raised.fill"
        }
    }

    private func trendColor(_ trend: ValueTrend) -> Color {
        switch trend {
        case .rising: return .green
        case .stable: return .blue
        case .declining: return .red
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Chart Point

private struct ChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}
