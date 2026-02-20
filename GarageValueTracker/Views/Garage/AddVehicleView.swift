import SwiftUI
import CoreData
import PhotosUI

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
    
    // Photo picker states
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var showingImagePicker = false
    
    // License plate lookup states
    @State private var licensePlate: String = ""
    @State private var licensePlateState: String = ""
    @State private var isLookingUpPlate = false
    @State private var plateLookupError: String?
    @State private var showVINFallback = false
    @State private var plateVIN: String = ""
    @State private var isDecodingPlateVIN = false
    
    var body: some View {
        NavigationView {
            Form {
                // License Plate Lookup Section
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Quick Add by License Plate", systemImage: "car.rear.and.tire.marks")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        HStack(spacing: 10) {
                            Picker("State", selection: $licensePlateState) {
                                Text("State").tag("")
                                ForEach(LicensePlateService.usStates, id: \.code) { state in
                                    Text(state.code).tag(state.code)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 90)
                            
                            TextField("Plate Number", text: $licensePlate)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Button(action: lookupPlate) {
                                if isLookingUpPlate {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "magnifyingglass")
                                }
                            }
                            .disabled(licensePlate.isEmpty || licensePlateState.isEmpty || isLookingUpPlate)
                        }
                        
                        if let error = plateLookupError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        if showVINFallback {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Enter VIN to auto-fill vehicle details:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    TextField("17-character VIN", text: $plateVIN)
                                        .textInputAutocapitalization(.characters)
                                        .autocorrectionDisabled()
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                    
                                    Button(action: decodeVINFromPlate) {
                                        if isDecodingPlateVIN {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        } else {
                                            Text("Decode")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                    }
                                    .disabled(plateVIN.count != 17 || isDecodingPlateVIN)
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                } header: {
                    Text("Quick Lookup")
                } footer: {
                    Text("Look up your vehicle by plate or VIN to auto-fill details below.")
                }
                
                // Photo Section
                Section(header: Text("Vehicle Photo")) {
                    VStack(spacing: 12) {
                        if let photoData = selectedPhotoData,
                           let uiImage = UIImage(data: photoData) {
                            // Show selected photo
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        } else {
                            // Placeholder
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(height: 200)
                                
                                VStack(spacing: 8) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                    Text("Add Photo")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        // Photo picker button
                        PhotosPicker(selection: $selectedPhotoItem,
                                   matching: .images) {
                            HStack {
                                Image(systemName: selectedPhotoData == nil ? "photo.on.rectangle" : "arrow.triangle.2.circlepath")
                                Text(selectedPhotoData == nil ? "Choose Photo" : "Change Photo")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .onChange(of: selectedPhotoItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    selectedPhotoData = compressImage(data)
                                }
                            }
                        }
                        
                        if selectedPhotoData != nil {
                            Button(role: .destructive) {
                                selectedPhotoData = nil
                                selectedPhotoItem = nil
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Remove Photo")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.red.opacity(0.1))
                                .foregroundColor(.red)
                                .cornerRadius(8)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }
                
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
                        .onChange(of: selectedMake) { _, newMake in
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
                                .onChange(of: customMake) { _, newValue in
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
                        .onChange(of: selectedModel) { _, newModel in
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
                                .onChange(of: customModel) { _, newValue in
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
                        .onChange(of: selectedYear) { _, newYear in
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
                                .onChange(of: customYear) { _, newValue in
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
        
        if !licensePlate.isEmpty {
            vehicle.licensePlate = licensePlate.uppercased()
            vehicle.licensePlateState = licensePlateState
        }
        
        // Save photo if selected
        if let photoData = selectedPhotoData {
            vehicle.imageData = photoData
        }
        
        do {
            try viewContext.save()
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Error saving vehicle: \(error.localizedDescription)")
        }
    }
    
    // MARK: - License Plate Lookup
    
    private func lookupPlate() {
        isLookingUpPlate = true
        plateLookupError = nil
        showVINFallback = false
        
        LicensePlateService.shared.lookupPlate(licensePlate, state: licensePlateState) { result in
            isLookingUpPlate = false
            switch result {
            case .success(let plateResult):
                vin = plateResult.vin
                if let resultMake = plateResult.make { make = resultMake }
                if let resultModel = plateResult.model { model = resultModel }
                if let resultYear = plateResult.year { year = String(resultYear) }
            case .failure:
                plateLookupError = "Plate lookup unavailable. Try entering your VIN instead."
                showVINFallback = true
            }
        }
    }
    
    private func decodeVINFromPlate() {
        isDecodingPlateVIN = true
        plateLookupError = nil
        
        VehicleAPIService.shared.decodeVIN(plateVIN) { result in
            isDecodingPlateVIN = false
            switch result {
            case .success(let decoded):
                vin = decoded.vin
                
                if let matchingMake = availableMakes.first(where: { $0.lowercased() == decoded.make.lowercased() }) {
                    selectedMake = matchingMake
                    make = matchingMake
                    updateAvailableModels()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if let matchingModel = availableModels.first(where: { $0.lowercased() == decoded.model.lowercased() }) {
                            selectedModel = matchingModel
                            model = matchingModel
                        } else {
                            selectedModel = "Custom"
                            customModel = decoded.model
                            model = decoded.model
                        }
                    }
                } else {
                    selectedMake = "Custom"
                    customMake = decoded.make
                    make = decoded.make
                    selectedModel = "Custom"
                    customModel = decoded.model
                    model = decoded.model
                }
                
                let yearStr = String(decoded.year)
                if availableYears.contains(yearStr) {
                    selectedYear = yearStr
                } else {
                    selectedYear = "Custom"
                    customYear = yearStr
                }
                year = yearStr
                
                if let decodedTrim = decoded.trim {
                    trim = decodedTrim
                }
                
                checkTrimsAvailability()
                showVINFallback = false
                plateLookupError = nil
                
            case .failure(let error):
                plateLookupError = "VIN decode failed: \(error.localizedDescription)"
            }
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
    
    // MARK: - Image Helpers
    
    private func compressImage(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        
        // Resize to max width/height of 1024
        let maxDimension: CGFloat = 1024
        let size = image.size
        var newSize = size
        
        if size.width > maxDimension || size.height > maxDimension {
            let ratio = size.width / size.height
            if size.width > size.height {
                newSize = CGSize(width: maxDimension, height: maxDimension / ratio)
            } else {
                newSize = CGSize(width: maxDimension * ratio, height: maxDimension)
            }
        }
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // Compress to JPEG with 0.8 quality
        return resizedImage?.jpegData(compressionQuality: 0.8)
    }
}

struct AddVehicleView_Previews: PreviewProvider {
    static var previews: some View {
        AddVehicleView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
