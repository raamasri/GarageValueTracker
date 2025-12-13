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
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Vehicle Information")) {
                    TextField("Make (e.g., Toyota)", text: $make)
                    TextField("Model (e.g., Camry)", text: $model)
                    TextField("Year", text: $year)
                        .keyboardType(.numberPad)
                    TextField("Trim (Optional)", text: $trim)
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
        
        let vehicle = VehicleEntity(
            context: viewContext,
            make: make,
            model: model,
            year: yearInt,
            trim: trim.isEmpty ? nil : trim,
            vin: vin.isEmpty ? nil : vin,
            mileage: mileageInt,
            purchasePrice: purchasePriceDouble,
            purchaseDate: purchaseDate
        )
        
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
}

struct AddVehicleView_Previews: PreviewProvider {
    static var previews: some View {
        AddVehicleView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
