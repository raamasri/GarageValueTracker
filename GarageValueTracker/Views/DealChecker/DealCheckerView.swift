import SwiftUI
import SwiftData

struct DealCheckerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettingsEntity]
    
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var make = ""
    @State private var model = ""
    @State private var trim = ""
    @State private var transmission = "Manual"
    @State private var mileage = ""
    @State private var zipCode = ""
    @State private var askPrice = ""
    
    @State private var dealResult: DealCheckResponse?
    @State private var isChecking = false
    @State private var showingResult = false
    
    private var userSettings: UserSettingsEntity {
        settings.first ?? UserSettingsEntity()
    }
    
    var body: some View {
        NavigationStack {
            Form {
                vehicleDetailsSection
                
                listingDetailsSection
                
                checkButtonSection
            }
            .navigationTitle("Deal Checker")
            .sheet(isPresented: $showingResult) {
                if let result = dealResult {
                    DealResultView(result: result, vehicleInfo: vehicleDisplayName)
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private var vehicleDetailsSection: some View {
        Section("Vehicle") {
            Picker("Year", selection: $year) {
                ForEach((1990...Calendar.current.component(.year, from: Date()) + 1).reversed(), id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            
            TextField("Make (e.g., Toyota)", text: $make)
                .autocorrectionDisabled()
            
            TextField("Model (e.g., GR86)", text: $model)
                .autocorrectionDisabled()
            
            TextField("Trim (e.g., Premium)", text: $trim)
                .autocorrectionDisabled()
            
            Picker("Transmission", selection: $transmission) {
                Text("Manual").tag("Manual")
                Text("Automatic").tag("Automatic")
            }
        }
    }
    
    private var listingDetailsSection: some View {
        Section("Listing Details") {
            TextField("Mileage", text: $mileage)
                .keyboardType(.numberPad)
            
            TextField("Zip Code", text: $zipCode)
                .keyboardType(.numberPad)
            
            TextField("Asking Price", text: $askPrice)
                .keyboardType(.decimalPad)
        }
    }
    
    private var checkButtonSection: some View {
        Section {
            Button {
                Task {
                    await checkDeal()
                }
            } label: {
                HStack {
                    if isChecking {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Check Deal")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .disabled(!canCheckDeal || isChecking)
            .listRowBackground(canCheckDeal && !isChecking ? Color.accentColor : Color.gray.opacity(0.3))
            .foregroundStyle(.white)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }
    
    // MARK: - Helpers
    
    private var canCheckDeal: Bool {
        !make.isEmpty && !model.isEmpty && !trim.isEmpty &&
        !mileage.isEmpty && !zipCode.isEmpty && !askPrice.isEmpty
    }
    
    private var vehicleDisplayName: String {
        "\(year) \(make) \(model) \(trim)"
    }
    
    private func checkDeal() async {
        isChecking = true
        
        do {
            // First normalize the vehicle
            let normalizeRequest = VehicleNormalizeRequest(
                vin: nil,
                year: year,
                make: make,
                model: model,
                trim: trim,
                transmission: transmission,
                mileage: Int(mileage) ?? 0,
                zip: zipCode
            )
            
            let normalized = try await MarketAPIService.shared.normalizeVehicle(normalizeRequest)
            
            // Then check the deal
            let dealRequest = DealCheckRequest(
                vehicleId: normalized.vehicleId,
                mileage: Int(mileage) ?? 0,
                zip: zipCode,
                askPrice: Double(askPrice) ?? 0,
                hassleModel: HassleModel(
                    hoursPerWeekActiveListing: userSettings.hoursPerWeekActiveListing,
                    hoursPerTestDrive: userSettings.hoursPerTestDrive,
                    hoursPerPriceChange: userSettings.hoursPerPriceChange
                )
            )
            
            dealResult = try await MarketAPIService.shared.checkDeal(dealRequest)
            showingResult = true
            
        } catch {
            print("Failed to check deal: \(error)")
        }
        
        isChecking = false
    }
}

struct DealResultView: View {
    let result: DealCheckResponse
    let vehicleInfo: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with rating
                    ratingHeaderCard
                    
                    // Fair Value Band
                    fairValueCard
                    
                    // Sell Outlook
                    sellOutlookCard
                    
                    // Pricing Scenarios
                    pricingScenariosCard
                }
                .padding()
            }
            .navigationTitle("Deal Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Rating Header
    
    private var ratingHeaderCard: some View {
        VStack(spacing: 16) {
            Text(vehicleInfo)
                .font(.title3)
                .fontWeight(.semibold)
            
            // Big Rating Badge
            VStack(spacing: 8) {
                ratingIcon
                
                Text(ratingText)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(ratingColor)
                
                Text(ratingSubtext)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(ratingColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var ratingIcon: some View {
        let icon: String = {
            switch result.currentPricing.rating {
            case "under_market": return "arrow.down.circle.fill"
            case "fair": return "checkmark.circle.fill"
            case "over_market": return "arrow.up.circle.fill"
            default: return "questionmark.circle.fill"
            }
        }()
        
        return Image(systemName: icon)
            .font(.system(size: 60))
            .foregroundStyle(ratingColor)
    }
    
    private var ratingText: String {
        switch result.currentPricing.rating {
        case "under_market": return "Under Market"
        case "fair": return "Fair Price"
        case "over_market": return "Over Market"
        default: return "Unknown"
        }
    }
    
    private var ratingSubtext: String {
        let pct = result.currentPricing.priceVsMidPct
        if pct < 0 {
            return String(format: "%.1f%% below market mid", abs(pct))
        } else if pct > 0 {
            return String(format: "%.1f%% above market mid", pct)
        } else {
            return "At market mid"
        }
    }
    
    private var ratingColor: Color {
        switch result.currentPricing.rating {
        case "under_market": return .green
        case "fair": return .blue
        case "over_market": return .red
        default: return .gray
        }
    }
    
    // MARK: - Fair Value Card
    
    private var fairValueCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Fair Value Band")
                .font(.headline)
            
            HStack(spacing: 0) {
                VStack(spacing: 8) {
                    Text("Low")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatCurrency(result.fairValue.low))
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 50)
                
                VStack(spacing: 8) {
                    Text("Mid")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatCurrency(result.fairValue.mid))
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 50)
                
                VStack(spacing: 8) {
                    Text("High")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatCurrency(result.fairValue.high))
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            
            Divider()
            
            HStack {
                Text("Asking Price:")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatCurrency(result.currentPricing.askPrice))
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
    
    // MARK: - Sell Outlook Card
    
    private var sellOutlookCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sell Speed Forecast")
                .font(.headline)
            
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Expected Days on Market")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(result.sellOutlook.expectedDaysOnMarket) days")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
            }
            
            Divider()
            
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Probability of selling in < 7 days")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("\(Int(result.sellOutlook.probabilityUnder7Days * 100))%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                }
            }
            
            Divider()
            
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "hourglass")
                    .foregroundStyle(.purple)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Estimated hassle hours")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("~\(Int(result.sellOutlook.estimatedHassleHours)) hours")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.purple)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
    
    // MARK: - Pricing Scenarios Card
    
    private var pricingScenariosCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Price-for-Speed Scenarios")
                .font(.headline)
            
            Text("Lower your price to sell faster and reduce hassle")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            ForEach(Array(result.scenarios.enumerated()), id: \.offset) { index, scenario in
                if index > 0 {
                    Divider()
                }
                scenarioRow(scenario)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
    
    private func scenarioRow(_ scenario: PricingScenario) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(scenario.label)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(formatCurrency(scenario.price))
                    .font(.title3)
                    .fontWeight(.bold)
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("\(scenario.expectedDaysOnMarket) days", systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Label("\(Int(scenario.probabilityUnder7Days * 100))% < 7 days", systemImage: "speedometer")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Label("~\(Int(scenario.estimatedHassleHours))h hassle", systemImage: "hourglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if scenario.hassleHoursSaved > 0 {
                        Label("Saves \(Int(scenario.hassleHoursSaved))h", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Formatters
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

#Preview {
    DealCheckerView()
        .modelContainer(for: UserSettingsEntity.self, inMemory: true)
}

