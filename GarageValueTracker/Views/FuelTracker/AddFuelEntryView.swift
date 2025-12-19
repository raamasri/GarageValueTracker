import SwiftUI
import CoreData

struct AddFuelEntryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    let vehicle: VehicleEntity
    
    @State private var date = Date()
    @State private var mileage: String
    @State private var gallons = ""
    @State private var totalCost = ""
    @State private var station = ""
    @State private var notes = ""
    
    init(vehicle: VehicleEntity) {
        self.vehicle = vehicle
        _mileage = State(initialValue: "\(vehicle.mileage)")
    }
    
    private var pricePerGallon: Double? {
        guard let cost = Double(totalCost),
              let gal = Double(gallons),
              gal > 0 else {
            return nil
        }
        return cost / gal
    }
    
    private var isValid: Bool {
        guard let _ = Int(mileage),
              let gal = Double(gallons), gal > 0,
              let cost = Double(totalCost), cost > 0 else {
            return false
        }
        return true
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Fill-Up Details") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                    
                    HStack {
                        Text("Mileage")
                        Spacer()
                        TextField("Odometer Reading", text: $mileage)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Gallons")
                        Spacer()
                        TextField("0.00", text: $gallons)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Total Cost")
                        Spacer()
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $totalCost)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    if let ppg = pricePerGallon {
                        HStack {
                            Text("Price per Gallon")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "$%.3f", ppg))
                                .foregroundColor(.secondary)
                                .fontWeight(.medium)
                        }
                    }
                }
                
                Section("Optional") {
                    TextField("Gas Station", text: $station)
                    
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
                
                Section {
                    Button(action: saveFuelEntry) {
                        HStack {
                            Image(systemName: "fuelpump.fill")
                            Text("Save Fill-Up")
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(isValid ? .blue : .gray)
                    }
                    .disabled(!isValid)
                }
            }
            .navigationTitle("Add Fill-Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func saveFuelEntry() {
        guard let mileageValue = Int(mileage),
              let gallonsValue = Double(gallons),
              let costValue = Double(totalCost) else {
            return
        }
        
        let entry = FuelEntryEntity(
            context: viewContext,
            vehicleID: vehicle.id,
            date: date,
            mileage: mileageValue,
            gallons: gallonsValue,
            cost: costValue
        )
        
        if !station.isEmpty {
            entry.station = station
        }
        
        if !notes.isEmpty {
            entry.notes = notes
        }
        
        // Update vehicle mileage if this is more recent
        if mileageValue > vehicle.mileage {
            vehicle.mileage = Int32(mileageValue)
        }
        
        do {
            try viewContext.save()
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Error saving fuel entry: \(error)")
        }
    }
}

// MARK: - Preview
struct AddFuelEntryView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let vehicle = VehicleEntity(context: context)
        vehicle.id = UUID()
        vehicle.make = "Toyota"
        vehicle.model = "Camry"
        vehicle.year = 2020
        vehicle.mileage = 45000
        
        return AddFuelEntryView(vehicle: vehicle)
            .environment(\.managedObjectContext, context)
    }
}

