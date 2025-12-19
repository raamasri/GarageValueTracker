import SwiftUI
import CoreData
import PhotosUI

struct AddWishlistVehicleView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedMake = ""
    @State private var selectedModel = ""
    @State private var selectedYear = ""
    @State private var trim = ""
    @State private var mileage = ""
    @State private var currentPrice = ""
    @State private var targetPrice = ""
    @State private var location = ""
    @State private var seller = ""
    @State private var listingURL = ""
    @State private var vin = ""
    @State private var notes = ""
    
    // Smart dropdown states
    @State private var availableMakes: [String] = []
    @State private var availableModels: [String] = []
    @State private var availableYears: [Int] = []
    @State private var customMake = ""
    @State private var customModel = ""
    @State private var customYear = ""
    
    // Photo picker
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    
    private var vehicleInformationSection: some View {
        Section("Vehicle Information") {
            // Make Picker
            Picker("Make", selection: $selectedMake) {
                Text("Select Make").tag("")
                ForEach(availableMakes, id: \.self) { make in
                    Text(make).tag(make)
                }
                Text("Custom").tag("Custom")
            }
            
            if selectedMake == "Custom" {
                TextField("Enter Make", text: $customMake)
            }
            
            // Model Picker
            if !selectedMake.isEmpty && selectedMake != "Custom" {
                Picker("Model", selection: $selectedModel) {
                    Text("Select Model").tag("")
                    ForEach(availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                    Text("Custom").tag("Custom")
                }
            } else if selectedMake == "Custom" {
                TextField("Model", text: $customModel)
            }
            
            if selectedModel == "Custom" {
                TextField("Enter Model", text: $customModel)
            }
            
            // Year Picker
            if (!selectedMake.isEmpty && !selectedModel.isEmpty && selectedModel != "Custom") || selectedMake == "Custom" {
                Picker("Year", selection: $selectedYear) {
                    Text("Select Year").tag("")
                    ForEach(availableYears, id: \.self) { year in
                        Text(String(year)).tag(String(year))
                    }
                    Text("Custom").tag("Custom")
                }
            }
            
            if selectedYear == "Custom" {
                TextField("Enter Year", text: $customYear)
                    .keyboardType(.numberPad)
            }
            
            TextField("Trim (Optional)", text: $trim)
            
            TextField("Mileage (Optional)", text: $mileage)
                .keyboardType(.numberPad)
        }
    }
    
    private var pricingSection: some View {
        Section {
            HStack {
                Text("$")
                    .foregroundColor(.secondary)
                TextField("Current Price (Optional)", text: $currentPrice)
                    .keyboardType(.decimalPad)
            }
            
            HStack {
                Text("$")
                    .foregroundColor(.secondary)
                TextField("Target Price (Optional)", text: $targetPrice)
                    .keyboardType(.decimalPad)
            }
            .foregroundColor(.green)
        } header: {
            Text("Pricing")
        } footer: {
            Text("Add a target price to track when it drops to your ideal price")
                .font(.caption)
        }
    }
    
    private var listingDetailsSection: some View {
        Section("Listing Details") {
            TextField("Location (Optional)", text: $location)
            TextField("Seller (Optional)", text: $seller)
            TextField("Listing URL (Optional)", text: $listingURL)
                .keyboardType(.URL)
                .autocapitalization(.none)
            TextField("VIN (Optional)", text: $vin)
                .autocapitalization(.allCharacters)
        }
    }
    
    private var photoSection: some View {
        Section("Vehicle Photo") {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                if let selectedPhotoData,
                   let uiImage = UIImage(data: selectedPhotoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    HStack {
                        Image(systemName: "photo")
                            .font(.title2)
                        Text("Choose Photo")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            if selectedPhotoData != nil {
                Button(action: {
                    selectedPhotoItem = nil
                    selectedPhotoData = nil
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Remove Photo")
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
    
    private var notesSection: some View {
        Section("Notes") {
            TextEditor(text: $notes)
                .frame(minHeight: 100)
        }
    }
    
    var body: some View {
        NavigationView {
            formContent
        }
    }
    
    private var formContent: some View {
        Form {
            vehicleInformationSection
            pricingSection
            listingDetailsSection
            photoSection
            notesSection
        }
        .navigationTitle("Add to Wishlist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveWishlistVehicle()
                }
                .disabled(!isValid)
            }
        }
        .onChange(of: selectedPhotoItem) { handlePhotoChange() }
        .onChange(of: selectedMake) { handleMakeChange() }
        .onChange(of: customMake) { handleCustomMakeChange() }
        .onChange(of: selectedModel) { handleModelChange() }
        .onChange(of: customModel) { handleCustomModelChange() }
        .onAppear { loadInitialData() }
    }
    
    private var isValid: Bool {
        let finalMake = selectedMake == "Custom" ? customMake : selectedMake
        let finalModel = selectedModel == "Custom" ? customModel : selectedModel
        let finalYear = selectedYear == "Custom" ? customYear : selectedYear
        
        // Only require make, model, and year
        guard !finalMake.isEmpty,
              !finalModel.isEmpty,
              !finalYear.isEmpty,
              let _ = Int16(finalYear) else {
            return false
        }
        
        // If price is provided, validate it's a valid number
        if !currentPrice.isEmpty {
            guard let priceValue = Double(currentPrice), priceValue > 0 else {
                return false
            }
        }
        
        // If target price is provided, validate it's a valid number
        if !targetPrice.isEmpty {
            guard let targetValue = Double(targetPrice), targetValue > 0 else {
                return false
            }
        }
        
        return true
    }
    
    private func saveWishlistVehicle() {
        let finalMake = selectedMake == "Custom" ? customMake : selectedMake
        let finalModel = selectedModel == "Custom" ? customModel : selectedModel
        let finalYear = selectedYear == "Custom" ? customYear : selectedYear
        
        guard let yearValue = Int16(finalYear) else { return }
        
        // Parse price values - default to 0 if not provided
        let priceValue = Double(currentPrice) ?? 0
        let targetPriceValue = Double(targetPrice) ?? 0
        let mileageValue = Int32(mileage) ?? 0
        
        _ = WishlistService.shared.addToWishlist(
            context: viewContext,
            make: finalMake,
            model: finalModel,
            year: yearValue,
            trim: trim.isEmpty ? nil : trim,
            mileage: mileageValue,
            currentPrice: priceValue,
            targetPrice: targetPriceValue,
            location: location.isEmpty ? nil : location,
            seller: seller.isEmpty ? nil : seller,
            listingURL: listingURL.isEmpty ? nil : listingURL,
            vin: vin.isEmpty ? nil : vin,
            notes: notes.isEmpty ? nil : notes,
            imageData: selectedPhotoData
        )
        
        presentationMode.wrappedValue.dismiss()
    }
    
    private func compressImage(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        
        let maxSize: CGFloat = 1200
        var newSize = image.size
        
        if newSize.width > maxSize || newSize.height > maxSize {
            let ratio = newSize.width / newSize.height
            if ratio > 1 {
                newSize.width = maxSize
                newSize.height = maxSize / ratio
            } else {
                newSize.height = maxSize
                newSize.width = maxSize * ratio
            }
        }
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage?.jpegData(compressionQuality: 0.7)
    }
    
    private func handlePhotoChange() {
        Task {
            if let data = try? await selectedPhotoItem?.loadTransferable(type: Data.self) {
                selectedPhotoData = compressImage(data)
            }
        }
    }
    
    private func handleMakeChange() {
        if selectedMake != "Custom" && !selectedMake.isEmpty {
            availableModels = VehicleDatabaseService.shared.getModels(for: selectedMake)
        }
        selectedModel = ""
        selectedYear = ""
    }
    
    private func handleCustomMakeChange() {
        selectedModel = ""
        selectedYear = ""
    }
    
    private func handleModelChange() {
        if selectedModel != "Custom" && !selectedModel.isEmpty && !selectedMake.isEmpty {
            availableYears = VehicleDatabaseService.shared.getAvailableYears()
        }
        selectedYear = ""
    }
    
    private func handleCustomModelChange() {
        selectedYear = ""
    }
    
    private func loadInitialData() {
        availableMakes = VehicleDatabaseService.shared.getAllMakes()
        availableYears = VehicleDatabaseService.shared.getAvailableYears()
    }
}

