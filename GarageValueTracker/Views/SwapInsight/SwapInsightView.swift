import SwiftUI
import SwiftData

struct SwapInsightView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query private var allVehicles: [VehicleEntity]
    
    private var ownedVehicles: [VehicleEntity] {
        allVehicles.filter { $0.ownershipType == .owned }
    }
    
    private var watchlistVehicles: [VehicleEntity] {
        allVehicles.filter { $0.ownershipType == .watchlist }
    }
    
    @State private var selectedOwnedId: UUID?
    @State private var selectedWatchlistId: UUID?
    @State private var swapResult: SwapInsightResponse?
    @State private var isAnalyzing = false
    
    var body: some View {
        NavigationStack {
            Form {
                if ownedVehicles.isEmpty || watchlistVehicles.isEmpty {
                    emptyStateSection
                } else {
                    vehicleSelectionSection
                    
                    if swapResult != nil {
                        resultsSection
                    }
                    
                    analyzeButtonSection
                }
            }
            .navigationTitle("Swap Insight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private var emptyStateSection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "arrow.triangle.swap")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                
                Text("Need Both Garage & Watchlist")
                    .font(.headline)
                
                Text("Add at least one owned vehicle and one watchlist vehicle to compare swap scenarios.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
    }
    
    private var vehicleSelectionSection: some View {
        Group {
            Section("Current Vehicle (Owned)") {
                Picker("Select Vehicle", selection: $selectedOwnedId) {
                    Text("Select...").tag(nil as UUID?)
                    ForEach(ownedVehicles) { vehicle in
                        Text(vehicle.displayName).tag(vehicle.id as UUID?)
                    }
                }
                .onChange(of: selectedOwnedId) { _, _ in
                    swapResult = nil
                }
            }
            
            Section("Alternative Vehicle (Watchlist)") {
                Picker("Select Vehicle", selection: $selectedWatchlistId) {
                    Text("Select...").tag(nil as UUID?)
                    ForEach(watchlistVehicles) { vehicle in
                        Text(vehicle.displayName).tag(vehicle.id as UUID?)
                    }
                }
                .onChange(of: selectedWatchlistId) { _, _ in
                    swapResult = nil
                }
            }
        }
    }
    
    private var resultsSection: some View {
        Group {
            if let result = swapResult {
                Section("Current Vehicle") {
                    depreciationRow(label: "3-Year Depreciation", pct: result.current.expected3yrDeprPct, usd: result.current.expected3yrDeprUsd)
                    costRow(label: "Monthly Cost", value: result.current.monthlyCost)
                }
                
                Section("Alternative Vehicle") {
                    depreciationRow(label: "3-Year Depreciation", pct: result.alt.expected3yrDeprPct, usd: result.alt.expected3yrDeprUsd)
                    costRow(label: "Monthly Cost (Est.)", value: result.alt.monthlyCost)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Verdict")
                            .font(.headline)
                        
                        if result.verdict.deprDropPctPoints > 0 {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.green)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Better Depreciation")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    Text(String(format: "Expected 3-year depreciation drops by %.1f percentage points", result.verdict.deprDropPctPoints))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            HStack(spacing: 12) {
                                Image(systemName: "dollarsign.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.green)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Potential Savings")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    Text(formatCurrency(result.verdict.expectedSavings3yr) + " over 3 years")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.orange)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Higher Depreciation")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    Text("Alternative may depreciate more")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Monthly Cost Delta")
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Text(formatCurrency(result.verdict.monthlyCostDelta) + "/mo")
                                .fontWeight(.semibold)
                                .foregroundStyle(result.verdict.monthlyCostDelta <= 0 ? .green : .red)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
    
    private var analyzeButtonSection: some View {
        Section {
            Button {
                Task {
                    await analyzeSwap()
                }
            } label: {
                HStack {
                    if isAnalyzing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Analyze Swap")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .disabled(!canAnalyze || isAnalyzing)
            .listRowBackground(canAnalyze && !isAnalyzing ? Color.accentColor : Color.gray.opacity(0.3))
            .foregroundStyle(.white)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }
    
    // MARK: - Helper Views
    
    private func depreciationRow(label: String, pct: Double, usd: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(format: "%.0f%%", pct))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.red)
                
                Text(formatCurrency(usd))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func costRow(label: String, value: Double) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(formatCurrency(value) + "/mo")
                .fontWeight(.semibold)
        }
    }
    
    // MARK: - Logic
    
    private var canAnalyze: Bool {
        selectedOwnedId != nil && selectedWatchlistId != nil
    }
    
    private func analyzeSwap() async {
        guard let ownedId = selectedOwnedId,
              let watchlistId = selectedWatchlistId,
              let ownedVehicle = ownedVehicles.first(where: { $0.id == ownedId }),
              let watchlistVehicle = watchlistVehicles.first(where: { $0.id == watchlistId }) else {
            return
        }
        
        isAnalyzing = true
        
        do {
            // Get current market value for owned vehicle
            let valuationRequest = ValuationEstimateRequest(
                vehicleId: ownedVehicle.id.uuidString,
                mileage: ownedVehicle.mileageCurrent,
                zip: ownedVehicle.zip
            )
            let valuation = try await MarketAPIService.shared.getValuationEstimate(valuationRequest)
            
            // Get alternative entry price (use target or market mid)
            let altValuationRequest = ValuationEstimateRequest(
                vehicleId: watchlistVehicle.id.uuidString,
                mileage: watchlistVehicle.mileageCurrent,
                zip: watchlistVehicle.zip
            )
            let altValuation = try await MarketAPIService.shared.getValuationEstimate(altValuationRequest)
            let altEntryPrice = watchlistVehicle.targetPrice ?? altValuation.mid
            
            // Analyze swap
            let request = SwapInsightRequest(
                currentVehicleId: ownedVehicle.id.uuidString,
                altVehicleId: watchlistVehicle.id.uuidString,
                currentMarketMid: valuation.mid,
                altEntryPrice: altEntryPrice,
                regionBucket: ownedVehicle.regionBucket ?? "general"
            )
            
            swapResult = try await MarketAPIService.shared.getSwapInsight(request)
        } catch {
            print("Failed to analyze swap: \(error)")
        }
        
        isAnalyzing = false
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

#Preview {
    SwapInsightView()
        .modelContainer(for: VehicleEntity.self, inMemory: true)
}

