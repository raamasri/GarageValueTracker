import SwiftUI
import CoreData

struct AlertsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \AlertEntity.createdAt, ascending: false)],
        animation: .default
    )
    private var alerts: FetchedResults<AlertEntity>
    
    @State private var showingCreateAlert = false
    
    var body: some View {
        NavigationView {
            Group {
                if alerts.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No Alerts")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("Set up alerts for price targets, depreciation cliffs, and sell windows")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button(action: { showingCreateAlert = true }) {
                            Label("Create Alert", systemImage: "plus.circle.fill")
                                .fontWeight(.semibold)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(14)
                        }
                        .padding(.horizontal, 40)
                    }
                } else {
                    List {
                        Section("Active") {
                            ForEach(alerts.filter { $0.isEnabled }) { alert in
                                AlertRowView(alert: alert)
                            }
                            .onDelete { offsets in
                                let activeAlerts = alerts.filter { $0.isEnabled }
                                offsets.forEach { index in
                                    AlertService.shared.deleteAlert(activeAlerts[index], context: viewContext)
                                }
                            }
                        }
                        
                        let triggered = alerts.filter { $0.lastTriggered != nil }
                        if !triggered.isEmpty {
                            Section("History") {
                                ForEach(triggered) { alert in
                                    AlertHistoryRow(alert: alert)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Alerts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if !alerts.isEmpty {
                        Button(action: { showingCreateAlert = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCreateAlert) {
                CreateAlertView()
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }
}

struct AlertRowView: View {
    @ObservedObject var alert: AlertEntity
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: alert.type.icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 36, height: 36)
                .background(Color.blue.opacity(0.12))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(alert.type.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let msg = alert.message {
                    Text(msg)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { alert.isEnabled },
                set: { _ in AlertService.shared.toggleAlert(alert, context: viewContext) }
            ))
            .labelsHidden()
        }
    }
}

struct AlertHistoryRow: View {
    let alert: AlertEntity
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(.subheadline)
                if let date = alert.lastTriggered {
                    Text(date, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct CreateAlertView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \VehicleEntity.year, ascending: false)]
    )
    private var vehicles: FetchedResults<VehicleEntity>
    
    @State private var selectedType: AlertType = .priceTarget
    @State private var title = ""
    @State private var message = ""
    @State private var selectedVehicleID: UUID?
    @State private var threshold = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Alert Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(AlertType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon).tag(type)
                        }
                    }
                }
                
                Section("Details") {
                    TextField("Alert Title", text: $title)
                    TextField("Message (optional)", text: $message)
                    
                    if selectedType == .priceTarget {
                        TextField("Price Threshold", text: $threshold)
                            .keyboardType(.decimalPad)
                    }
                }
                
                if !vehicles.isEmpty {
                    Section("Vehicle (optional)") {
                        Picker("Vehicle", selection: $selectedVehicleID) {
                            Text("All Vehicles").tag(nil as UUID?)
                            ForEach(vehicles) { vehicle in
                                Text(vehicle.displayName).tag(vehicle.id as UUID?)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Create Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        _ = AlertService.shared.createAlert(
                            context: viewContext,
                            vehicleID: selectedVehicleID,
                            type: selectedType,
                            title: title.isEmpty ? selectedType.displayName : title,
                            message: message.isEmpty ? nil : message,
                            threshold: Double(threshold) ?? 0
                        )
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(title.isEmpty && selectedType == .priceTarget && threshold.isEmpty)
                }
            }
        }
    }
}
