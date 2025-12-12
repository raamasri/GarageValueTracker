import SwiftUI
import SwiftData

struct UpgradePathView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query private var allVehicles: [VehicleEntity]
    
    private var ownedVehicles: [VehicleEntity] {
        allVehicles.filter { $0.ownershipType == .owned }
    }
    
    @State private var selectedVehicleId: UUID?
    @State private var targetBudget = ""
    @State private var timeframe = 12
    @State private var annualMileage = "12000"
    @State private var upgradePath: UpgradePathResponse?
    @State private var isAnalyzing = false
    
    var body: some View {
        NavigationStack {
            Form {
                if ownedVehicles.isEmpty {
                    emptyStateSection
                } else {
                    inputSection
                    
                    if upgradePath != nil {
                        resultsSection
                    }
                    
                    analyzeButtonSection
                }
            }
            .navigationTitle("Upgrade Path")
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
                Image(systemName: "arrow.up.forward.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                
                Text("No Owned Vehicles")
                    .font(.headline)
                
                Text("Add a vehicle to your garage to see upgrade path recommendations.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
    }
    
    private var inputSection: some View {
        Group {
            Section {
                Picker("Select Vehicle", selection: $selectedVehicleId) {
                    Text("Select...").tag(nil as UUID?)
                    ForEach(ownedVehicles) { vehicle in
                        Text(vehicle.displayName).tag(vehicle.id as UUID?)
                    }
                }
                .onChange(of: selectedVehicleId) { _, _ in
                    upgradePath = nil
                }
            } header: {
                Text("Current Vehicle")
            }
            
            Section {
                TextField("Max Budget (Optional)", text: $targetBudget)
                    .keyboardType(.numberPad)
                
                Picker("Timeframe", selection: $timeframe) {
                    Text("6 months").tag(6)
                    Text("12 months").tag(12)
                    Text("18 months").tag(18)
                    Text("24 months").tag(24)
                }
                
                TextField("Annual Mileage", text: $annualMileage)
                    .keyboardType(.numberPad)
            } header: {
                Text("Upgrade Parameters")
            } footer: {
                Text("We'll calculate net cost including your current car's depreciation, tax/fees, and expected discounts.")
            }
        }
    }
    
    private var resultsSection: some View {
        Group {
            if let path = upgradePath {
                Section {
                    Text("Recommended Upgrade Moves")
                        .font(.headline)
                        .padding(.vertical, 4)
                } header: {
                    Text("Analysis Results")
                }
                
                ForEach(Array(path.recommendedMoves.enumerated()), id: \.offset) { index, move in
                    Section {
                        upgradeMoveCard(move, rank: index + 1)
                    }
                }
            }
        }
    }
    
    private var analyzeButtonSection: some View {
        Section {
            Button {
                Task {
                    await analyzeUpgradePath()
                }
            } label: {
                HStack {
                    if isAnalyzing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Find Upgrade Paths")
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
    
    // MARK: - Upgrade Move Card
    
    private func upgradeMoveCard(_ move: UpgradeMove, rank: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with rank
            HStack {
                Text("#\(rank)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(move.targetVehicle.make + " " + move.targetVehicle.model)
                        .font(.headline)
                    Text("\(move.targetVehicle.year) \(move.targetVehicle.trim)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
            
            // Net Cost (Big Number)
            VStack(alignment: .leading, spacing: 4) {
                Text("Net Cost Over \(timeframe) Months")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(formatCurrency(move.netCost12Months))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color.accentColor)
            }
            
            // Cost Delta
            HStack {
                Text("Monthly Cost Change:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(formatCurrency(move.costPerMonthDelta) + "/mo")
                    .font(.headline)
                    .foregroundStyle(move.costPerMonthDelta <= 0 ? .green : .red)
            }
            
            Divider()
            
            // Breakdown
            VStack(spacing: 8) {
                costBreakdownRow(label: "MSRP", value: move.targetVehicle.msrp)
                costBreakdownRow(label: "Expected Discount", value: -move.expectedDiscount, valueColor: .green)
                costBreakdownRow(label: "Expected Price", value: move.targetVehicle.expectedPrice, isBold: true)
                costBreakdownRow(label: "Tax & Fees", value: move.taxAndFees)
                costBreakdownRow(label: "Your Car Depreciation", value: move.expectedDepreciation, valueColor: .red)
                
                Divider()
                
                costBreakdownRow(label: "Net Out of Pocket", value: move.netOutOfPocket, isBold: true)
            }
            
            Divider()
            
            // Reasoning
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
                
                Text(move.reasoning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func costBreakdownRow(label: String, value: Double, isBold: Bool = false, valueColor: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(isBold ? .subheadline.weight(.semibold) : .caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(formatCurrency(value))
                .font(isBold ? .body.weight(.semibold) : .caption)
                .foregroundStyle(valueColor)
        }
    }
    
    // MARK: - Logic
    
    private var canAnalyze: Bool {
        selectedVehicleId != nil && !annualMileage.isEmpty
    }
    
    private func analyzeUpgradePath() async {
        guard let vehicleId = selectedVehicleId,
              let vehicle = ownedVehicles.first(where: { $0.id == vehicleId }) else {
            return
        }
        
        isAnalyzing = true
        
        do {
            // Get current market value
            let valuationRequest = ValuationEstimateRequest(
                vehicleId: vehicle.id.uuidString,
                mileage: vehicle.mileageCurrent,
                zip: vehicle.zip
            )
            let valuation = try await MarketAPIService.shared.getValuationEstimate(valuationRequest)
            
            // Analyze upgrade path
            let request = UpgradePathRequest(
                currentVehicleId: vehicle.id.uuidString,
                currentMarketMid: valuation.mid,
                targetBudget: targetBudget.isEmpty ? nil : Double(targetBudget),
                timeframe: timeframe,
                annualMileage: Int(annualMileage) ?? 12000,
                regionBucket: vehicle.regionBucket ?? "general"
            )
            
            upgradePath = try await MarketAPIService.shared.getUpgradePath(request)
        } catch {
            print("Failed to analyze upgrade path: \(error)")
        }
        
        isAnalyzing = false
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: abs(value))) ?? "$0"
    }
}

#Preview {
    UpgradePathView()
        .modelContainer(for: VehicleEntity.self, inMemory: true)
}

