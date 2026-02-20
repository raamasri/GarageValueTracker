import SwiftUI
import CoreData

struct RegistrationInspectionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    let vehicle: VehicleEntity
    
    @State private var registrationDate: Date
    @State private var hasRegistrationDate: Bool
    @State private var inspectionDate: Date
    @State private var hasInspectionDate: Bool
    @State private var inspectionState: String
    @State private var showingSavedAlert = false
    
    private let usStates = [
        "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
        "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
        "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
        "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
        "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY", "DC"
    ]
    
    // States that require periodic safety inspections
    private let inspectionRequiredStates: Set<String> = [
        "DE", "HI", "LA", "ME", "MA", "MO", "NH", "NJ", "NY", "NC",
        "PA", "RI", "TX", "UT", "VA", "VT", "WV"
    ]
    
    // States that require emissions testing
    private let emissionsStates: Set<String> = [
        "AZ", "CA", "CO", "CT", "GA", "IL", "IN", "MD", "NV", "NM",
        "OH", "OR", "TN", "VA", "WA", "WI"
    ]
    
    init(vehicle: VehicleEntity) {
        self.vehicle = vehicle
        _registrationDate = State(initialValue: vehicle.registrationRenewalDate ?? Calendar.current.date(byAdding: .year, value: 1, to: Date())!)
        _hasRegistrationDate = State(initialValue: vehicle.registrationRenewalDate != nil)
        _inspectionDate = State(initialValue: vehicle.inspectionDueDate ?? Calendar.current.date(byAdding: .year, value: 1, to: Date())!)
        _hasInspectionDate = State(initialValue: vehicle.inspectionDueDate != nil)
        _inspectionState = State(initialValue: vehicle.inspectionState ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                registrationSection
                inspectionSection
                stateInfoSection
            }
            .navigationTitle("Registration & Inspection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                }
            }
            .alert("Saved", isPresented: $showingSavedAlert) {
                Button("OK") {
                    presentationMode.wrappedValue.dismiss()
                }
            } message: {
                Text("Registration and inspection reminders have been updated. You'll receive notifications before due dates.")
            }
        }
    }
    
    // MARK: - Registration Section
    
    private var registrationSection: some View {
        Section {
            Toggle(isOn: $hasRegistrationDate) {
                Label("Track Registration", systemImage: "doc.text.fill")
            }
            
            if hasRegistrationDate {
                DatePicker("Renewal Date", selection: $registrationDate, displayedComponents: .date)
                
                if registrationDate > Date() {
                    let days = Calendar.current.dateComponents([.day], from: Date(), to: registrationDate).day ?? 0
                    HStack {
                        Image(systemName: days <= 30 ? "exclamationmark.triangle.fill" : "clock")
                            .foregroundColor(days <= 30 ? .orange : .green)
                        Text(days <= 30 ? "Due in \(days) days" : "\(days) days until renewal")
                            .font(.caption)
                            .foregroundColor(days <= 30 ? .orange : .secondary)
                    }
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Registration is overdue!")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    }
                }
            }
        } header: {
            Text("Vehicle Registration")
        } footer: {
            Text("You'll be reminded 1 month, 1 week, and on the day of renewal.")
        }
    }
    
    // MARK: - Inspection Section
    
    private var inspectionSection: some View {
        Section {
            Toggle(isOn: $hasInspectionDate) {
                Label("Track Inspection", systemImage: "checkmark.shield.fill")
            }
            
            if hasInspectionDate {
                Picker("State", selection: $inspectionState) {
                    Text("Select State").tag("")
                    ForEach(usStates, id: \.self) { state in
                        Text(state).tag(state)
                    }
                }
                
                DatePicker("Due Date", selection: $inspectionDate, displayedComponents: .date)
                
                if !inspectionState.isEmpty {
                    inspectionTypeInfo
                }
                
                if inspectionDate > Date() {
                    let days = Calendar.current.dateComponents([.day], from: Date(), to: inspectionDate).day ?? 0
                    HStack {
                        Image(systemName: days <= 30 ? "exclamationmark.triangle.fill" : "clock")
                            .foregroundColor(days <= 30 ? .orange : .green)
                        Text(days <= 30 ? "Due in \(days) days" : "\(days) days until inspection")
                            .font(.caption)
                            .foregroundColor(days <= 30 ? .orange : .secondary)
                    }
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Inspection is overdue!")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    }
                }
            }
        } header: {
            Text("Safety & Emissions Inspection")
        } footer: {
            Text("You'll be reminded 1 month, 1 week, and on the due date.")
        }
    }
    
    @ViewBuilder
    private var inspectionTypeInfo: some View {
        if inspectionRequiredStates.contains(inspectionState) && emissionsStates.contains(inspectionState) {
            Label("Safety + Emissions required", systemImage: "info.circle")
                .font(.caption)
                .foregroundColor(.blue)
        } else if inspectionRequiredStates.contains(inspectionState) {
            Label("Safety inspection required", systemImage: "info.circle")
                .font(.caption)
                .foregroundColor(.blue)
        } else if emissionsStates.contains(inspectionState) {
            Label("Emissions testing required", systemImage: "info.circle")
                .font(.caption)
                .foregroundColor(.blue)
        } else {
            Label("No periodic inspection required in \(inspectionState)", systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundColor(.green)
        }
    }
    
    // MARK: - State Info Section
    
    private var stateInfoSection: some View {
        Section(header: Text("About Inspections")) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Safety Inspections", systemImage: "shield.checkered")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("17 states require periodic safety inspections covering brakes, lights, tires, and other safety components.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Emissions Testing", systemImage: "leaf.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("16 states require emissions testing, typically in urban areas. Requirements vary by vehicle age and location.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Save
    
    private func saveChanges() {
        vehicle.registrationRenewalDate = hasRegistrationDate ? registrationDate : nil
        vehicle.inspectionDueDate = hasInspectionDate ? inspectionDate : nil
        vehicle.inspectionState = hasInspectionDate ? (inspectionState.isEmpty ? nil : inspectionState) : nil
        vehicle.updatedAt = Date()
        
        do {
            try viewContext.save()
            
            if hasRegistrationDate {
                NotificationService.shared.scheduleRegistrationRenewal(
                    vehicleID: vehicle.id,
                    vehicleName: vehicle.displayName,
                    renewalDate: registrationDate
                )
            }
            
            if hasInspectionDate {
                NotificationService.shared.scheduleInspectionReminder(
                    vehicleID: vehicle.id,
                    vehicleName: vehicle.displayName,
                    inspectionDate: inspectionDate
                )
            }
            
            showingSavedAlert = true
        } catch {
            print("Error saving registration/inspection: \(error)")
        }
    }
}
