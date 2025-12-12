import SwiftUI
import SwiftData

struct AddVehicleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let ownershipType: OwnershipType
    
    @State private var step: AddVehicleStep = .method
    @State private var vinEntry = ""
    @State private var isDecodingVIN = false
    @State private var vinDecodeError: String?
    
    // Manual entry fields
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var make = ""
    @State private var model = ""
    @State private var trim = ""
    @State private var transmission = "Manual"
    @State private var mileage = ""
    @State private var zipCode = ""
    
    // Purchase info (for owned vehicles)
    @State private var purchasePrice = ""
    @State private var purchaseDate = Date()
    @State private var purchaseMileage = ""
    
    // Watchlist info
    @State private var targetPrice = ""
    
    enum AddVehicleStep {
        case method
        case vinEntry
        case manualEntry
        case purchaseInfo
        case confirmation
    }
    
    var body: some View {
        NavigationStack {
            Form {
                switch step {
                case .method:
                    methodSelectionSection
                case .vinEntry:
                    vinEntrySection
                case .manualEntry:
                    manualEntrySection
                case .purchaseInfo:
                    purchaseInfoSection
                case .confirmation:
                    confirmationSection
                }
            }
            .navigationTitle(ownershipType == .owned ? "Add to Garage" : "Add to Watchlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(actionButtonTitle) {
                        handleNextAction()
                    }
                    .disabled(!canProceed)
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private var methodSelectionSection: some View {
        Section {
            Button {
                step = .vinEntry
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("VIN Decode")
                            .font(.headline)
                        Text("Automatic details from VIN")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "barcode.viewfinder")
                        .font(.title2)
                }
            }
            .foregroundStyle(.primary)
            
            Button {
                step = .manualEntry
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Manual Entry")
                            .font(.headline)
                        Text("Enter details manually")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "keyboard")
                        .font(.title2)
                }
            }
            .foregroundStyle(.primary)
        } header: {
            Text("How would you like to add this vehicle?")
        }
    }
    
    private var vinEntrySection: some View {
        Section {
            TextField("Enter VIN", text: $vinEntry)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            
            if let error = vinDecodeError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            
            if isDecodingVIN {
                HStack {
                    ProgressView()
                    Text("Decoding VIN...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Vehicle Identification Number")
        } footer: {
            Text("The VIN is usually found on the driver's side dashboard or door jamb. It's 17 characters long.")
        }
    }
    
    private var manualEntrySection: some View {
        Group {
            Section("Vehicle Details") {
                Picker("Year", selection: $year) {
                    ForEach((1990...Calendar.current.component(.year, from: Date()) + 1).reversed(), id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                
                TextField("Make", text: $make)
                    .autocorrectionDisabled()
                
                TextField("Model", text: $model)
                    .autocorrectionDisabled()
                
                TextField("Trim", text: $trim)
                    .autocorrectionDisabled()
                
                Picker("Transmission", selection: $transmission) {
                    Text("Manual").tag("Manual")
                    Text("Automatic").tag("Automatic")
                }
            }
            
            Section("Current Info") {
                TextField("Current Mileage", text: $mileage)
                    .keyboardType(.numberPad)
                
                TextField("Zip Code", text: $zipCode)
                    .keyboardType(.numberPad)
            }
        }
    }
    
    private var purchaseInfoSection: some View {
        Group {
            if ownershipType == .owned {
                Section("Purchase Details") {
                    TextField("Purchase Price", text: $purchasePrice)
                        .keyboardType(.decimalPad)
                    
                    DatePicker("Purchase Date", selection: $purchaseDate, displayedComponents: .date)
                    
                    TextField("Purchase Mileage", text: $purchaseMileage)
                        .keyboardType(.numberPad)
                }
            } else {
                Section("Watchlist Settings") {
                    TextField("Target Entry Price (Optional)", text: $targetPrice)
                        .keyboardType(.decimalPad)
                }
            }
        }
    }
    
    private var confirmationSection: some View {
        Section("Review") {
            LabeledContent("Vehicle", value: "\(year) \(make) \(model) \(trim)")
            LabeledContent("Transmission", value: transmission)
            LabeledContent("Mileage", value: "\(mileage) miles")
            LabeledContent("Location", value: zipCode)
            
            if ownershipType == .owned {
                if let price = Double(purchasePrice) {
                    LabeledContent("Purchase Price", value: formatCurrency(price))
                }
                LabeledContent("Purchase Date", value: purchaseDate.formatted(date: .abbreviated, time: .omitted))
            } else {
                if let target = Double(targetPrice) {
                    LabeledContent("Target Price", value: formatCurrency(target))
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var actionButtonTitle: String {
        switch step {
        case .method:
            return "Next"
        case .vinEntry:
            return "Decode VIN"
        case .manualEntry:
            return "Next"
        case .purchaseInfo:
            return "Review"
        case .confirmation:
            return "Add Vehicle"
        }
    }
    
    private var canProceed: Bool {
        switch step {
        case .method:
            return false
        case .vinEntry:
            return vinEntry.count == 17 && !isDecodingVIN
        case .manualEntry:
            return !make.isEmpty && !model.isEmpty && !trim.isEmpty && 
                   !mileage.isEmpty && !zipCode.isEmpty
        case .purchaseInfo:
            if ownershipType == .owned {
                return !purchasePrice.isEmpty && !purchaseMileage.isEmpty
            } else {
                return true
            }
        case .confirmation:
            return true
        }
    }
    
    private func handleNextAction() {
        switch step {
        case .method:
            break
        case .vinEntry:
            Task {
                await decodeVIN()
            }
        case .manualEntry:
            if ownershipType == .owned {
                step = .purchaseInfo
            } else {
                step = .purchaseInfo
            }
        case .purchaseInfo:
            step = .confirmation
        case .confirmation:
            saveVehicle()
        }
    }
    
    private func decodeVIN() async {
        isDecodingVIN = true
        vinDecodeError = nil
        
        do {
            let result = try await VehicleAPIService.shared.decodeVIN(vinEntry)
            
            if let result = result {
                // Populate fields from VIN decode
                if let yearStr = result.modelYear, let yearInt = Int(yearStr) {
                    year = yearInt
                }
                make = result.make ?? ""
                model = result.model ?? ""
                trim = result.trim ?? ""
                
                step = .manualEntry // Still need mileage and zip
            } else {
                vinDecodeError = "Could not decode VIN"
            }
        } catch {
            vinDecodeError = "Error decoding VIN: \(error.localizedDescription)"
        }
        
        isDecodingVIN = false
    }
    
    private func saveVehicle() {
        let vehicle = VehicleEntity(
            ownershipType: ownershipType,
            vin: vinEntry.isEmpty ? nil : vinEntry,
            year: year,
            make: make,
            model: model,
            trim: trim,
            transmission: transmission,
            mileageCurrent: Int(mileage) ?? 0,
            zip: zipCode,
            purchasePrice: ownershipType == .owned ? Double(purchasePrice) : nil,
            purchaseDate: ownershipType == .owned ? purchaseDate : nil,
            purchaseMileage: ownershipType == .owned ? Int(purchaseMileage) : nil,
            targetPrice: ownershipType == .watchlist ? Double(targetPrice) : nil
        )
        
        modelContext.insert(vehicle)
        
        // Normalize vehicle with backend
        Task {
            do {
                let request = VehicleNormalizeRequest(
                    vin: vehicle.vin,
                    year: vehicle.year,
                    make: vehicle.make,
                    model: vehicle.model,
                    trim: vehicle.trim,
                    transmission: vehicle.transmission,
                    mileage: vehicle.mileageCurrent,
                    zip: vehicle.zip
                )
                let response = try await MarketAPIService.shared.normalizeVehicle(request)
                
                // Update vehicle with normalized data
                vehicle.segment = response.segment
                vehicle.mileageBand = response.mileageBand
                vehicle.regionBucket = response.regionBucket
            } catch {
                print("Failed to normalize vehicle: \(error)")
            }
        }
        
        dismiss()
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

#Preview {
    AddVehicleView(ownershipType: .owned)
        .modelContainer(for: VehicleEntity.self, inMemory: true)
}



