import SwiftUI
import SwiftData

struct AddCostEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let vehicle: VehicleEntity
    
    @State private var date = Date()
    @State private var category: CostCategory = .maintenance
    @State private var amount = ""
    @State private var notes = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Cost Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    
                    Picker("Category", selection: $category) {
                        ForEach(CostCategory.allCases, id: \.self) { category in
                            Label(category.rawValue, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                    
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                }
                
                Section("Notes (Optional)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Add Cost")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCost()
                    }
                    .disabled(amount.isEmpty || Double(amount) == nil)
                }
            }
        }
    }
    
    private func saveCost() {
        guard let amountValue = Double(amount) else { return }
        
        let cost = CostEntryEntity(
            date: date,
            category: category,
            amount: amountValue,
            notes: notes
        )
        cost.vehicle = vehicle
        
        modelContext.insert(cost)
        
        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: VehicleEntity.self, configurations: config)
    
    let vehicle = VehicleEntity(
        ownershipType: .owned,
        year: 2022,
        make: "Toyota",
        model: "GR86",
        trim: "Premium",
        transmission: "Manual",
        mileageCurrent: 32000,
        zip: "95126"
    )
    container.mainContext.insert(vehicle)
    
    return AddCostEntryView(vehicle: vehicle)
        .modelContainer(container)
}



