import SwiftUI
import Charts
import CoreData

struct TotalCostOfOwnershipView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    let vehicle: VehicleEntity
    
    @FetchRequest private var costEntries: FetchedResults<CostEntryEntity>
    @FetchRequest private var fuelEntries: FetchedResults<FuelEntryEntity>
    
    init(vehicle: VehicleEntity) {
        self.vehicle = vehicle
        
        _costEntries = FetchRequest<CostEntryEntity>(
            sortDescriptors: [NSSortDescriptor(keyPath: \CostEntryEntity.date, ascending: true)],
            predicate: NSPredicate(format: "vehicleID == %@", vehicle.id as CVarArg),
            animation: .default
        )
        
        _fuelEntries = FetchRequest<FuelEntryEntity>(
            sortDescriptors: [NSSortDescriptor(keyPath: \FuelEntryEntity.date, ascending: true)],
            predicate: NSPredicate(format: "vehicleID == %@", vehicle.id as CVarArg),
            animation: .default
        )
    }
    
    // MARK: - Computed Properties
    
    private var monthsOwned: Int {
        max(Calendar.current.dateComponents([.month], from: vehicle.purchaseDate, to: Date()).month ?? 1, 1)
    }
    
    private var totalMaintenanceCost: Double {
        costEntries.filter { $0.category != "Fuel" }.reduce(0) { $0 + $1.amount }
    }
    
    private var totalFuelCost: Double {
        fuelEntries.reduce(0) { $0 + $1.cost }
    }
    
    private var totalInsuranceCost: Double {
        guard vehicle.insurancePremium > 0 else { return 0 }
        return vehicle.insurancePremium * (Double(monthsOwned) / 12.0)
    }
    
    private var depreciation: Double {
        max(vehicle.purchasePrice - vehicle.currentValue, 0)
    }
    
    private var totalCostOfOwnership: Double {
        depreciation + totalMaintenanceCost + totalFuelCost + totalInsuranceCost
    }
    
    private var costPerMonth: Double {
        totalCostOfOwnership / Double(monthsOwned)
    }
    
    private var costPerMile: Double {
        guard vehicle.mileage > 0 else { return 0 }
        let purchaseMileage = max(Int(vehicle.mileage) - (monthsOwned * 1000), 0)
        let milesDriven = Int(vehicle.mileage) - purchaseMileage
        guard milesDriven > 0 else { return 0 }
        return totalCostOfOwnership / Double(milesDriven)
    }
    
    private var pieData: [(category: String, amount: Double, color: Color)] {
        var data: [(String, Double, Color)] = []
        if depreciation > 0 { data.append(("Depreciation", depreciation, .red)) }
        if totalMaintenanceCost > 0 { data.append(("Maintenance", totalMaintenanceCost, .orange)) }
        if totalFuelCost > 0 { data.append(("Fuel", totalFuelCost, .cyan)) }
        if totalInsuranceCost > 0 { data.append(("Insurance", totalInsuranceCost, .purple)) }
        return data
    }
    
    private var monthlyCostData: [(month: Date, maintenance: Double, fuel: Double, insurance: Double)] {
        var monthlyData: [String: (maintenance: Double, fuel: Double, insurance: Double, date: Date)] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        
        for entry in costEntries {
            let key = formatter.string(from: entry.date)
            var existing = monthlyData[key] ?? (0, 0, 0, entry.date)
            if entry.category == "Fuel" {
                existing.fuel += entry.amount
            } else {
                existing.maintenance += entry.amount
            }
            existing.date = entry.date
            monthlyData[key] = existing
        }
        
        for entry in fuelEntries {
            let key = formatter.string(from: entry.date)
            var existing = monthlyData[key] ?? (0, 0, 0, entry.date)
            existing.fuel += entry.cost
            existing.date = entry.date
            monthlyData[key] = existing
        }
        
        let monthlyInsurance = vehicle.insurancePremium / 12.0
        if monthlyInsurance > 0 {
            for (key, var value) in monthlyData {
                value.insurance = monthlyInsurance
                monthlyData[key] = value
            }
        }
        
        return monthlyData.values
            .sorted { $0.date < $1.date }
            .suffix(12)
            .map { (month: $0.date, maintenance: $0.maintenance, fuel: $0.fuel, insurance: $0.insurance) }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    totalCostHeader
                    quickStatsRow
                    costBreakdownChart
                    if monthlyCostData.count >= 2 {
                        monthlyTrendChart
                    }
                    costCategoryBreakdown
                }
                .padding(.vertical)
            }
            .navigationTitle("Cost of Ownership")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
    
    // MARK: - Total Cost Header
    
    private var totalCostHeader: some View {
        VStack(spacing: 12) {
            Text("Total Cost of Ownership")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("$\(Int(totalCostOfOwnership))")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.primary)
            
            Text("\(monthsOwned) months of ownership")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
    
    // MARK: - Quick Stats
    
    private var quickStatsRow: some View {
        HStack(spacing: 12) {
            QuickStatCard(title: "Per Month", value: "$\(Int(costPerMonth))", icon: "calendar", color: .blue)
            QuickStatCard(title: "Per Mile", value: "$\(String(format: "%.2f", costPerMile))", icon: "road.lanes", color: .green)
            QuickStatCard(title: "Per Day", value: "$\(Int(costPerMonth / 30))", icon: "clock", color: .orange)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Cost Breakdown Pie Chart
    
    private var costBreakdownChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cost Breakdown")
                .font(.headline)
            
            if pieData.isEmpty {
                Text("No cost data yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 30)
            } else {
                Chart(pieData, id: \.category) { item in
                    SectorMark(
                        angle: .value("Amount", item.amount),
                        innerRadius: .ratio(0.6),
                        angularInset: 2
                    )
                    .foregroundStyle(item.color)
                    .cornerRadius(4)
                }
                .frame(height: 200)
                
                // Legend
                VStack(spacing: 8) {
                    ForEach(pieData, id: \.category) { item in
                        HStack {
                            Circle()
                                .fill(item.color)
                                .frame(width: 10, height: 10)
                            Text(item.category)
                                .font(.subheadline)
                            Spacer()
                            Text("$\(Int(item.amount))")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            let pct = totalCostOfOwnership > 0 ? (item.amount / totalCostOfOwnership) * 100 : 0
                            Text("(\(Int(pct))%)")
                                .font(.caption)
                                .foregroundColor(.secondary)
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
    }
    
    // MARK: - Monthly Trend Chart
    
    private var monthlyTrendChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Monthly Spending Trend")
                .font(.headline)
            
            Chart {
                ForEach(monthlyCostData, id: \.month) { item in
                    let total = item.maintenance + item.fuel + item.insurance
                    BarMark(
                        x: .value("Month", item.month, unit: .month),
                        y: .value("Amount", total)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .cyan], startPoint: .bottom, endPoint: .top)
                    )
                    .cornerRadius(4)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text("$\(Int(amount))")
                        }
                    }
                }
            }
            .frame(height: 200)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
    
    // MARK: - Category Breakdown
    
    private var costCategoryBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detailed Breakdown")
                .font(.headline)
                .padding(.horizontal)
            
            CostBreakdownRow(icon: "arrow.down.right.circle.fill", color: .red,
                             title: "Depreciation", subtitle: "Purchase price minus current value",
                             amount: depreciation)
            
            CostBreakdownRow(icon: "wrench.and.screwdriver.fill", color: .orange,
                             title: "Maintenance & Repairs", subtitle: "\(costEntries.filter { $0.category != "Fuel" }.count) entries",
                             amount: totalMaintenanceCost)
            
            CostBreakdownRow(icon: "fuelpump.fill", color: .cyan,
                             title: "Fuel", subtitle: "\(fuelEntries.count) fill-ups",
                             amount: totalFuelCost)
            
            CostBreakdownRow(icon: "shield.checkered", color: .purple,
                             title: "Insurance", subtitle: vehicle.insuranceProvider ?? "Not set",
                             amount: totalInsuranceCost)
            
            Divider().padding(.horizontal)
            
            HStack {
                Text("Total")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text("$\(Int(totalCostOfOwnership))")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
}

// MARK: - Supporting Views

struct QuickStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct CostBreakdownRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let amount: Double
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 36)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("$\(Int(amount))")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}
