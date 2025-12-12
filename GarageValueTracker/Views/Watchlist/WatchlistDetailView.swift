import SwiftUI
import SwiftData

struct WatchlistDetailView: View {
    @Bindable var vehicle: VehicleEntity
    @Environment(\.modelContext) private var modelContext
    
    @State private var valuation: ValuationEstimateResponse?
    @State private var isLoading = true
    @State private var targetPriceString = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Vehicle Header
                vehicleHeaderCard
                
                if isLoading {
                    ProgressView()
                        .padding()
                } else {
                    // Market Valuation
                    if let val = valuation {
                        marketValuationCard(val)
                    }
                    
                    // Target Price & Alerts
                    alertSettingsCard
                    
                    // Expected Depreciation
                    depreciationCard
                    
                    // Suggested Entry Strategy
                    entryStrategyCard
                }
            }
            .padding()
        }
        .navigationTitle(vehicle.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
        .onAppear {
            targetPriceString = vehicle.targetPrice.map { String(Int($0)) } ?? ""
        }
    }
    
    // MARK: - Vehicle Header
    
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
                
                Image(systemName: "star.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.yellow.opacity(0.6))
            }
            
            Divider()
            
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Target Mileage")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatMileage(vehicle.mileageCurrent))
                        .font(.body)
                        .fontWeight(.semibold)
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
            Text("Current Market")
                .font(.headline)
            
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
                }
            }
            
            Divider()
            
            HStack(spacing: 0) {
                metricColumn(
                    title: "90d Momentum",
                    value: String(format: "%.1f%%", val.momentum90d),
                    color: val.momentum90d >= 0 ? .green : .red
                )
                
                Divider()
                    .frame(height: 50)
                
                metricColumn(
                    title: "Liquidity",
                    value: "\(Int(val.liquidityScore * 100))/100",
                    color: .blue
                )
                
                Divider()
                    .frame(height: 50)
                
                metricColumn(
                    title: "Sample Size",
                    value: "\(val.sampleSize)",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
    
    // MARK: - Alert Settings Card
    
    private var alertSettingsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Price Alerts")
                .font(.headline)
            
            Toggle("Enable Alerts", isOn: $vehicle.alertEnabled)
            
            if vehicle.alertEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Alert me when market price drops to:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Text("$")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        
                        TextField("Target Price", text: $targetPriceString)
                            .keyboardType(.numberPad)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .onChange(of: targetPriceString) { oldValue, newValue in
                                if let price = Double(newValue) {
                                    vehicle.targetPrice = price
                                }
                            }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    if let currentMid = valuation?.mid, let target = vehicle.targetPrice {
                        let difference = currentMid - target
                        let percentDiff = (difference / currentMid) * 100
                        
                        HStack {
                            Image(systemName: difference > 0 ? "arrow.down" : "arrow.up")
                                .foregroundStyle(difference > 0 ? .green : .red)
                            
                            Text("\(formatCurrency(abs(difference))) (\(String(format: "%.1f%%", abs(percentDiff)))) \(difference > 0 ? "below" : "above") current market")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
    
    // MARK: - Depreciation Card
    
    private var depreciationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Expected Depreciation")
                .font(.headline)
            
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("1 Year")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("-8%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                    if let mid = valuation?.mid {
                        Text(formatCurrency(mid * 0.92))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                    .frame(height: 60)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("3 Years")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("-22%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.red)
                    if let mid = valuation?.mid {
                        Text(formatCurrency(mid * 0.78))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Text("Based on similar vehicles in your region")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
    
    // MARK: - Entry Strategy Card
    
    private var entryStrategyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Entry Strategy")
                .font(.headline)
            
            if let val = valuation {
                VStack(alignment: .leading, spacing: 12) {
                    strategyRow(
                        label: "Fair Entry",
                        price: val.mid * 0.95,
                        description: "5% below market mid"
                    )
                    
                    Divider()
                    
                    strategyRow(
                        label: "Good Deal",
                        price: val.low,
                        description: "At market low estimate"
                    )
                    
                    Divider()
                    
                    strategyRow(
                        label: "Steal",
                        price: val.low * 0.95,
                        description: "5% below market low"
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
    
    // MARK: - Helper Views
    
    private func metricColumn(title: String, value: String, color: Color) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
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
    
    private func strategyRow(label: String, price: Double, description: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(formatCurrency(price))
                .font(.body)
                .fontWeight(.semibold)
        }
    }
    
    // MARK: - Data Loading
    
    private func loadData() async {
        isLoading = true
        
        do {
            let valuationRequest = ValuationEstimateRequest(
                vehicleId: vehicle.id.uuidString,
                mileage: vehicle.mileageCurrent,
                zip: vehicle.zip
            )
            valuation = try await MarketAPIService.shared.getValuationEstimate(valuationRequest)
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
        ownershipType: .watchlist,
        year: 2024,
        make: "Mazda",
        model: "MX-5 Miata",
        trim: "Club",
        transmission: "Manual",
        mileageCurrent: 5000,
        zip: "95126",
        targetPrice: 30000,
        alertEnabled: true
    )
    container.mainContext.insert(vehicle)
    
    return NavigationStack {
        WatchlistDetailView(vehicle: vehicle)
    }
    .modelContainer(container)
}

