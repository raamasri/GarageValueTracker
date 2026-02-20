import SwiftUI
import Charts
import CoreData

struct DepreciationChartView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    let vehicle: VehicleEntity
    
    @FetchRequest private var valuationSnapshots: FetchedResults<ValuationSnapshotEntity>
    
    @State private var chartData: [ValuePoint] = []
    @State private var selectedPoint: ValuePoint?
    
    init(vehicle: VehicleEntity) {
        self.vehicle = vehicle
        
        _valuationSnapshots = FetchRequest<ValuationSnapshotEntity>(
            sortDescriptors: [NSSortDescriptor(keyPath: \ValuationSnapshotEntity.date, ascending: true)],
            predicate: NSPredicate(format: "vehicleID == %@", vehicle.id as CVarArg),
            animation: .default
        )
    }
    
    private var msrp: Double {
        vehicle.trimMSRP > 0 ? vehicle.trimMSRP : vehicle.purchasePrice
    }
    
    private var totalDepreciation: Double {
        max(msrp - vehicle.currentValue, 0)
    }
    
    private var depreciationPercent: Double {
        guard msrp > 0 else { return 0 }
        return (totalDepreciation / msrp) * 100
    }
    
    private var yearlyDepreciationRate: Double {
        let age = max(Calendar.current.dateComponents([.year], from: vehicle.purchaseDate, to: Date()).year ?? 1, 1)
        guard msrp > 0 else { return 0 }
        return (totalDepreciation / msrp / Double(age)) * 100
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    valueHeader
                    depreciationStatsRow
                    valueOverTimeChart
                    projectionSection
                    milestoneSection
                }
                .padding(.vertical)
            }
            .navigationTitle("Value Over Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .onAppear { buildChartData() }
        }
    }
    
    // MARK: - Value Header
    
    private var valueHeader: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Value")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(Int(vehicle.currentValue))")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Original Price")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(Int(msrp))")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    if totalDepreciation > 0 {
                        Text("-$\(Int(totalDepreciation))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Depreciation progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)
                    
                    let retainedPercent = max(100 - depreciationPercent, 0) / 100.0
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(colors: [.green, retainedPercent > 0.5 ? .green : .orange],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: geometry.size.width * retainedPercent, height: 12)
                }
            }
            .frame(height: 12)
            
            HStack {
                Text("\(Int(max(100 - depreciationPercent, 0)))% value retained")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(String(format: "%.1f", depreciationPercent))% depreciated")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
    
    // MARK: - Stats Row
    
    private var depreciationStatsRow: some View {
        HStack(spacing: 12) {
            QuickStatCard(
                title: "Per Year",
                value: "-\(String(format: "%.1f", yearlyDepreciationRate))%",
                icon: "calendar",
                color: .red
            )
            QuickStatCard(
                title: "Lost Value",
                value: "-$\(Int(totalDepreciation))",
                icon: "arrow.down.right",
                color: .orange
            )
            
            let age = max(Calendar.current.dateComponents([.year], from: vehicle.purchaseDate, to: Date()).year ?? 1, 1)
            QuickStatCard(
                title: "Vehicle Age",
                value: "\(age) yr\(age == 1 ? "" : "s")",
                icon: "clock",
                color: .blue
            )
        }
        .padding(.horizontal)
    }
    
    // MARK: - Value Over Time Chart
    
    private var valueOverTimeChart: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                ForEach(chartData.filter { !$0.isProjection }) { point in
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
                
                ForEach(chartData.filter { $0.isProjection }) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(.orange.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                }
                
                if let selected = selectedPoint {
                    RuleMark(x: .value("Date", selected.date))
                        .foregroundStyle(.gray.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .top) {
                            VStack(spacing: 2) {
                                Text("$\(Int(selected.value))")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                Text(selected.label)
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
                                        selectedPoint = chartData.min(by: {
                                            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                        })
                                    }
                                }
                                .onEnded { _ in
                                    selectedPoint = nil
                                }
                        )
                }
            }
            .frame(height: 250)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
    
    // MARK: - Projection Section
    
    private var projectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Future Projections")
                .font(.headline)
            
            let projections = chartData.filter { $0.isProjection }
            ForEach(projections) { point in
                HStack {
                    Text(point.label)
                        .font(.subheadline)
                    Spacer()
                    Text("$\(Int(point.value))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    let loss = vehicle.currentValue - point.value
                    if loss > 0 {
                        Text("-$\(Int(loss))")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(.vertical, 4)
                
                if point.id != projections.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
    
    // MARK: - Milestone Section
    
    private var milestoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Value Milestones")
                .font(.headline)
            
            let milestones: [(String, Double)] = [
                ("75% of purchase price", msrp * 0.75),
                ("50% of purchase price", msrp * 0.50),
                ("25% of purchase price", msrp * 0.25)
            ]
            
            ForEach(milestones, id: \.0) { (label, threshold) in
                HStack {
                    Image(systemName: vehicle.currentValue <= threshold ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(vehicle.currentValue <= threshold ? .orange : .green)
                    
                    Text(label)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("$\(Int(threshold))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if vehicle.currentValue > threshold {
                        let yearsUntil = estimateYearsUntilValue(threshold)
                        Text("~\(yearsUntil) yr\(yearsUntil == 1 ? "" : "s")")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    } else {
                        Text("Passed")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
    
    // MARK: - Data Building
    
    private func buildChartData() {
        var points: [ValuePoint] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        
        // Purchase point
        points.append(ValuePoint(
            date: vehicle.purchaseDate,
            value: vehicle.purchasePrice,
            label: "Purchased",
            isProjection: false
        ))
        
        // Historical snapshots
        for snapshot in valuationSnapshots {
            points.append(ValuePoint(
                date: snapshot.date,
                value: snapshot.estimatedValue,
                label: formatter.string(from: snapshot.date),
                isProjection: false
            ))
        }
        
        // Current value (if not already the last snapshot)
        let today = Date()
        if points.last?.date != today {
            points.append(ValuePoint(
                date: today,
                value: vehicle.currentValue,
                label: "Today",
                isProjection: false
            ))
        }
        
        // Future projections (1-5 years)
        let make = vehicle.make
        let model = vehicle.model
        var projectedValue = vehicle.currentValue
        
        for yearOffset in 1...5 {
            let futureDate = Calendar.current.date(byAdding: .year, value: yearOffset, to: today)!
            
            let rate = getSubsequentDepreciationRate(make: make, model: model)
            projectedValue *= (1.0 - rate)
            
            let yearLabel = Calendar.current.component(.year, from: futureDate)
            points.append(ValuePoint(
                date: futureDate,
                value: max(projectedValue, msrp * 0.05),
                label: String(yearLabel),
                isProjection: true
            ))
        }
        
        chartData = points
    }
    
    private func getSubsequentDepreciationRate(make: String, model: String) -> Double {
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
    
    private func estimateYearsUntilValue(_ target: Double) -> Int {
        let rate = getSubsequentDepreciationRate(make: vehicle.make, model: vehicle.model)
        var value = vehicle.currentValue
        var years = 0
        while value > target && years < 20 {
            value *= (1.0 - rate)
            years += 1
        }
        return years
    }
}

// MARK: - Value Point Model

struct ValuePoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let label: String
    let isProjection: Bool
}
