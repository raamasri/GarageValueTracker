import SwiftUI
import CoreData

struct AccidentHistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    let vehicle: VehicleEntity
    
    @State private var accidents: [AccidentRecord] = []
    @State private var showingAddAccident = false
    @State private var totalValueImpact: Double = 0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    impactSummaryCard
                    
                    if accidents.isEmpty {
                        emptyStateView
                    } else {
                        accidentListView
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Accident History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddAccident = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddAccident) {
                AddAccidentView(vehicle: vehicle) {
                    reloadData()
                }
                .environment(\.managedObjectContext, viewContext)
            }
            .onAppear { reloadData() }
        }
    }
    
    // MARK: - Impact Summary
    
    private var impactSummaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Value Impact")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if totalValueImpact > 0 {
                        Text("-$\(Int(totalValueImpact))")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.red)
                    } else {
                        Text("No Impact")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Current Value")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(Int(vehicle.currentValue))")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    if totalValueImpact > 0 {
                        let impactPercent = (totalValueImpact / vehicle.currentValue) * 100
                        Text("-\(String(format: "%.1f", impactPercent))% reduction")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            if !accidents.isEmpty {
                Divider()
                HStack {
                    Label("\(accidents.count) accident\(accidents.count == 1 ? "" : "s") on record", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                    Spacer()
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 56))
                .foregroundColor(.green)
            
            Text("Clean History")
                .font(.title3)
                .fontWeight(.bold)
            
            Text("No accidents reported for this vehicle. A clean history helps maintain your car's value.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(action: { showingAddAccident = true }) {
                Label("Report an Accident", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Accident List
    
    private var accidentListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reported Accidents")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(Array(accidents.enumerated()), id: \.offset) { index, accident in
                AccidentRecordCard(accident: accident, vehicleValue: vehicle.currentValue)
            }
            .padding(.horizontal)
            
            Button(action: { showingAddAccident = true }) {
                Label("Add Another Accident", systemImage: "plus.circle.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }
    
    private func reloadData() {
        accidents = vehicle.accidentRecords
        totalValueImpact = vehicle.calculateAccidentImpact()
    }
}

// MARK: - Accident Record Card

struct AccidentRecordCard: View {
    let accident: AccidentRecord
    let vehicleValue: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                severityBadge
                Spacer()
                Text(accident.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(accident.damageType)
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack(spacing: 16) {
                if let cost = accident.repairCost, cost > 0 {
                    Label("$\(Int(cost)) repair", systemImage: "wrench.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                let impact = vehicleValue * accident.severity.depreciationPercent
                Label("-$\(Int(impact)) value", systemImage: "arrow.down.right")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            if let notes = accident.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    private var severityBadge: some View {
        Text(accident.severity.rawValue)
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(severityColor.opacity(0.15))
            .foregroundColor(severityColor)
            .cornerRadius(8)
    }
    
    private var severityColor: Color {
        switch accident.severity {
        case .minor: return .yellow
        case .moderate: return .orange
        case .major: return .red
        case .structural: return .purple
        }
    }
}

// MARK: - Add Accident View

struct AddAccidentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    let vehicle: VehicleEntity
    var onSave: () -> Void
    
    @State private var date = Date()
    @State private var severity: AccidentRecord.AccidentSeverity = .minor
    @State private var damageType = ""
    @State private var repairCost = ""
    @State private var notes = ""
    
    private let damageTypes = [
        "Front-end collision",
        "Rear-end collision",
        "Side impact",
        "Fender bender",
        "Hail damage",
        "Flood damage",
        "Vandalism",
        "Hit and run",
        "Rollover",
        "Other"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Accident Details") {
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                    
                    Picker("Severity", selection: $severity) {
                        Text("Minor").tag(AccidentRecord.AccidentSeverity.minor)
                        Text("Moderate").tag(AccidentRecord.AccidentSeverity.moderate)
                        Text("Major").tag(AccidentRecord.AccidentSeverity.major)
                        Text("Structural").tag(AccidentRecord.AccidentSeverity.structural)
                    }
                    
                    Picker("Damage Type", selection: $damageType) {
                        Text("Select type").tag("")
                        ForEach(damageTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                }
                
                Section {
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("Repair Cost (Optional)", text: $repairCost)
                            .keyboardType(.decimalPad)
                    }
                } header: {
                    Text("Repair Cost")
                } footer: {
                    Text("Enter the total cost of repairs if known")
                }
                
                Section("Estimated Value Impact") {
                    let impactPercent = severity.depreciationPercent * 100
                    let impactDollars = vehicle.currentValue * severity.depreciationPercent
                    
                    HStack {
                        Text("Depreciation")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("-\(String(format: "%.1f", impactPercent))%")
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    }
                    
                    HStack {
                        Text("Estimated Impact")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("-$\(Int(impactDollars))")
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    }
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Add Accident")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveAccident()
                    }
                    .disabled(damageType.isEmpty)
                }
            }
        }
    }
    
    private func saveAccident() {
        let record = AccidentRecord(
            date: date,
            severity: severity,
            damageType: damageType,
            repairCost: Double(repairCost),
            notes: notes.isEmpty ? nil : notes
        )
        
        vehicle.addAccident(record)
        vehicle.accidentValueImpact = vehicle.calculateAccidentImpact()
        
        do {
            try viewContext.save()
            onSave()
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Error saving accident: \(error)")
        }
    }
}
