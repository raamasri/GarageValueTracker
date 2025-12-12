import SwiftUI
import SwiftData

struct VehicleDetailView: View {
    @Bindable var vehicle: VehicleEntity
    @Environment(\.modelContext) private var modelContext
    
    @State private var valuation: ValuationEstimateResponse?
    @State private var pnl: PnLComputeResponse?
    @State private var showingAddCost = false
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                vehicleHeaderCard
                
                if isLoading {
                    ProgressView()
                        .padding()
                } else {
                    // Market Valuation
                    if let val = valuation {
                        marketValuationCard(val)
                    }
                    
                    // P&L Performance (owned only)
                    if vehicle.ownershipType == .owned, let pnlData = pnl {
                        pnlPerformanceCard(pnlData)
                    }
                    
                    // Cost Ledger (owned only)
                    if vehicle.ownershipType == .owned {
                        costLedgerSection
                    }
                    
                    // Watchlist Settings
                    if vehicle.ownershipType == .watchlist {
                        watchlistSettingsCard
                    }
                }
            }
            .padding()
        }
        .navigationTitle(vehicle.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddCost) {
            AddCostEntryView(vehicle: vehicle)
        }
        .task {
            await loadData()
        }
    }
    
    // MARK: - Vehicle Header
    
    @ViewBuilder
    private var vehicleHeaderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicle.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(vehicle.transmission)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: vehicle.ownershipType == .owned ? "car.fill" : "star.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentColor.opacity(0.3))
            }
            
            Divider()
            
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mileage")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatMileage(vehicle.mileageCurrent))
                        .font(.body)
                        .fontWeight(.semibold)
                }
                
                if let vin = vehicle.vin {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("VIN")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(vin.suffix(8)))
                            .font(.body)
                            .fontWeight(.semibold)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Location")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(vehicle.zip)
                        .font(.body)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
    
    // MARK: - Market Valuation Card
    
    private func marketValuationCard(_ val: ValuationEstimateResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Market Valuation")
                    .font(.headline)
                
                Spacer()
                
                recommendationBadge(val.recommendation)
            }
            
            // Value Range
            VStack(spacing: 8) {
                HStack {
                    Text(formatCurrency(val.mid))
                        .font(.system(size: 36, weight: .bold))
                    
                    Spacer()
                }
                
                HStack(spacing: 4) {
                    Text("Range: \(formatCurrency(val.low)) - \(formatCurrency(val.high))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    confidenceBadge(val.confidence)
                }
            }
            
            Divider()
            
            // Metrics Grid
            HStack(spacing: 0) {
                metricColumn(
                    title: "90d Momentum",
                    value: String(format: "%.1f%%", val.momentum90d),
                    color: val.momentum90d >= 0 ? .green : .red,
                    icon: val.momentum90d >= 0 ? "arrow.up.right" : "arrow.down.right"
                )
                
                Divider()
                    .frame(height: 50)
                
                metricColumn(
                    title: "Liquidity",
                    value: "\(Int(val.liquidityScore * 100))/100",
                    color: val.liquidityScore > 0.5 ? .green : .orange,
                    icon: "chart.bar"
                )
                
                Divider()
                    .frame(height: 50)
                
                metricColumn(
                    title: "Sample Size",
                    value: "\(val.sampleSize)",
                    color: .blue,
                    icon: "chart.line.uptrend.xyaxis"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
    
    // MARK: - P&L Performance Card
    
    private func pnlPerformanceCard(_ pnlData: PnLComputeResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ownership Performance")
                .font(.headline)
            
            // Unrealized P&L - Big Number
            VStack(alignment: .leading, spacing: 4) {
                Text("Unrealized P&L")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(formatCurrency(pnlData.unrealizedPnL))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(pnlData.unrealizedPnL >= 0 ? .green : .red)
            }
            
            Divider()
            
            // Detailed Breakdown
            VStack(spacing: 12) {
                pnlRow(label: "Purchase Price", value: formatCurrency(vehicle.purchasePrice ?? 0))
                pnlRow(label: "Total Costs", value: formatCurrency(pnlData.totalCosts))
                pnlRow(label: "Total Basis", value: formatCurrency(pnlData.basis), isBold: true)
                
                Divider()
                
                pnlRow(label: "Current Market Value", value: formatCurrency(pnlData.currentValue), isBold: true)
                pnlRow(
                    label: "Cumulative Depreciation",
                    value: formatCurrency(pnlData.cumulativeDepreciation),
                    valueColor: .red
                )
                
                Divider()
                
                pnlRow(
                    label: "Avg Monthly Cost",
                    value: formatCurrency(pnlData.avgMonthlyCost) + "/mo",
                    isBold: true,
                    valueColor: .orange
                )
            }
            
            if let purchaseDate = vehicle.purchaseDate {
                Text("Owned since \(purchaseDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
    
    // MARK: - Cost Ledger Section
    
    private var costLedgerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Cost Ledger")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    showingAddCost = true
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                }
            }
            
            if let costs = vehicle.costEntries, !costs.isEmpty {
                ForEach(costs.sorted(by: { $0.date > $1.date })) { cost in
                    costEntryRow(cost)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "receipt")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    
                    Text("No costs recorded yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Button {
                        showingAddCost = true
                    } label: {
                        Text("Add First Cost")
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
    
    private func costEntryRow(_ cost: CostEntryEntity) -> some View {
        HStack(spacing: 12) {
                Image(systemName: cost.category.icon)
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(cost.category.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(cost.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if !cost.notes.isEmpty {
                    Text(cost.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Text(formatCurrency(cost.amount))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Watchlist Settings Card
    
    private var watchlistSettingsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Watchlist Settings")
                .font(.headline)
            
            Toggle("Price Alerts", isOn: $vehicle.alertEnabled)
            
            if vehicle.alertEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Alert me when price drops to:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if let target = vehicle.targetPrice {
                        Text(formatCurrency(target))
                            .font(.title3)
                            .fontWeight(.semibold)
                    } else {
                        Text("Not set")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
    
    // MARK: - Helper Views
    
    private func metricColumn(title: String, value: String, color: Color, icon: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
    }
    
    private func pnlRow(label: String, value: String, isBold: Bool = false, valueColor: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(isBold ? .subheadline.weight(.semibold) : .subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(isBold ? .body.weight(.semibold) : .body)
                .foregroundStyle(valueColor)
        }
    }
    
    private func recommendationBadge(_ recommendation: String) -> some View {
        let (text, color): (String, Color) = {
            switch recommendation {
            case "hold": return ("Hold", .green)
            case "consider_selling": return ("Consider Sell", .orange)
            case "strong_sell": return ("Strong Sell", .red)
            default: return (recommendation, .gray)
            }
        }()
        
        return Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
    
    private func confidenceBadge(_ confidence: String) -> some View {
        let color: Color = {
            switch confidence.lowercased() {
            case "high": return .green
            case "medium": return .orange
            default: return .red
            }
        }()
        
        return Text(confidence.capitalized)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
    
    // MARK: - Data Loading
    
    private func loadData() async {
        isLoading = true
        
        // Load valuation
        do {
            let valuationRequest = ValuationEstimateRequest(
                vehicleId: vehicle.id.uuidString,
                mileage: vehicle.mileageCurrent,
                zip: vehicle.zip
            )
            valuation = try await MarketAPIService.shared.getValuationEstimate(valuationRequest)
            
            // Save valuation snapshot
            if let val = valuation {
                let snapshot = ValuationSnapshotEntity(
                    date: Date(),
                    low: val.low,
                    mid: val.mid,
                    high: val.high,
                    confidence: ConfidenceLevel(rawValue: val.confidence.capitalized) ?? .low,
                    sampleSize: val.sampleSize,
                    momentum90d: val.momentum90d,
                    liquidityScore: val.liquidityScore,
                    recommendation: Recommendation(rawValue: val.recommendation.replacingOccurrences(of: "_", with: " ").capitalized.replacingOccurrences(of: "Selling", with: "Sell"))
                )
                snapshot.vehicle = vehicle
                modelContext.insert(snapshot)
            }
            
            // Load P&L if owned vehicle
            if vehicle.ownershipType == .owned,
               let purchasePrice = vehicle.purchasePrice,
               let purchaseDate = vehicle.purchaseDate,
               let currentMid = valuation?.mid {
                
                let formatter = ISO8601DateFormatter()
                let costEntries = (vehicle.costEntries ?? []).map { cost in
                    CostEntryData(
                        date: formatter.string(from: cost.date),
                        category: cost.category.rawValue.lowercased(),
                        amount: cost.amount
                    )
                }
                
                let pnlRequest = PnLComputeRequest(
                    vehicleId: vehicle.id.uuidString,
                    purchasePrice: purchasePrice,
                    purchaseDate: formatter.string(from: purchaseDate),
                    costEntries: costEntries,
                    currentMarketMid: currentMid
                )
                
                pnl = try await MarketAPIService.shared.computePnL(pnlRequest)
            }
        } catch {
            print("Failed to load data: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Formatters
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
    
    private func formatMileage(_ mileage: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return "\(formatter.string(from: NSNumber(value: mileage)) ?? "0") mi"
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: VehicleEntity.self, configurations: config)
    
    let vehicle = VehicleEntity(
        ownershipType: .owned,
        year: 2022,
        make: "Toyota",
        model: "GR86",
        trim: "Premium",
        transmission: "Manual",
        mileageCurrent: 32000,
        zip: "95126",
        purchasePrice: 32000,
        purchaseDate: Date(timeIntervalSinceNow: -365*24*3600),
        purchaseMileage: 15000
    )
    container.mainContext.insert(vehicle)
    
    return NavigationStack {
        VehicleDetailView(vehicle: vehicle)
    }
    .modelContainer(container)
}

