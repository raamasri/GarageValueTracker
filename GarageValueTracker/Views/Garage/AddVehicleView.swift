import SwiftUI
import CoreData

struct AddVehicleView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    @State private var make: String = ""
    @State private var model: String = ""
    @State private var year: String = ""
    @State private var trim: String = ""
    @State private var vin: String = ""
    @State private var mileage: String = ""
    @State private var purchasePrice: String = ""
    @State private var purchaseDate = Date()
    @State private var notes: String = ""
    
    @State private var selectedTrimData: TrimData?
    @State private var showingTrimSelection = false
    @State private var hasTrimsAvailable = false
    
    // Dropdown states
    @State private var selectedMake: String = "Custom"
    @State private var selectedModel: String = "Custom"
    @State private var selectedYear: String = "Custom"
    @State private var availableMakes: [String] = []
    @State private var availableModels: [String] = []
    @State private var availableYears: [String] = []
    @State private var customMake: String = ""
    @State private var customModel: String = ""
    @State private var customYear: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Vehicle Information")) {
                    // Make Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Make")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("Make", selection: $selectedMake) {
                            ForEach(availableMakes, id: \.self) { make in
                                Text(make).tag(make)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedMake) { newMake in
                            if newMake != "Custom" {
                                make = newMake
                                updateAvailableModels()
                            } else {
                                make = ""
                            }
                            checkTrimsAvailability()
                        }
                        
                        if selectedMake == "Custom" {
                            TextField("Enter make", text: $customMake)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: customMake) { newValue in
                                    make = newValue
                                    checkTrimsAvailability()
                                }
                        }
                    }
                    
                    // Model Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Model")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("Model", selection: $selectedModel) {
                            ForEach(availableModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedModel) { newModel in
                            if newModel != "Custom" {
                                model = newModel
                            } else {
                                model = ""
                            }
                            checkTrimsAvailability()
                        }
                        
                        if selectedModel == "Custom" {
                            TextField("Enter model", text: $customModel)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: customModel) { newValue in
                                    model = newValue
                                    checkTrimsAvailability()
                                }
                        }
                    }
                    
                    // Year Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Year")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("Year", selection: $selectedYear) {
                            ForEach(availableYears, id: \.self) { year in
                                Text(year).tag(year)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedYear) { newYear in
                            if newYear != "Custom" {
                                year = newYear
                            } else {
                                year = ""
                            }
                            checkTrimsAvailability()
                        }
                        
                        if selectedYear == "Custom" {
                            TextField("Enter year", text: $customYear)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                                .onChange(of: customYear) { newValue in
                                    year = newValue
                                    checkTrimsAvailability()
                                }
                        }
                    }
                    
                    // Trim selection
                    if hasTrimsAvailable {
                        Button(action: {
                            showingTrimSelection = true
                        }) {
                            HStack {
                                Text("Trim")
                                    .foregroundColor(.primary)
                                Spacer()
                                if let trimData = selectedTrimData {
                                    Text(trimData.trimLevel)
                                        .foregroundColor(.secondary)
                                    Text("•")
                                        .foregroundColor(.secondary)
                                    Text(formatPrice(trimData.msrp))
                                        .foregroundColor(.blue)
                                } else {
                                    Text("Select Trim")
                                        .foregroundColor(.blue)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        TextField("Trim (Optional)", text: $trim)
                    }
                }
                
                Section(header: Text("Details")) {
                    TextField("VIN (Optional)", text: $vin)
                        .autocapitalization(.allCharacters)
                    
                    HStack {
                        Image(systemName: "gauge")
                            .foregroundColor(.secondary)
                        TextField("Mileage", text: $mileage)
                            .keyboardType(.numberPad)
                    }
                }
                
                Section(header: Text("Purchase Information")) {
                    DatePicker("Purchase Date", selection: $purchaseDate, displayedComponents: .date)
                    
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("Purchase Price", text: $purchasePrice)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section(header: Text("Notes (Optional)")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Add Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveVehicle()
                    }
                    .disabled(!isValidVehicle)
                }
            }
            .sheet(isPresented: $showingTrimSelection) {
                if let yearInt = Int(year), !make.isEmpty, !model.isEmpty {
                    TrimSelectionView(
                        make: make,
                        model: model,
                        year: yearInt,
                        selectedTrim: $selectedTrimData
                    )
                }
            }
            .onAppear {
                initializeDropdowns()
            }
        }
    }
    
    private var isValidVehicle: Bool {
        !make.isEmpty && !model.isEmpty && !year.isEmpty && !purchasePrice.isEmpty
    }
    
    private func saveVehicle() {
        guard let yearInt = Int(year),
              let purchasePriceDouble = Double(purchasePrice) else {
            return
        }
        
        let mileageInt = Int(mileage) ?? 0
        
        // Determine trim info
        let trimName: String?
        let trimMSRP: Double
        var selectedTrimID: UUID?
        
        if let trimData = selectedTrimData {
            // Using selected trim from database
            trimName = trimData.trimLevel
            trimMSRP = trimData.msrp
            
            // Try to get or create TrimEntity
            if let trimEntity = TrimDatabaseService.shared.getOrCreateTrimEntity(from: trimData) {
                selectedTrimID = trimEntity.id
            }
        } else {
            // Manual trim entry
            trimName = trim.isEmpty ? nil : trim
            trimMSRP = 0.0
        }
        
        let vehicle = VehicleEntity(
            context: viewContext,
            make: make,
            model: model,
            year: yearInt,
            trim: trimName,
            vin: vin.isEmpty ? nil : vin,
            mileage: mileageInt,
            purchasePrice: purchasePriceDouble,
            purchaseDate: purchaseDate
        )
        
        vehicle.selectedTrimID = selectedTrimID
        vehicle.trimMSRP = trimMSRP
        
        if !notes.isEmpty {
            vehicle.notes = notes
        }
        
        do {
            try viewContext.save()
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Error saving vehicle: \(error.localizedDescription)")
        }
    }
    
    private func checkTrimsAvailability() {
        guard let yearInt = Int(year), !make.isEmpty, !model.isEmpty else {
            hasTrimsAvailable = false
            return
        }
        
        hasTrimsAvailable = TrimDatabaseService.shared.hasTrimsAvailable(
            make: make,
            model: model,
            year: yearInt
        )
        
        // Clear selection if vehicle changed
        if hasTrimsAvailable {
            selectedTrimData = nil
        }
    }
    
    private func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: price)) ?? "$\(Int(price))"
    }
    
    // MARK: - Dropdown Helpers
    
    private func initializeDropdowns() {
        let vehicleDB = VehicleDatabaseService.shared
        
        // Load makes
        var makes = vehicleDB.getAllMakes()
        makes.append("Custom")
        availableMakes = makes
        
        // Set default to first make if available
        if !makes.isEmpty {
            selectedMake = makes[0]
            make = makes[0]
            updateAvailableModels()
        }
        
        // Load years
        var years = vehicleDB.getAvailableYears().map { String($0) }
        years.append("Custom")
        availableYears = years
        
        // Set default to current year if available
        if !years.isEmpty {
            selectedYear = years[0]
            year = years[0]
        }
    }
    
    private func updateAvailableModels() {
        let vehicleDB = VehicleDatabaseService.shared
        
        if selectedMake != "Custom" {
            var models = vehicleDB.getModels(for: selectedMake)
            models.append("Custom")
            availableModels = models
            
            // Set default to first model if available
            if models.count > 1 { // More than just "Custom"
                selectedModel = models[0]
                model = models[0]
            } else {
                selectedModel = "Custom"
                model = ""
            }
        } else {
            availableModels = ["Custom"]
            selectedModel = "Custom"
            model = ""
        }
    }
}

struct AddVehicleView_Previews: PreviewProvider {
    static var previews: some View {
        AddVehicleView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
